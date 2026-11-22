#!/usr/bin/env python3
"""Comparatif versionné d'Écluse et d'autres outils (P2-224).

Rend reproductible la sonde du 17 novembre : tire, graine 42, un échantillon
de documents des corpus synthétiques du dépôt, passe chaque outil dessus et
note **ce que chaque outil laisse passer**.

Échantillon (graine 42, voir `echantillon`) :

- 50 documents du corpus v3 (`bench/corpus.jsonl`, identifiants structurels) ;
- des **dossiers entiers** du corpus de dossiers réaliste, jusqu'à 50
  documents (`bench/dossiers/corpus_dossiers_realiste.jsonl`) ;
- 50 documents du corpus flou réaliste (`bench/flou/corpus_flou_realiste.jsonl`)
  qui portent une adresse ou une date de naissance annotée.

Outils : `Ecluse.redact` document par document, `Ecluse.redact` en session de
dossier, Presidio par défaut, Presidio configuré en français, spaCy
`fr_core_news_lg` seul, règles d'EDS-Pseudo (`eds_pseudo.simple_rules`,
`eds_pseudo.addresses`, `eds_pseudo.dates`).

Règle de score (la même pour tous) :

- une entité annotée est **couverte** quand tous ses caractères non blancs
  sont sous une prédiction de l'outil, **quel que soit le type prédit** ;
- pour un nom, la **civilité** (« Mme », « Dr »…) est retirée avant le test ;
- les masquages à tort sont comptés sur les documents **sans entité
  annotée** : un document y compte une fois s'il porte au moins une
  prédiction, quelle qu'elle soit.

Ce script ne tourne pas dans `etat.sh`. Il n'imprime que des comptes, jamais un
texte ni une valeur.

Usage (depuis la racine, environnement Python décrit dans
`bench/requirements-comparatif.txt`, `dart` dans le PATH, corpus générés par
`bench/etat.sh` ou leurs générateurs, graine 42) :

    python3 bench/comparatif.py --md bench/COMPARATIF.md

Sans `--md`, le tableau est imprimé. `--outils` limite les outils lancés
(liste séparée par des virgules, noms de `OUTILS`).
"""

import argparse
import json
import os
import platform
import random
import re
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(ICI)
SORTIE = os.path.join(ICI, "comparatif")
GRAINE = 42

CIVILITES = {"m", "m.", "monsieur", "mme", "mme.", "madame", "mademoiselle",
             "mlle", "mlle.", "dr", "dr.", "docteur", "pr", "pr.",
             "professeur", "me", "maître"}

OUTILS = ["ecluse_document", "ecluse_session", "presidio_defaut",
          "presidio_francais", "spacy_fr", "eds_pseudo"]
LIBELLES = {
    "ecluse_document": "Écluse, document par document",
    "ecluse_session": "Écluse, session de dossier",
    "presidio_defaut": "Presidio par défaut",
    "presidio_francais": "Presidio en français",
    "spacy_fr": "spaCy fr_core_news_lg seul",
    "eds_pseudo": "EDS-Pseudo (règles)",
}


# --- échantillon ----------------------------------------------------------

def _lire(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(ligne) for ligne in f if ligne.strip()]


def echantillon(v3, dossiers, flou, graine=GRAINE, n_v3=50, plafond_dossiers=50,
                n_flou=50):
    """Tire l'échantillon. Chaque document sort avec `source`, un `id` unique
    renuméroté et une clé `dossier` (celle du corpus de dossiers, sinon une clé
    propre au document : la session n'a alors rien à partager)."""
    rng = random.Random(graine)
    docs = []
    for i in sorted(rng.sample(range(len(v3)), n_v3)):
        docs.append(dict(v3[i], source="v3", dossier=f"v3-{i}"))
    par_dossier = {}
    for d in dossiers:
        par_dossier.setdefault(d["dossier"], []).append(d)
    cles = sorted(par_dossier)
    rng.shuffle(cles)
    total = 0
    for c in cles:
        if total + len(par_dossier[c]) > plafond_dossiers:
            continue
        for d in sorted(par_dossier[c], key=lambda x: x.get("rang", 0)):
            docs.append(dict(d, source="dossiers", dossier=f"d-{c}"))
        total += len(par_dossier[c])
    candidats = [i for i, d in enumerate(flou)
                 if any(e["type"] in ("adresse", "date_naissance")
                        for e in d["entities"])]
    for i in sorted(rng.sample(candidats, min(n_flou, len(candidats)))):
        docs.append(dict(flou[i], source="flou", dossier=f"f-{i}"))
    for k, d in enumerate(docs):
        d["id"] = k
    return docs


