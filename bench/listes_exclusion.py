#!/usr/bin/env python3
"""P2-308 (mesure) : inventaire des listes qui retirent un mot de ce qui serait
masqué comme nom, et sonde synthétique d'homonymes. Rien n'est corrigé.

Deux commandes :

  inventaire : lit les sources Dart (`packages/ecluse_redact/lib/src/heuristics/`),
      extrait chaque liste d'exclusion nommée (taille, entrées), croise chaque
      entrée d'un mot avec le fichier INSEE des noms de famille
      (`packages/ecluse_reference/assets/patronymes_effectifs.tsv.gz`, noms portés
      au moins 30 fois, naissances 1891-2000) : une entrée qui est aussi un patronyme
      est un **homonyme**. N'imprime que des comptes, des entrées de liste (des mots
      de la langue, écrits dans le code) et des effectifs agrégés : jamais un texte.
  sonde : écrit un corpus JSONL synthétique (graine fixe) : pour chaque liste et
      ses homonymes les plus répandus, un vrai nom dont le patronyme est ce mot, dans
      trois tournures. Un nom annoté par document ; à passer par
      `packages/ecluse_redact/bin/run_gardes_avertissements.dart`.
  analyse : lit corpus + prédictions, rend par liste et tournure le nombre
      d'homonymes **en clair** (au moins un caractère du patronyme hors entité) et,
      parmi eux, ceux qu'un avertissement accompagne.

Usage :
    python3 bench/listes_exclusion.py inventaire
    python3 bench/listes_exclusion.py sonde --out sonde.jsonl [--par-liste 40]
    python3 bench/listes_exclusion.py analyse sonde.jsonl:pred.jsonl
"""
import argparse
import gzip
import json
import os
import re
import sys
import unicodedata
from collections import Counter, defaultdict

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
H = os.path.join(RACINE, "packages/ecluse_redact/lib/src/heuristics")
INSEE = os.path.join(RACINE, "packages/ecluse_reference/assets/patronymes_effectifs.tsv.gz")

# (identifiant, fichier, déclaration à chercher, ce que la liste retire)
LISTES = [
    ("statuts", "name_detector.dart", "_statuts",
     "mot de statut ou d'état civil (« Marié ») jamais pris pour un nom après une civilité ou un mot de parenté"),
    ("mots_voisins_neutres", "name_detector.dart", "_motsVoisinsNeutres",
     "jour, mois, adverbe de temps, formule : jamais absorbé comme patronyme voisin d'un prénom"),
    ("non_noms", "name_detector.dart", "_nonNoms",
     "valeur qui n'est pas un nom (« Non », « Service ») derrière une étiquette de champ"),
    ("mots_structure", "name_detector.dart", "_motsStructure",
     "début de ligne de signature qui désigne une structure"),
    ("formules_cloture", "name_detector.dart", "_formulesCloture",
     "formule de clôture d'un courrier (la ligne suivante est le nom)"),
    ("organismes", "name_detector.dart", "_organismes",
     "organisme national ou service public (« France Travail ») derrière une tournure de personne"),
    ("sigles_organismes", "name_detector.dart", "_siglesOrganismes",
     "sigle d'organisme en capitales"),
    ("mots_contexte_non_noms", "name_detector.dart", "_motsDeContexteNonNoms",
     "pronom, quantificateur : jamais le nom introduit par « le dossier de »"),
    ("mots_de_role", "name_detector.dart", "_motsDeRole",
     "civilité, parenté, fonction soignante ou sociale derrière une tournure de personne"),
    ("articles_capitalises", "name_detector.dart", "_articlesCapitalises",
     "article en majuscule initiale (« La Mairie a confirmé »)"),
    ("sigles_exclus", "name_detector.dart", "_excludedAcronyms",
     "sigle clinique ou administratif en capitales (« EVA », « HTA », « AS »)"),
    ("verbes_conjugues", "verbes_conjugues.dart", "verbesConjuguesCourants",
     "verbe conjugué d'usage courant derrière un prénom (« Sophie rappelle »)"),
    ("prenoms_insee_exclus", "prenom_insee_detector.dart", "exclus",
     "mot du fichier INSEE des prénoms jamais pris pour un prénom (« Manuel », « Mario »)"),
    ("paires_exclues", "prenom_insee_detector.dart", "pairesExclues",
     "paire prénom + mot jamais prise pour un nom (« France Travail »)"),
    ("outils_initiale", "initiale_libelle_detector.dart", "_outils",
     "mot outil derrière une initiale après un libellé de personne"),
    ("mots_neutres", "mots_neutres.dart", "motsNeutres",
     "mot outil, unité, comptage (partagé avec le détecteur d'adresses)"),
]

