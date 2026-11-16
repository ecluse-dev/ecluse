#!/usr/bin/env python3
"""Ecritures de communes hors referentiel : ce que la regle « nom exact » ne
couvre pas (P2-215, mesure pour `agent/specs/P2-215.md`).

**Mesure seulement : rien ici n'est dans `lib/`.** La regle « nom exact du
referentiel » (decision du 16 novembre, P2-214) lit les noms tels que le
referentiel les ecrit ; son « 0 » sur le balayage est vrai par construction.
Ce script ecrit les memes communes **autrement**, et compte ce qui reste en
clair.

Population : les communes pour lesquelles la regle est la seule protection,
c'est-a-dire celles que le motif d'`AdresseDetector` ne lit pas en entier en
capitales sans « CEDEX » (formes A, C et D de `agent/specs/P2-205.md` : cinq
mots ou plus, parenthese ou tiret isole, determinant puis mot neutre ; la
forme B, mot neutre en tete, est hors de la regle). Pour les autres communes
le motif ne regarde pas l'orthographe : une faute n'y change rien.

Ecritures (`variante`), une adresse par commune et par variante applicable,
tout le document en capitales, sans CEDEX, code postal fabrique :

- `reference` : la forme postale du referentiel (colonne NORM). Controle ;
- `accents` : le libelle officiel en capitales **avec** ses accents, tirets et
  apostrophes remplaces par une espace (« CHÂTEAU CHINON (VILLE) »). Controle
  de « accent perdu » : la regle compare sans accent, les deux doivent
  donner le meme resultat ;
- `st` : « SAINT » ecrit « ST », « SAINTE » ecrit « STE » ;
- `apostrophe_collee` : une apostrophe perdue sans espace (« D ARTHEZ » ->
  « DARTHEZ ») ;
- `tiret_colle` : un tiret perdu sans espace (« CHATEAU CHINON » ->
  « CHATEAUCHINON ») ;
- `lettre_fautive` : une lettre d'un mot d'au moins quatre lettres remplacee
  par une autre ;
- `lettre_omise` : une lettre d'un mot d'au moins quatre lettres retiree.

Regles simulees, comme dans `regles_candidates_communes.py` : l'etendue
masquee finale est l'**union** des detections de `Ecluse.redact` (ce que
recoit le LLM, predictions de `run_redact_bench.dart`) et de l'etendue que la
regle ajouterait ; `resolveOverlaps` n'est pas rejoue. Chaque regle prend le
plus long prefixe de la fin de ligne, apres le code postal, qui est un nom de
sa table ; elle ne s'applique qu'a un texte sans aucune minuscule.

- `exact` : nom exact, sans accent ni ponctuation (P2-214) ;
- `normalise` : option 1 de la spec. Avant de comparer, « ST » et « STE »
  deviennent « SAINT » et « SAINTE », puis les espaces sont retirees des deux
  cotes (le nom et le texte sont compares « colles ») ;
- `distance1` : option 2. Comme `normalise`, et une lettre d'ecart est
  toleree (une substitution, une lettre en trop ou en moins) pour un nom d'au
  moins `--lettres-min` lettres.

Deux tables : `complete` (les 34 875 communes, la simulation de P2-206) et
`reduite` (les seules formes A, C et D, comme la table embarquee de P2-214).

Sous-commandes :

- `genere` : ecrit le corpus des ecritures ;
- `couverture` : adresses en partie en clair par variante, avec `Ecluse.redact`
  seul puis avec chaque regle et chaque table ;
- `cout` : sur des temoins **sans adresse a cet endroit**, nombre de lignes
  ou la regle ajouterait un masquage (borne haute : compte toute etendue que
  la regle produirait, que `Ecluse.redact` l'ait deja masquee ou non).

N'imprime que des comptes. Donnees : referentiel public, corpus synthetiques.

Usage (depuis `bench/`, apres `bash bench/etat.sh` pour les temoins) :
    python3 ecritures_hors_referentiel.py genere --seed 42 \\
        --out flou/corpus_ecritures_hors_referentiel.jsonl
    (cd ../packages/ecluse_redact && dart run bin/run_redact_bench.dart \\
        ../../bench/flou/corpus_ecritures_hors_referentiel.jsonl \\
        ../../bench/flou/pred_ecritures_hors_referentiel.jsonl)
    python3 ecritures_hors_referentiel.py couverture \\
        --corpus flou/corpus_ecritures_hors_referentiel.jsonl \\
        --pred flou/pred_ecritures_hors_referentiel.jsonl
    python3 ecritures_hors_referentiel.py cout \\
        flou/corpus_flou_cinq_chiffres.jsonl flou/corpus_flou_determinant.jsonl \\
        flou/corpus_flou_commune_neutre.jsonl flou/corpus_flou_neutre_cedex.jsonl \\
        flou/corpus_courriers.jsonl flou/corpus_flou_commune_suivie.jsonl
"""