# --- score ----------------------------------------------------------------

def borne_sans_civilite(texte, ent):
    """Début de l'entité après retrait des civilités en tête (noms seulement)."""
    debut, fin = ent["start"], ent["end"]
    if ent["type"] != "nom":
        return debut, fin
    while True:
        m = re.match(r"\s*(\S+)", texte[debut:fin])
        if not m or m.group(1).lower() not in CIVILITES:
            return debut, fin
        suivant = debut + m.end()
        if suivant >= fin:  # le nom n'est que la civilité : on la garde
            return debut, fin
        debut = suivant


def couverte(texte, ent, spans):
    debut, fin = borne_sans_civilite(texte, ent)
    sous = set()
    for a, b, *_ in spans:  # le type prédit éventuel (P2-246) est indifférent
        sous.update(range(a, b))
    return all(texte[i].isspace() or i in sous for i in range(debut, fin))


def score(docs, spans_par_doc):
    """Renvoie (par_type, faux) : par_type[type] = [couvertes, total] ;
    faux = [documents sans entité portant une prédiction, documents sans
    entité]."""
    par_type = {}
    faux = [0, 0]
    for d in docs:
        spans = spans_par_doc.get(d["id"], [])
        if not d["entities"]:
            faux[1] += 1
            if spans:
                faux[0] += 1
            continue
        for e in d["entities"]:
            c = par_type.setdefault(e["type"], [0, 0])
            c[1] += 1
            if couverte(d["text"], e, spans):
                c[0] += 1
    return par_type, faux


# --- annotation complémentaire (P2-247) -------------------------------------
#
# Le corpus v3 n'annote que les identifiants structurels (NIR, RPPS, IBAN,
# FINESS) : ses phrases contiennent aussi des noms, des téléphones et des
# numéros de dossier que personne n'annote. Sans cela, un outil qui les masque
# est compté « à tort ». Cette annotation est propre au comparatif : elle ne
# modifie ni `generate_corpus.py` ni les corpus, elle ajoute des entités sur la
# copie de l'échantillon. Règle, écrite pour être relue :
#
# - **nom** : une suite « Prénom Nom » où Prénom est dans `PRENOMS` et Nom dans
#   `NOMS` de `generate_corpus.py` (les listes du générateur : ce sont les
#   personnes qu'il a posées), civilité exclue ;
# - **telephone** : un numéro français à dix chiffres (0X, ou +33 X) groupés par
#   deux, séparés par espace, point ou espace insécable ;
# - **dossier** : le nombre qui suit « dossier n° » ou « dossier numéro ».
#
# Un ajout qui recouvre une entité déjà annotée est ignoré. Les numéros que le
# corpus pose comme pièges (SIREN, SIRET, IBAN à clé invalide, numéros de
# praticien inconnus) ne sont **pas** annotés : ce ne sont pas des données
# personnelles au sens de cette règle (le SIREN est traité par P2-248).

RE_TEL = re.compile(r"(?<!\d)(?:0|\+33[ .\u00a0]?)[1-9](?:[ .\u00a0]?\d{2}){4}(?!\d)")
RE_DOSSIER = re.compile(r"dossier\s+(?:n°|numéro)\s*(\d+)", re.IGNORECASE)


def _regle_nom():
    sys.path.insert(0, ICI)
    from generate_corpus import NOMS, PRENOMS
    pre = "|".join(re.escape(x) for x in sorted(PRENOMS, key=len, reverse=True))
    nom = "|".join(re.escape(x) for x in sorted(NOMS, key=len, reverse=True))
    return re.compile(rf"(?<!\w)(?:{pre}) (?:{nom})(?!\w)")