# Tournures de la sonde : {W} est le patronyme (annoté), {P} un prénom connu.
TOURNURES = {
    "dossier_de": ("Le dossier de {W} a été transmis hier.", "W"),
    "civilite": ("Madame {W} est venue ce matin.", "W"),
    "prenom_patronyme": ("{P} {W} a rappelé le service ce matin.", "PW"),
    # Même phrase écrite sans majuscule (courriel pressé, export en minuscules) :
    # la seule tournure où les verbes conjugués sont consultés.
    "minuscules": ("{P} {W} a rappelé le service ce matin.", "PW_bas"),
}
PRENOMS = ["Sophie", "Nathalie", "Laurent", "Julien", "Isabelle", "Pascal"]


def plie(m):
    m = unicodedata.normalize("NFD", m)
    m = "".join(c for c in m if not unicodedata.combining(c))
    return m.upper().replace("’", "'")


def charge_insee():
    eff = {}
    with gzip.open(INSEE, "rt", encoding="utf-8") as f:
        for l in f:
            if l.startswith("#") or "\t" not in l:
                continue
            nom, n = l.rstrip("\n").split("\t")
            eff[nom] = int(n)
    return eff


def extrait(fichier, nom):
    src = open(os.path.join(H, fichier), encoding="utf-8").read()
    m = re.search(r"(?:static\s+)?(?:const|final)\s+(?:Set<String>|List<String>|Map<[^>]*>)?\s*"
                  + re.escape(nom) + r"\s*=\s*(?:<String>)?([\[{])", src)
    if not m:
        m = re.search(re.escape(nom) + r"\s*=\s*(?:<String>)?([\[{])", src)
    if not m:
        raise SystemExit(f"liste introuvable : {nom} dans {fichier}")
    ouvre = m.group(1)
    ferme = "]" if ouvre == "[" else "}"
    i = m.end()
    prof = 1
    j = i
    while prof:
        c = src[j]
        if c == ouvre:
            prof += 1
        elif c == ferme:
            prof -= 1
        j += 1
    corps = src[i:j - 1]
    corps = re.sub(r"//[^\n]*", "", corps)
    return re.findall(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"", corps), src


def entrees(fichier, nom):
    brut, _ = extrait(fichier, nom)
    return [a or b for a, b in brut]


def homonymes(ent, eff):
    """Entrées d'un seul mot qui sont aussi un patronyme INSEE, triées par effectif."""
    res = {}
    for e in ent:
        if re.search(r"[\s]", e):
            continue
        n = eff.get(plie(e))
        if n:
            res[e] = n
    return sorted(res.items(), key=lambda kv: -kv[1])


# Les quatre listes coûteuses (P2-308, signalées par P2-310) et les neuf autres
# (P2-316) : seules leurs entrées qui sont aussi un patronyme INSEE sont
# signalées par `Ecluse.redact`.
LISTES_COUTEUSES = ["statuts", "mots_voisins_neutres", "mots_de_role", "verbes_conjugues"]
# Les neuf autres listes à homonymes (P2-316), signalées comme les quatre premières.
LISTES_NEUF = ["non_noms", "mots_structure", "sigles_organismes", "mots_contexte_non_noms",
               "articles_capitalises", "sigles_exclus", "prenoms_insee_exclus", "mots_neutres",
               "outils_initiale"]
LISTES_SIGNALEES = LISTES_COUTEUSES + LISTES_NEUF
FICHIER_HOMONYMES = os.path.join(H, "homonymes_patronymes.dart")