import argparse
import collections
import csv
import gzip
import json
import os
import random
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)

from classe_communes_capitales import DETERMINANTS, mots_neutres  # noqa: E402
from generate_corpus_cedex import code_postal  # noqa: E402
from regles_candidates_communes import (CODE_POSTAL, COMMUNES,  # noqa: E402
                                        PLUS_LONG_NOM, couverts_de, en_clair,
                                        fin_ligne, norme, tokens)

VARIANTES = ("reference", "accents", "st", "apostrophe_collee", "tiret_colle",
             "lettre_fautive", "lettre_omise")
REGLES = ("exact", "normalise", "distance1")
TABLES = ("complete", "reduite")
ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
ABREVIATIONS = {"ST": "SAINT", "STE": "SAINTE"}


def lit(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(ligne) for ligne in f if ligne.strip()]


def lit_referentiel(chemin=COMMUNES):
    """[(code, dep, norm, libelle)] dans l'ordre du fichier."""
    with gzip.open(chemin, "rt", encoding="utf-8") as f:
        return [(r["COM"], r["DEP"], r["NORM"], r["LIBELLE"])
                for r in csv.DictReader(f, delimiter=";") if r["NORM"]]


def forme(norm, libelle, neutres):
    """« A », « C », « D » (formes que la regle vise) ou None."""
    mots = norme(norm).lower().split()
    if not mots or (mots[0] in neutres and mots[0] not in DETERMINANTS):
        return None
    if mots[0] in DETERMINANTS and len(mots) > 1 and mots[1] in neutres:
        return "D"
    if "(" in libelle or " - " in libelle or "  " in libelle:
        return "C"
    return "A" if len(mots) >= 5 else None


def _un_mot_long(rng, mots):
    """Indice d'un mot d'au moins quatre lettres, ou None."""
    longs = [i for i, m in enumerate(mots) if len(m) >= 4 and m.isalpha()]
    return rng.choice(longs) if longs else None


def ecrit(rng, norm, libelle, variante):
    """L'ecriture de la commune pour `variante`, ou None si elle ne
    s'applique pas a ce nom (ou ne change rien)."""
    if variante == "reference":
        return norm
    if variante == "accents":
        texte = re.sub(r"['’-]+", " ", libelle.upper())
        texte = re.sub(r" +", " ", texte).strip()
        return texte if texte != norm else None
    mots = norm.split()
    if variante == "st":
        abrege = ["ST" if m == "SAINT" else "STE" if m == "SAINTE" else m
                  for m in mots]
        return " ".join(abrege) if abrege != mots else None
    if variante in ("apostrophe_collee", "tiret_colle"):
        signe = "'’" if variante == "apostrophe_collee" else "-"
        brut = libelle.upper().replace(" - ", " ")
        places = [i for i, c in enumerate(brut) if c in signe
                  and 0 < i < len(brut) - 1
                  and brut[i - 1].isalpha() and brut[i + 1].isalpha()]
        if not places:
            return None
        i = rng.choice(places)
        colle = brut[:i] + brut[i + 1:]
        # Le reste du nom reste en forme postale : seul ce signe est perdu.
        return norme_postale(colle)
    i = _un_mot_long(rng, mots)
    if i is None:
        return None
    mot = mots[i]
    j = rng.randrange(len(mot))
    if variante == "lettre_fautive":
        autre = rng.choice([c for c in ALPHABET if c != mot[j]])
        mots[i] = mot[:j] + autre + mot[j + 1:]
    elif variante == "lettre_omise":
        mots[i] = mot[:j] + mot[j + 1:]
    else:
        raise ValueError(variante)
    return " ".join(mots)


def norme_postale(texte):
    """Forme postale d'un libelle : sans accent, tirets et apostrophes en
    espaces, parentheses gardees (comme la colonne NORM)."""
    sans = norme(texte.replace("(", " XPARO ").replace(")", " XPARF "))
    return re.sub(r" ?XPARF", ")", re.sub(r"XPARO ?", "(", sans))