def annote_complement(docs):
    """Copie de `docs` avec les entités ajoutées par la règle ci-dessus
    (champ `ajoute` = True sur chacune). Renvoie (copie, comptes) où comptes
    = {(source, type): nombre d'entités ajoutées}."""
    re_nom = _regle_nom()
    comptes = {}
    sortie = []
    for d in docs:
        texte = d["text"]
        entites = list(d["entities"])
        pris = [(e["start"], e["end"]) for e in entites]
        candidats = [("nom", m.start(), m.end()) for m in re_nom.finditer(texte)]
        candidats += [("telephone", m.start(), m.end())
                      for m in RE_TEL.finditer(texte)]
        candidats += [("dossier", m.start(1), m.end(1))
                      for m in RE_DOSSIER.finditer(texte)]
        for t, a, b in sorted(candidats, key=lambda c: c[1]):
            if any(a < fin and debut < b for debut, fin in pris):
                continue
            entites.append({"type": t, "start": a, "end": b, "ajoute": True})
            pris.append((a, b))
            comptes[(d["source"], t)] = comptes.get((d["source"], t), 0) + 1
        sortie.append(dict(d, entities=entites))
    return sortie, comptes


# --- outils ---------------------------------------------------------------

CORPUS = os.path.join(SORTIE, "corpus_comparatif.jsonl")