def mots_homonymes():
    """Entrées d'un mot des quatre listes qui sont aussi un patronyme INSEE
    (≥ 30 naissances), en minuscules sans accent : ce que le code compare."""
    eff = charge_insee()
    mots = set()
    for ident, fichier, nom, _ in LISTES:
        if ident in LISTES_SIGNALEES:
            for e, _n in homonymes(entrees(fichier, nom), eff):
                mots.add(plie(e).lower())
    return sorted(mots)


def source_dart():
    mots = mots_homonymes()
    lignes = "".join(f"  '{m}',\n" for m in mots)
    return (
        "// Fichier GÉNÉRÉ : `python3 bench/listes_exclusion.py homonymes_dart`\n"
        "// (P2-310, P2-316). Ne pas éditer à la main : `bench/test_listes_exclusion.py`\n"
        "// compare ce fichier à la sortie du script.\n"
        "\n"
        "/// Entrées d'un mot des treize listes d'exclusion des noms qui ont des homonymes\n"
        "/// (les quatre de P2-310 : `statuts`, `mots_voisins_neutres`, `mots_de_role`,\n"
        "/// `verbes_conjugues` ; les neuf de P2-316, voir `LISTES_NEUF`) qui\n"
        "/// sont aussi un patronyme du fichier INSEE des noms de famille (au moins 30\n"
        "/// naissances, 1891-2000), en minuscules sans accent. Seuls ces mots sont\n"
        "/// signalés « à vérifier » quand une liste les laisse en clair : un mot qui\n"
        "/// n'est pas un nom de personne (« bénéficiaire », « rappelle ») ne l'est pas.\n"
        "const Set<String> motsHomonymesDePatronymes = {\n"
        f"{lignes}"
        "};\n"
    )


def cmd_homonymes_dart(ecrire):
    src = source_dart()
    if ecrire:
        with open(FICHIER_HOMONYMES, "w", encoding="utf-8") as f:
            f.write(src)
        print(f"{FICHIER_HOMONYMES} : {len(mots_homonymes())} mots")
    else:
        sys.stdout.write(src)


def cmd_inventaire():
    eff = charge_insee()
    print("liste | fichier | entrées | un mot | homonymes INSEE (≥30) | dont ≥ 1 000 | plus répandus (effectif)")
    for ident, fichier, nom, _ in LISTES:
        ent = entrees(fichier, nom)
        un = [e for e in ent if not re.search(r"\s", e)]
        h = homonymes(ent, eff)
        gros = [x for x in h if x[1] >= 1000]
        tete = ", ".join(f"{e} ({n})" for e, n in h[:5])
        print(f"{ident} | {fichier} | {len(ent)} | {len(un)} | {len(h)} | {len(gros)} | {tete}")