def genere(seed, communes=None, neutres=None):
    rng = random.Random(f"{seed}-ecritures-hors-referentiel")
    communes = lit_referentiel() if communes is None else communes
    neutres = mots_neutres() if neutres is None else neutres
    docs = []
    for code, dep, norm, libelle in communes:
        f = forme(norm, libelle, neutres)
        if f is None:
            continue
        for variante in VARIANTES:
            nom = ecrit(rng, norm, libelle, variante)
            if nom is None:
                continue
            avant = "COURRIER À ADRESSER À :\n"
            cp = code_postal(rng, dep)
            texte = f"{avant}{cp} {nom}\nMERCI DE VOTRE RETOUR."
            debut = len(avant)
            fin = debut + 6 + len(nom)
            docs.append({
                "id": len(docs), "text": texte,
                "entities": [{"type": "adresse", "start": debut, "end": fin}],
                "parties": {"commune": [debut + 6, fin]},
                "com": code, "forme": f, "variante": variante})
    return docs


# --- regles simulees --------------------------------------------------------

def colle(nom_norme):
    """Cle « collee » : abreviations developpees, espaces retirees."""
    return "".join(ABREVIATIONS.get(m, m) for m in nom_norme.split())


def suppressions(cle):
    """La cle et toutes ses formes a une lettre retiree."""
    return {cle} | {cle[:i] + cle[i + 1:] for i in range(len(cle))}


class Table:
    """Une table de noms et les trois facons d'y chercher."""

    def __init__(self, noms_normes, lettres_min=8):
        self.exacts = set(noms_normes)
        self.colles = {colle(n) for n in noms_normes}
        self.lettres_min = lettres_min
        # Distance 1 par voisinage de suppressions : deux cles sont a une
        # lettre d'ecart (substitution, ajout ou retrait) si elles partagent
        # une forme a une lettre retiree, et que leurs longueurs different
        # d'au plus un. Les noms courts sont exclus de la tolerance.
        self.voisins = collections.defaultdict(set)
        for c in self.colles:
            if len(c) >= lettres_min:
                for s in suppressions(c):
                    self.voisins[s].add(len(c))

    def contient(self, regle, texte_norme):
        if regle == "exact":
            return texte_norme in self.exacts
        c = colle(texte_norme)
        if c in self.colles:
            return True
        if regle == "normalise":
            return False
        if len(c) < self.lettres_min:
            return False
        return any(abs(n - len(c)) <= 1 for s in suppressions(c)
                   for n in self.voisins.get(s, ()))


def etendues(texte, regle, table):
    """Etendues [debut, fin) que la regle ajouterait ; texte sans aucune
    minuscule seulement (la branche ou la regle vit)."""
    if texte != texte.upper():
        return []
    sortie = []
    for cp in CODE_POSTAL.finditer(texte):
        i = cp.end()
        while i < len(texte) and texte[i] in "   \t":
            i += 1
        if i == cp.end():
            continue
        fin = fin_ligne(texte, i)
        mots = tokens(texte[i:fin])
        meilleur = None
        for k in range(1, min(len(mots), PLUS_LONG_NOM) + 1):
            bout = i + mots[k - 1][1]
            if texte[bout:fin].startswith(")"):
                bout += 1
            if table.contient(regle, norme(texte[i:bout])):
                meilleur = bout
        if meilleur:
            sortie.append((cp.start(), meilleur))
    return sortie


def tables(lettres_min):
    neutres = mots_neutres()
    communes = lit_referentiel()
    return {
        "complete": Table([norme(c[2]) for c in communes], lettres_min),
        "reduite": Table([norme(c[2]) for c in communes
                          if forme(c[2], c[3], neutres)], lettres_min),
    }