def ecrit_corpus(docs):
    os.makedirs(SORTIE, exist_ok=True)
    with open(CORPUS, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")


def lance_ecluse(docs, dossier, corpus=CORPUS, etiquette=""):
    sortie = os.path.join(SORTIE, "pred_ecluse_%s%s.jsonl"
                          % ("session" if dossier else "document", etiquette))
    cmd = ["dart", "run", "bin/run_dossiers_bench.dart"]
    if dossier:
        cmd.append("--dossier")
    cmd += [corpus, sortie]
    subprocess.run(cmd, cwd=os.path.join(RACINE, "packages", "ecluse_redact"),
                   check=True, stdin=subprocess.DEVNULL,
                   stdout=subprocess.DEVNULL)
    return {p["id"]: [(m["start"], m["end"], m["type"]) for m in p["mentions"]]
            for p in _lire(sortie)}


def lance_presidio(docs, francais):
    import warnings
    warnings.filterwarnings("ignore")
    from presidio_analyzer import AnalyzerEngine, RecognizerRegistry
    from presidio_analyzer.nlp_engine import NlpEngineProvider
    if francais:
        nlp = NlpEngineProvider(nlp_configuration={
            "nlp_engine_name": "spacy",
            "models": [{"lang_code": "fr", "model_name": "fr_core_news_lg"}],
        }).create_engine()
        registre = RecognizerRegistry(supported_languages=["fr"])
        registre.load_predefined_recognizers(nlp_engine=nlp, languages=["fr"])
        moteur = AnalyzerEngine(nlp_engine=nlp, registry=registre,
                                supported_languages=["fr"])
        langue = "fr"
    else:
        moteur = AnalyzerEngine()
        langue = "en"
    return {d["id"]: [(r.start, r.end, r.entity_type) for r in
                      moteur.analyze(text=d["text"], language=langue,
                                     score_threshold=0.35)]
            for d in docs}


def lance_spacy(docs):
    import spacy
    nlp = spacy.load("fr_core_news_lg")
    return {d["id"]: [(e.start_char, e.end_char, e.label_)
                      for e in nlp(d["text"]).ents] for d in docs}


def lance_eds_pseudo(docs):
    import warnings
    warnings.filterwarnings("ignore")
    import edsnlp
    nlp = edsnlp.blank("eds")
    nlp.add_pipe("eds.normalizer")
    for pipe in ("eds_pseudo.simple_rules", "eds_pseudo.addresses",
                 "eds_pseudo.dates"):
        nlp.add_pipe(pipe)
    return {d["id"]: [(e.start_char, e.end_char, e.label_)
                      for e in nlp(d["text"]).ents] for d in docs}


def lance(outil, docs, corpus=CORPUS, etiquette=""):
    """Les outils Python tournent chacun dans leur processus : edsnlp et spaCy
    enregistrent des composants dans un registre commun, et charger l'un avant
    l'autre fait échouer la création des règles d'EDS-Pseudo (constaté)."""
    if outil == "ecluse_document":
        return lance_ecluse(docs, False, corpus, etiquette)
    if outil == "ecluse_session":
        return lance_ecluse(docs, True, corpus, etiquette)
    sortie = os.path.join(SORTIE, f"pred_{outil}{etiquette}.jsonl")
    subprocess.run([sys.executable, os.path.abspath(__file__), "--interne",
                    outil, "--corpus", corpus, "--sortie", sortie], check=True, stdin=subprocess.DEVNULL,
                   stdout=subprocess.DEVNULL)
    return {p["id"]: [tuple(s) for s in p["spans"]] for p in _lire(sortie)}


# --- témoin sans donnée personnelle (P2-246) ---------------------------------

CORPUS_TEMOIN = os.path.join(SORTIE, "corpus_temoin.jsonl")


def mesure_temoin(docs, spans_par_doc):
    """Masquages à tort sur des documents **sans aucune** donnée personnelle.
    Renvoie {"docs": [masqués, total], "car": [masqués, total], "types":
    {type: [documents, caractères]}}. Un caractère compte une fois (union des
    prédictions, blancs exclus) ; un type compte un document s'il y figure."""
    r = {"docs": [0, len(docs)], "car": [0, 0], "types": {}}
    for d in docs:
        texte = d["text"]
        r["car"][1] += sum(1 for c in texte if not c.isspace())
        spans = spans_par_doc.get(d["id"], [])
        if spans:
            r["docs"][0] += 1
        sous = set()
        par_type = {}
        for a, b, *t in spans:
            nom = t[0] if t else "?"
            pos = {i for i in range(a, b) if not texte[i].isspace()}
            sous |= pos
            par_type.setdefault(nom, set()).update(pos)
        r["car"][0] += len(sous)
        for nom, pos in par_type.items():
            c = r["types"].setdefault(nom, [0, 0])
            c[0] += 1
            c[1] += len(pos)
    return r


def tableau_temoin(mesures, docs):
    outils = [o for o in OUTILS if o in mesures]
    lignes = ["| | " + " | ".join(LIBELLES[o] for o in outils) + " |",
              "|---|" + "---:|" * len(outils),
              "| Documents masqués à tort | " + " | ".join(
                  pct(*mesures[o]["docs"]) for o in outils) + " |",
              "| Caractères (hors blancs) masqués à tort | " + " | ".join(
                  pct(*mesures[o]["car"]) for o in outils) + " |"]
    types = sorted({t for o in outils for t in mesures[o]["types"]})
    for t in types:
        lignes.append(f"| type prédit `{t}` (documents / caractères) | " + " | ".join(
            "{}/{}".format(*mesures[o]["types"][t]) if t in mesures[o]["types"]
            else "—" for o in outils) + " |")
    familles = sorted({d.get("famille", "?") for d in docs})
    return "\n".join(lignes), familles


def familles_ecluse(docs, spans):
    """Documents d'Écluse masqués à tort, par famille de document."""
    par = {}
    for d in docs:
        c = par.setdefault(d.get("famille", "?"), [0, 0])
        c[1] += 1
        if spans.get(d["id"]):
            c[0] += 1
    return par


def lance_interne(outil, docs):
    if outil == "presidio_defaut":
        return lance_presidio(docs, francais=False)
    if outil == "presidio_francais":
        return lance_presidio(docs, francais=True)
    if outil == "spacy_fr":
        return lance_spacy(docs)
    if outil == "eds_pseudo":
        return lance_eds_pseudo(docs)
    raise ValueError(outil)


# --- rapport --------------------------------------------------------------

def versions():
    from importlib import metadata

    def v(nom):
        try:
            return metadata.version(nom)
        except metadata.PackageNotFoundError:
            return "non installé"

    commit_eds = "inconnu"
    try:
        dist = metadata.distribution("eds-pseudo")
        direct = json.loads(dist.read_text("direct_url.json") or "{}")
        commit_eds = direct.get("vcs_info", {}).get("commit_id", "inconnu")[:12]
    except Exception:
        pass
    dart = subprocess.run(["dart", "--version"], capture_output=True, text=True)
    git = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=RACINE,
                         capture_output=True, text=True).stdout.strip()
    return [
        ("Écluse (commit du dépôt)", git),
        ("Dart", (dart.stdout or dart.stderr).strip()),
        ("Python", platform.python_version()),
        ("presidio-analyzer", v("presidio-analyzer")),
        ("spacy", v("spacy")),
        ("fr_core_news_lg", v("fr_core_news_lg")),
        ("en_core_web_lg", v("en_core_web_lg")),
        ("edsnlp", v("edsnlp")),
        ("eds-pseudo (installé depuis GitHub)",
         f"{v('eds-pseudo')}, commit {commit_eds}"),
    ]


