#!/usr/bin/env python3
"""Témoin « communes moyennes derrière une tournure de personne » (P2-238).

P2-233 a chiffré un seuil de population pour la liste des communes que
`NameDetector` n'écarte plus derrière « à la demande de » (aujourd'hui 10 000
habitants et plus), mais son témoin `lieu` (P2-218) ne contient que de grandes
villes (toutes au-dessus de 89 000 habitants). Ce témoin-ci ajoute des **lieux
de 10 000 à 100 000 habitants**, tirés du référentiel versionné
(`geo_communes.csv.gz`, INSEE, Licence Ouverte v2.0), pour chiffrer le coût
réel d'un seuil de 100 000 : une phrase « à la demande de Dole » est un lieu,
la masquer est une lisibilité perdue, pas une fuite.

**Aucune personne n'y figure** : aucune entité annotée. Chaque document place
une commune dans une des quatre tournures de P2-220 (mêmes gabarits que
`generate_corpus_tournures_personne.py`). Trois tranches de population
municipale, `TOUR` communes tirées dans chacune (graine explicite, tirage trié
par code commune) :

- `10-30k` : 10 000 à 29 999 habitants ;
- `30-50k` : 30 000 à 49 999 ;
- `50-100k` : 50 000 à 99 999.

Chaque commune est placée une fois dans chaque tournure. Les documents portent
`tranche`, `pmun` (population) et `lieu` (début et fin de la commune dans le
texte) : le scoreur n'imprime que des comptes. Les communes sans population
dans le fichier (Paris, Lyon, Marseille, Mayotte) ne sont pas tirées : le
témoin de P2-218 les contient déjà.

Usage :
    python3 generate_corpus_tournures_communes_moyennes.py --seed 42 \\
        --out flou/corpus_tournures_communes_moyennes.jsonl
"""

import argparse
import gzip
import json
import os
import random

import generate_corpus_tournures_personne as gp

ICI = os.path.dirname(os.path.abspath(__file__))
COMMUNES = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")

TOURNURES = gp.TOURNURES
GABARITS = gp.GABARITS
TRANCHES = [("10-30k", 10000, 30000), ("30-50k", 30000, 50000),
            ("50-100k", 50000, 100000)]
TOUR = 20  # communes par tranche : 60 au total, au moins 40


def lit_communes(chemin=COMMUNES):
    """[(code, libellé, population)] des communes de population renseignée."""
    res = []
    with gzip.open(chemin, "rt", encoding="utf-8") as f:
        next(f)
        for ligne in f:
            c = ligne.rstrip("\n").split(";")
            if len(c) < 6 or not c[5] or not c[3].strip().isdigit():
                continue
            res.append((c[0], c[5], int(c[3])))
    return sorted(res)


def tire(communes, seed, par_tranche=TOUR):
    """{tranche: [(code, libellé, pmun)]} : tirage seedé, trié par code."""
    rng = random.Random(f"{seed}:communes_moyennes")
    tirage = {}
    for nom, bas, haut in TRANCHES:
        pool = [c for c in communes if bas <= c[2] < haut]
        tirage[nom] = sorted(rng.sample(pool, par_tranche))
    return tirage


def construit(seed, communes=None):
    tirage = tire(communes if communes is not None else lit_communes(), seed)
    docs = []
    for tranche, lieux in tirage.items():
        for code, libelle, pmun in lieux:
            for tournure in TOURNURES:
                docs.append((tranche, pmun, libelle, tournure))
    random.Random(f"{seed}:ordre_communes_moyennes").shuffle(docs)
    sortie = []
    for i, (tranche, pmun, libelle, tournure) in enumerate(docs):
        entete = f"Dossier de suivi — pièce {i % 6 + 1}\n\n"
        phrase = GABARITS[tournure].format(libelle)
        texte = entete + phrase
        debut = len(entete) + phrase.index(libelle)
        sortie.append({"id": i, "text": texte, "entities": [],
                       "tournure": tournure, "tranche": tranche,
                       "pmun": pmun,
                       "lieu": {"start": debut, "end": debut + len(libelle)}})
    return sortie


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    docs = construit(a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out} (aucune entité annotée)")


if __name__ == "__main__":
    main()