def mesure_couverture(corpus, preds, lettres_min):
    tabs = tables(lettres_min)
    total = collections.Counter()
    seul = collections.Counter()
    reste = collections.Counter()
    for doc in corpus:
        if doc["id"] not in preds:
            raise ValueError(f"document {doc['id']} : prédiction absente")
        pred = preds[doc["id"]]
        e = doc["entities"][0]
        v = doc["variante"]
        total[v] += 1
        seul[v] += en_clair(doc["text"], e["start"], e["end"],
                            couverts_de(pred))
        for nom_table, table in tabs.items():
            for regle in REGLES:
                c = couverts_de(pred, etendues(doc["text"], regle, table))
                reste[(v, nom_table, regle)] += en_clair(
                    doc["text"], e["start"], e["end"], c)
    communes = len({d["com"] for d in corpus})
    print(f"écritures hors référentiel : {len(corpus)} adresses, {communes} "
          "communes des formes A, C et D, tout en capitales, sans CEDEX ; "
          "adresses en partie en clair (Ecluse.redact + règle simulée, hors "
          f"lib/ ; distance 1 pour un nom d'au moins {lettres_min} lettres)")
    for nom_table in TABLES:
        print(f"# table {nom_table} ({len(tabs[nom_table].exacts)} noms)")
        for v in VARIANTES:
            if not total[v]:
                continue
            detail = " ; ".join(f"{r} {reste[(v, nom_table, r)]}"
                                for r in REGLES)
            print(f"  variante={v} : {total[v]} adresses, Ecluse.redact seul "
                  f"{seul[v]} ; {detail}")
        hors = [v for v in VARIANTES if v not in ("reference", "accents")]
        n = sum(total[v] for v in hors)
        detail = " ; ".join(
            f"{r} {sum(reste[(v, nom_table, r)] for v in hors)}"
            for r in REGLES)
        print(f"  écritures hors référentiel (cinq variantes) : {n} adresses, "
              f"Ecluse.redact seul {sum(seul[v] for v in hors)} ; {detail}")


def lignes_sans_adresse(doc):
    """Les lignes (debut, fin) du document qui ne touchent aucune adresse
    annotee : la ou une etendue de la regle est un masquage en trop."""
    texte = doc["text"]
    annotes = [(e["start"], e["end"]) for e in doc.get("entities", [])]
    debut = 0
    for ligne in texte.split("\n"):
        fin = debut + len(ligne)
        if not any(a < fin and b > debut for a, b in annotes):
            yield debut, fin
        debut = fin + 1


def mesure_cout(chemins, lettres_min):
    tabs = tables(lettres_min)
    print("coût des règles sur des lignes sans adresse annotée, texte mis en "
          "capitales : lignes où la règle ajouterait une étendue (borne "
          f"haute ; distance 1 pour un nom d'au moins {lettres_min} lettres)")
    for chemin in chemins:
        corpus = lit(chemin)
        lignes = 0
        touche = collections.Counter()
        for doc in corpus:
            haut = doc["text"].upper()
            if len(haut) != len(doc["text"]):
                raise ValueError(f"document {doc['id']} : la mise en "
                                 "capitales change la longueur")
            libres = list(lignes_sans_adresse(doc))
            lignes += len(libres)
            for nom_table, table in tabs.items():
                for regle in REGLES:
                    ajouts = etendues(haut, regle, table)
                    touche[(nom_table, regle)] += sum(
                        1 for a, b in libres
                        if any(x < b and y > a for x, y in ajouts))
        nom = os.path.basename(chemin)
        for nom_table in TABLES:
            detail = " ; ".join(f"{r} {touche[(nom_table, r)]}"
                                for r in REGLES)
            print(f"  {nom}, table {nom_table} : {lignes} lignes ; {detail}")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sp = p.add_subparsers(dest="commande", required=True)
    g = sp.add_parser("genere")
    g.add_argument("--seed", type=int, default=42)
    g.add_argument("--out", required=True)
    c = sp.add_parser("couverture")
    c.add_argument("--corpus", required=True)
    c.add_argument("--pred", required=True)
    c.add_argument("--lettres-min", type=int, default=8)
    k = sp.add_parser("cout")
    k.add_argument("temoins", nargs="+")
    k.add_argument("--lettres-min", type=int, default=8)
    a = p.parse_args()
    if a.commande == "genere":
        docs = genere(a.seed)
        if not docs:
            raise SystemExit("aucune commune des formes A, C, D : corpus vide")
        with open(a.out, "w", encoding="utf-8") as f:
            for d in docs:
                f.write(json.dumps(d, ensure_ascii=False) + "\n")
        par = collections.Counter(d["variante"] for d in docs)
        print(f"{a.out} : {len(docs)} adresses ; " + ", ".join(
            f"{v} {par[v]}" for v in VARIANTES))
    elif a.commande == "couverture":
        preds = {d["id"]: d for d in lit(a.pred)}
        mesure_couverture(lit(a.corpus), preds, a.lettres_min)
    else:
        mesure_cout(a.temoins, a.lettres_min)


if __name__ == "__main__":
    main()