def pct(c, t):
    return "—" if t == 0 else f"{c}/{t} ({100.0 * c / t:.0f} %)"


def tableau(resultats, docs):
    outils = [o for o in OUTILS if o in resultats]
    types = sorted({t for r in resultats.values() for t in r[0]})
    lignes = ["| Type annoté | " + " | ".join(LIBELLES[o] for o in outils) + " |",
              "|---|" + "---:|" * len(outils)]
    for t in types:
        lignes.append(f"| {t} | " + " | ".join(
            pct(*resultats[o][0].get(t, [0, 0])) for o in outils) + " |")
    tot = {o: [sum(v[0] for v in resultats[o][0].values()),
               sum(v[1] for v in resultats[o][0].values())] for o in outils}
    lignes.append("| **Toutes entités** | " + " | ".join(
        "**" + pct(*tot[o]) + "**" for o in outils) + " |")
    lignes.append("| Documents sans entité masqués à tort | " + " | ".join(
        pct(*resultats[o][1]) for o in outils) + " |")
    return "\n".join(lignes)


LIMITES = """## Ce que ce comparatif ne dit pas

- **Les corpus sont produits par le projet** : ses détecteurs ont été écrits en
  regardant ces gabarits. Un outil qui n'a jamais vu ces gabarits part avec un
  handicap que ce comparatif ne chiffre pas ; sur des textes réels les écarts
  seraient différents, dans un sens ou dans l'autre. Aucun document réel n'est
  ici (règle 1 de `CLAUDE.md`).
- **Petit échantillon** : environ 150 documents tirés avec une seule graine (42).
  Aucun intervalle de confiance, aucune répétition avec d'autres graines.
- **La règle de score favorise la couverture** : une entité est « couverte » quel
  que soit le type prédit, et une prédiction large compte comme une couverture
  entière. Un outil qui masque tout le texte aurait 100 % de couverture ; c'est la
  ligne « masqués à tort » qui le retient, et elle ne compte que les documents
  **sans** entité annotée.
- **« Masqués à tort » n'est pas toujours une erreur** : le corpus v3 n'annote que
  les identifiants structurels, alors que ses phrases contiennent aussi des noms,
  des téléphones et des numéros de dossier non annotés ; un outil qui les masque y
  est compté « à tort » à cause de l'annotation, pas du texte. Les types prédits
  par Écluse sur ces documents sont donnés sous le tableau ; les autres outils
  n'ont pas été décomposés.
- **« Masqués à tort » compte les documents, pas les caractères** : un document
  sans entité qui porte une prédiction sur un mot courant compte autant qu'un
  document entièrement masqué.
- **Presidio** est lancé tel que ses reconnaisseurs prédéfinis le permettent
  (seuil de score 0,35, comme `bench/run_presidio.py`), **sans** reconnaisseurs NIR
  ou RPPS français : voir `bench/README.md` pour le comparatif dédié aux
  identifiants. « En français » veut dire : modèle spaCy `fr_core_news_lg` et
  reconnaisseurs prédéfinis chargés pour la langue `fr` ; rien de plus n'a été
  réglé.
- **spaCy seul** est un modèle d'entités nommées, pas un outil de
  pseudonymisation : il ne cherche ni e-mail, ni téléphone, ni identifiant. Ces
  lignes sont à lire comme « ce qu'il ne fait pas », pas comme un défaut.
- **EDS-Pseudo** : seules les règles sont mesurées (`simple_rules`, `addresses`,
  `dates`), **pas** le modèle appris du même projet, qui n'a pas été lancé ; le
  paquet `eds-pseudo` n'est pas sur PyPI, il est installé depuis son dépôt
  GitHub (commit noté plus haut).
- **Outils non mesurés** : tout ce qui n'est pas listé (autres pipelines de
  pseudonymisation, services en ligne, modèles de langue généralistes).
- **Écluse en session** n'a de sens que pour les documents de dossiers
  (clé `dossier`) ; les autres documents y sont passés un par un, comme en
  « document par document ».
- **Chemin mesuré** : `Ecluse.redact` (ce que reçoit le LLM) pour Écluse ; pour
  les autres outils, la détection de l'outil : aucun n'est branché à un LLM ici.
- Aucun chiffre de ce fichier n'est repris dans le `README.md` ni dans
  l'article : ce comparatif est une mesure interne, à relire avant toute
  citation.
"""


