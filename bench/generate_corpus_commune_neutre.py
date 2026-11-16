#!/usr/bin/env python3
"""Corpus TEMOIN « cinq chiffres + nom de commune de forme neutre » (P2-206).

Quinze communes du referentiel public versionne ont un nom qui commence par un
mot neutre de `mots_neutres.dart` (« SON », « VERS », « SOUS PARSAT », « AUX
AUSSAT », « LES PLACES »). La regle du mot neutre (`_communeNeutre`, P2-122)
les ecarte en capitales : « 08061 SON » n'est pas masque. La correction « nom
exact du referentiel » (`agent/specs/P2-205.md`, option B.2) la leverait quand
le nom est une commune. Ce temoin chiffre, avant toute correction, ce que
cette levee couterait : des phrases ordinaires ou un nombre a cinq chiffres
est suivi du nom d'une de ces communes, **aucune adresse annotee** (`"entities":
[]`) : toute adresse que la regle candidate ferait predire est un masquage en
trop (lisibilite perdue ; une commune laissee en clair serait, elle, une fuite
mesuree par le balayage).

Construit, pas observe : une phrase par forme, sans frequence reelle. Le
chiffre dit un pire cas.

Axes : `famille` (`fin` : le nom finit la ligne ; `suite` : le nom est suivi de
mots ordinaires qui n'en font pas partie) et `casse` (`capitales` ; `ordinaire`
: phrase en casse ordinaire, nom en casse de titre). Noms de communes : lus
dans le referentiel public deja versionne, jamais un document reel. Nombres
fabriques. Graine fixe.

Usage :
    python3 generate_corpus_commune_neutre.py --n 400 --seed 42 \\
        --out flou/corpus_flou_commune_neutre.jsonl
"""

import argparse
import csv
import gzip
import json
import os
import random
import re

from classe_communes_capitales import DETERMINANTS, mots_neutres

ICI = os.path.dirname(os.path.abspath(__file__))
COMMUNES = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")

FIN = ["Dossier {n} {w}", "Montant total {n} {w}", "Reference interne {n} {w}"]
SUITE = ["{n} {w} selon le plan", "Virement de {n} {w} effectue lundi",
         "Lot {n} {w} a livrer demain"]
FAMILLES = {"fin": FIN, "suite": SUITE}


def noms_neutres(chemin=COMMUNES):
    """Noms (forme normalisee du referentiel) dont le premier mot est neutre
    (hors LE, LA, LES, L'), ou un determinant suivi d'un mot neutre."""
    neutres = mots_neutres()
    noms = set()
    with gzip.open(chemin, "rt", encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter=";"):
            mots = re.split(r"\s+", r["NORM"].strip().lower())
            if not mots or not mots[0]:
                continue
            if mots[0] in DETERMINANTS:
                if len(mots) > 1 and mots[1] in neutres:
                    noms.add(r["NORM"])
            elif mots[0] in neutres:
                noms.add(r["NORM"])
    return sorted(noms)


def construit(n, seed, noms=None):
    noms = noms if noms is not None else noms_neutres()
    rng = random.Random(f"{seed}-commune-neutre")
    axes = [(f, c) for f in FAMILLES for c in ("capitales", "ordinaire")]
    docs = []
    for i in range(n):
        famille, casse = axes[i % len(axes)]
        nom = noms[(i // len(axes)) % len(noms)]
        nombre = str(rng.randrange(10_000, 99_999))
        texte = rng.choice(FAMILLES[famille]).format(n=nombre, w="\0")
        if casse == "capitales":
            texte = texte.upper().replace("\0", nom)
        else:
            texte = texte.replace("\0", nom.title()) + "."
        docs.append({"id": i, "text": texte, "entities": [],
                     "famille": famille, "casse": casse, "nom": nom})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=400)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_flou_commune_neutre.jsonl")
    a = p.parse_args()
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{a.out} : {len(docs)} phrases, 0 entite annotee")


if __name__ == "__main__":
    main()