def cmd_sonde(out, par_liste):
    eff = charge_insee()
    docs = []
    toutes = set()
    for _, fichier, nom, _ in LISTES:
        toutes.update(plie(e) for e in entrees(fichier, nom))
    for ident, fichier, nom, _ in LISTES:
        ent = entrees(fichier, nom)
        # Une casse de titre, comme dans un texte ordinaire ; une entrée en
        # capitales (sigle) reste en capitales.
        for k, (mot, n) in enumerate(homonymes(ent, eff)[:par_liste]):
            patro = mot if mot.isupper() else mot[:1].upper() + mot[1:]
            for t, (modele, forme) in TOURNURES.items():
                p = PRENOMS[k % len(PRENOMS)]
                texte = modele.format(W=patro, P=p)
                if forme.endswith("_bas"):
                    texte = texte.lower()
                deb = texte.lower().index(patro.lower()) if forme == "W" else texte.lower().index(p.lower())
                fin = texte.lower().index(patro.lower()) + len(patro)
                docs.append({
                    "id": len(docs), "text": texte,
                    "entities": [{"type": "nom", "start": deb, "end": fin}],
                    "liste": ident, "mot": mot, "tournure": t, "effectif": n,
                    "patro_debut": texte.lower().index(patro.lower()),
                    "patro_fin": texte.lower().index(patro.lower()) + len(patro),
                    "presentation": "sonde"})
    # Témoin : les 40 patronymes les plus répandus qui ne figurent dans aucune
    # liste ; ils doivent tous être masqués (sinon le défaut n'est pas celui des
    # listes).
    temoin = [(n, e) for n, e in eff.items() if n not in toutes and n.isalpha() and len(n) > 3]
    temoin = sorted(temoin, key=lambda x: -x[1])[:40]
    for k, (n, e) in enumerate(temoin):
        patro = n[:1] + n[1:].lower()
        for t, (modele, forme) in TOURNURES.items():
            p = PRENOMS[k % len(PRENOMS)]
            texte = modele.format(W=patro, P=p)
            if forme.endswith("_bas"):
                texte = texte.lower()
            i = texte.lower().index(patro.lower())
            deb = i if forme == "W" else texte.lower().index(p.lower())
            docs.append({
                "id": len(docs), "text": texte,
                "entities": [{"type": "nom", "start": deb, "end": i + len(patro)}],
                "liste": "temoin_patronymes", "mot": n, "tournure": t, "effectif": e,
                "patro_debut": i, "patro_fin": i + len(patro), "presentation": "sonde"})
    with open(out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {out}")


PERTINENT = re.compile(r"à vérifier|relire avant envoi|non masqué")


def en_clair(debut, fin, ents):
    return sum(1 for i in range(debut, fin)
               if not any(e["start"] <= i < e["end"] for e in ents))


def cmd_analyse(paires):
    eff = charge_insee()
    total_eff = sum(eff.values())
    t = defaultdict(Counter)
    distincts = defaultdict(dict)  # liste -> {mot: effectif} en clair sous au moins une tournure
    for p in paires:
        c, pr = p.split(":")
        corpus = [json.loads(l) for l in open(c, encoding="utf-8")]
        pred = {d["id"]: d for d in map(json.loads, open(pr, encoding="utf-8"))}
        for d in corpus:
            r = pred[d["id"]]
            clair = en_clair(d["patro_debut"], d["patro_fin"], r["entities"])
            sig = any(PERTINENT.search(w) for w in r["warnings"])
            k = (d["liste"], d["tournure"])
            t[k]["n"] += 1
            t[k]["eff"] += d["effectif"]
            if clair:
                t[k]["clair"] += 1
                t[k]["eff_clair"] += d["effectif"]
                distincts[d["liste"]][d["mot"]] = d["effectif"]
                if sig:
                    t[k]["clair_signale"] += 1
    print("liste | tournure | homonymes | patronyme en clair | dont signalés | SILENCIEUX | "
          "naissances 1891-2000 des patronymes en clair (part du fichier INSEE)")
    tot = defaultdict(Counter)
    for (liste, tour), c in sorted(t.items()):
        silencieux = c["clair"] - c["clair_signale"]
        print(f"{liste} | {tour} | {c['n']} | {c['clair']} | {c['clair_signale']} | {silencieux} | "
              f"{c['eff_clair']} ({100 * c['eff_clair'] / total_eff:.3f} %)")
        tot[liste]["n"] += c["n"]
        tot[liste]["clair"] += c["clair"]
        tot[liste]["sig"] += c["clair_signale"]
    print("\n== patronymes distincts en clair sous au moins une tournure (part des naissances du fichier INSEE)")
    for liste, mots in sorted(distincts.items()):
        e = sum(mots.values())
        print(f"{liste} : {len(mots)} patronymes, {e} naissances ({100 * e / total_eff:.3f} %)")
    print("\n== par liste (toutes tournures)")
    for liste, c in sorted(tot.items()):
        print(f"{liste} : {c['n']} documents, {c['clair']} patronymes en clair, "
              f"{c['sig']} signalés, {c['clair'] - c['sig']} silencieux")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("inventaire")
    h_ = sp.add_parser("homonymes_dart")
    h_.add_argument("--ecrire", action="store_true")
    s = sp.add_parser("sonde")
    s.add_argument("--out", required=True)
    s.add_argument("--par-liste", type=int, default=200)
    a_ = sp.add_parser("analyse")
    a_.add_argument("paires", nargs="+")
    a = ap.parse_args()
    if a.cmd == "inventaire":
        cmd_inventaire()
    elif a.cmd == "homonymes_dart":
        cmd_homonymes_dart(a.ecrire)
    elif a.cmd == "sonde":
        cmd_sonde(a.out, a.par_liste)
    else:
        cmd_analyse(a.paires)