def detail_ecluse(docs):
    """Types prédits par Écluse (document par document) sur les documents sans
    entité annotée, par source : des comptes, jamais une valeur."""
    chemin = os.path.join(SORTIE, "pred_ecluse_document.jsonl")
    if not os.path.exists(chemin):
        return ""
    preds = {p["id"]: p["mentions"] for p in _lire(chemin)}
    par = {}
    for d in docs:
        if d["entities"] or not preds.get(d["id"]):
            continue
        c = par.setdefault(d["source"], {})
        for m in preds[d["id"]]:
            c[m["type"]] = c.get(m["type"], 0) + 1
    if not par:
        return ""
    return ("Mentions d'Écluse (document par document) sur les documents sans entité "
            "annotée, par source et par type prédit : " + " ; ".join(
                f"{s} : " + ", ".join(f"{t} {n}" for t, n in sorted(c.items()))
                for s, c in sorted(par.items())) + ".")


def section_annotation(resultats, resultats_a, docs_a, comptes):
    """Ancienne et nouvelle lignes côte à côte (P2-247) : mêmes prédictions,
    deux annotations."""
    outils = [o for o in OUTILS if o in resultats]
    sans = sum(1 for d in docs_a if not d["entities"])
    lignes = [
        "## Annotation complémentaire des données personnelles non annotées (P2-247)",
        "",
        "Mêmes prédictions que ci-dessus, **deux annotations** : celle du corpus, et celle du",
        "corpus plus une annotation propre au comparatif (`annote_complement` dans",
        "`bench/comparatif.py` ; ni `generate_corpus.py` ni les corpus ne sont touchés).",
        "",
        "**Règle d'annotation.** Noms : suite « Prénom Nom » dont le prénom et le nom",
        "sont dans `PRENOMS` et `NOMS` de `generate_corpus.py`, civilité exclue.",
        "Téléphones : numéro français à dix chiffres groupés par deux (`0X`, ou `+33 X`).",
        "Numéros de dossier : le nombre qui suit « dossier n° ». Un ajout qui recouvre une",
        "entité déjà annotée est ignoré. **Non annotés** : SIREN, SIRET, IBAN à clé",
        "invalide et numéros de praticien inconnus (pièges du corpus, pas des données",
        "personnelles au sens de cette règle ; le SIREN relève de P2-248).",
        "",
        "Entités ajoutées (source, type : nombre) : "
        + ", ".join(f"{s} {t} : {n}" for (s, t), n in sorted(comptes.items()))
        + f". Documents sans entité : {sum(1 for d in docs_a if not d['entities'])} "
        "après annotation.",
        "",
        "Ancienne et nouvelle lignes, côte à côte :",
        "",
        "| | " + " | ".join(LIBELLES[o] for o in outils) + " |",
        "|---|" + "---:|" * len(outils),
    ]
    def tot(r):
        return [sum(v[0] for v in r[0].values()), sum(v[1] for v in r[0].values())]
    lignes.append("| Couverture, annotation du corpus | " + " | ".join(
        pct(*tot(resultats[o])) for o in outils) + " |")
    lignes.append("| Couverture, avec annotation complémentaire | " + " | ".join(
        pct(*tot(resultats_a[o])) for o in outils) + " |")
    lignes.append("| Sans entité masqués à tort, annotation du corpus | " + " | ".join(
        pct(*resultats[o][1]) for o in outils) + " |")
    lignes.append("| Sans entité masqués à tort, avec annotation complémentaire | "
                  + " | ".join(pct(*resultats_a[o][1]) for o in outils) + " |")
    lignes += ["", "Détail par type avec annotation complémentaire :", "",
               tableau(resultats_a, docs_a), "",
               "Limites : la règle ne voit que les personnes posées par les listes du "
               "générateur, les téléphones et dossiers de format régulier ; une donnée "
               "personnelle d'une autre forme (dans les dossiers ou le flou) resterait "
               "non annotée. Le chemin mesuré est inchangé : `Ecluse.redact` pour "
               "Écluse, la détection propre de chaque outil pour les autres.", ""]
    return "\n".join(lignes)


FAMILLES_TEMOIN = os.path.join(ICI, "comparatif_temoin_familles.md")


def section_temoin(docs, mesures, spans_ecluse):
    tab, _ = tableau_temoin(mesures, docs)
    lignes = [
        "## Témoin sans aucune donnée personnelle (P2-246)",
        "",
        f"{len(docs)} documents synthétiques du soin et du social, **sans aucune "
        "donnée personnelle** (générés par `bench/generate_corpus_temoin_sans_pii.py`, "
        f"graine {GRAINE}) : consignes de service, comptes rendus sans nom, protocoles, "
        "plannings de salles, notes logistiques, courriers types. Toute prédiction "
        "y est un masquage en trop ; aucune correction n'est faite ici.",
        "",
        "Chemin mesuré : `Ecluse.redact` (ce que reçoit le LLM) pour les deux "
        "colonnes Écluse ; la détection propre de chaque outil pour les autres.",
        "",
        tab,
        "",
        "Écluse (document par document), documents masqués à tort par famille : "
        + " ; ".join(f"{f} {c[0]}/{c[1]}" for f, c in
                     sorted(familles_ecluse(docs, spans_ecluse).items())) + ".",
        "",
    ]
    if os.path.exists(FAMILLES_TEMOIN):
        with open(FAMILLES_TEMOIN, encoding="utf-8") as f:
            lignes += [f.read().rstrip(), ""]
    return "\n".join(lignes)


def rapport(resultats, docs, commande):
    comptes = {}
    for d in docs:
        comptes[d["source"]] = comptes.get(d["source"], 0) + 1
    sans = sum(1 for d in docs if not d["entities"])
    lignes = [
        "# Comparatif d'outils (P2-224)",
        "",
        "Mesure seule, produite par `bench/comparatif.py`. Elle ne tourne pas dans",
        "`bench/etat.sh`. Aucun chiffre n'est repris dans le README ni dans",
        "l'article.",
        "",
        "## Commande exacte",
        "",
        "```",
        commande,
        "```",
        "",
        "Environnement : `pip install -r bench/requirements-comparatif.txt` puis",
        "`python3 -m spacy download fr_core_news_lg en_core_web_lg`, et",
        "`pip install git+https://github.com/aphp/eds-pseudo.git` (voir ce fichier).",
        "Les corpus sont ceux que `bench/etat.sh` génère (graine 42) ; `dart` doit",
        "être dans le `PATH`.",
        "",
        "## Versions",
        "",
        "| Composant | Version |",
        "|---|---|",
    ]
    lignes += [f"| {a} | {b} |" for a, b in versions()]
    lignes += [
        "",
        "## Échantillon",
        "",
        f"{len(docs)} documents (graine {GRAINE}) : "
        + ", ".join(f"{c} {s}" for s, c in sorted(comptes.items()))
        + f" ; dont {sans} sans entité annotée.",
        "",
        "## Résultats : entités entièrement couvertes, par outil et par type",
        "",
        tableau(resultats, docs),
        "",
        detail_ecluse(docs),
        "",
        "Règle de score : voir l'en-tête de `bench/comparatif.py`. Entité couverte =",
        "tous ses caractères non blancs sont sous une prédiction, quel que soit le",
        "type prédit ; civilité retirée des noms ; masquages à tort comptés sur les",
        "documents sans entité.",
        "",
        LIMITES,
    ]
    return "\n".join(lignes) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--md", help="écrit le rapport dans ce fichier")
    ap.add_argument("--outils", default=",".join(OUTILS))
    ap.add_argument("--temoin", action="store_true",
                    help="mesure aussi le témoin sans donnée personnelle (P2-246) : "
                         "bench/generate_corpus_temoin_sans_pii.py, graine 42")
    ap.add_argument("--interne", help=argparse.SUPPRESS)
    ap.add_argument("--corpus", default=CORPUS, help=argparse.SUPPRESS)
    ap.add_argument("--sortie", help=argparse.SUPPRESS)
    a = ap.parse_args()
    if a.interne:  # un outil Python, dans son propre processus
        docs = _lire(a.corpus)
        spans = lance_interne(a.interne, docs)
        with open(a.sortie or os.path.join(SORTIE, f"pred_{a.interne}.jsonl"),
                  "w", encoding="utf-8") as f:
            for i, s in spans.items():
                f.write(json.dumps({"id": i, "spans": s}) + "\n")
        return
    choisis = [o for o in a.outils.split(",") if o]
    inconnus = [o for o in choisis if o not in OUTILS]
    if inconnus:
        sys.exit("Outil inconnu : " + ", ".join(inconnus))
    chemins = {"v3": os.path.join(ICI, "corpus.jsonl"),
               "dossiers": os.path.join(ICI, "dossiers",
                                        "corpus_dossiers_realiste.jsonl"),
               "flou": os.path.join(ICI, "flou", "corpus_flou_realiste.jsonl")}
    for nom, c in chemins.items():
        if not os.path.exists(c):
            sys.exit(f"Corpus {nom} absent ({c}) : lancer d'abord bench/etat.sh "
                     "ou le générateur correspondant (graine 42).")
    docs = echantillon(_lire(chemins["v3"]), _lire(chemins["dossiers"]),
                       _lire(chemins["flou"]))
    ecrit_corpus(docs)
    resultats, resultats_a = {}, {}
    docs_a, comptes_a = annote_complement(docs)
    for outil in choisis:
        spans = lance(outil, docs)
        resultats[outil] = score(docs, spans)
        resultats_a[outil] = score(docs_a, spans)
        print(f"{LIBELLES[outil]} : {sum(v[0] for v in resultats[outil][0].values())}"
              f" / {sum(v[1] for v in resultats[outil][0].values())} entités couvertes",
              file=sys.stderr)
    temoin = None
    if a.temoin:
        subprocess.run([sys.executable,
                        os.path.join(ICI, "generate_corpus_temoin_sans_pii.py"),
                        "--n", "480", "--seed", str(GRAINE), "--out",
                        CORPUS_TEMOIN], check=True, stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL)
        docs_t = _lire(CORPUS_TEMOIN)
        mesures, spans_ecluse = {}, {}
        for outil in choisis:
            sp = lance(outil, docs_t, CORPUS_TEMOIN, "_temoin")
            mesures[outil] = mesure_temoin(docs_t, sp)
            if outil == "ecluse_document":
                spans_ecluse = sp
            print(f"témoin, {LIBELLES[outil]} : {mesures[outil]['docs'][0]} / "
                  f"{mesures[outil]['docs'][1]} documents masqués", file=sys.stderr)
        temoin = (docs_t, mesures, spans_ecluse)
    commande = "python3 bench/comparatif.py --md bench/COMPARATIF.md" + (
        " --temoin" if a.temoin else "")
    texte = rapport(resultats, docs, commande)
    texte += "\n" + section_annotation(resultats, resultats_a, docs_a, comptes_a)
    if temoin:
        texte += "\n" + section_temoin(*temoin)
    if a.md:
        with open(a.md, "w", encoding="utf-8") as f:
            f.write(texte)
    else:
        print(tableau(resultats, docs))


if __name__ == "__main__":
    main()
