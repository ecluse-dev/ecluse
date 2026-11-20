#!/usr/bin/env python3
"""Sonde « prénom + verbe conjugué » (P2-235, P2-240).

Sans majuscule hors début de phrase, `NomMinusculesDetector` lit « un prénom
connu suivi d'un mot » comme un nom de deux mots (confiance 0,5) : dans
« Sophie rappelle. », il propose « Sophie rappelle » en entier. Le verbe est
alors masqué, puis retenu comme patronyme établi (`patronymeEtabli`) et masqué
ailleurs, y compris dans les documents suivants d'un dossier. Exigence du
mainteneur (20 novembre) : **aucun verbe ne doit être masqué**.

Ce corpus rend la sonde de P2-235 reproductible. Deux familles, 10 prénoms
courants chacune, une phrase « Prénom verbe. » par couple :

- `courants` : 40 verbes conjugués d'usage courant (3e personne du singulier) ;
- `reserve` : 20 autres verbes, **choisis après l'écriture de la liste fermée
  du détecteur et vérifiés absents** (un test le contrôle), pour mesurer ce
  qu'une liste fermée ne couvre pas ; ils ne servent pas à la régler. Une
  première réserve avait été écrite avant la liste, qui en a repris 15 verbes :
  elle ne mesurait rien et a été remplacée.

Chaque document annote le seul prénom (`nom`). Le verbe n'est jamais annoté : toute
détection qui dépasse le prénom est un verbe masqué (de la lisibilité perdue).
`mot` porte les positions du prénom et `verbe` celles du verbe.

Valeurs synthétiques : aucun texte réel, aucune personne réelle.

Usage :
    python3 generate_corpus_prenom_verbe.py --seed 42 \\
        --out flou/corpus_prenom_verbe.jsonl
"""

import argparse
import json
import random

PRENOMS = ["Sophie", "Marc", "Julien", "Nathalie", "Thomas", "Isabelle",
           "Laurent", "Camille", "Nicolas", "Céline"]

COURANTS = [
    "rappelle", "appelle", "arrive", "vient", "veut", "doit", "peut", "entre",
    "passe", "demande", "répond", "parle", "travaille", "mange", "dort",
    "dit", "fait", "prend", "donne", "cherche", "trouve", "attend",
    "commence", "finit", "reste", "sort", "part", "regarde", "écoute",
    "pense", "pose", "montre", "change", "garde", "joue", "lit", "écrit",
    "voit", "sait", "vit",
]

RESERVE = [
    "sollicite", "mentionne", "rédige", "planifie", "annule", "reporte", "déclare",
    "conteste", "résume", "supervise", "distribue", "commande", "livre", "rembourse",
    "reconnaît", "renonce", "persiste", "félicite", "regrette", "encaisse",
]

FAMILLES = {"courants": COURANTS, "reserve": RESERVE}


def construit(seed):
    docs = []
    for famille, verbes in FAMILLES.items():
        for prenom in PRENOMS:
            for verbe in verbes:
                texte = f"{prenom} {verbe}."
                docs.append({
                    "text": texte, "famille": famille,
                    "mot": {"start": 0, "end": len(prenom)},
                    "verbe": {"start": len(prenom) + 1,
                              "end": len(prenom) + 1 + len(verbe)},
                    "entities": [{"type": "nom", "start": 0,
                                  "end": len(prenom)}],
                })
    random.Random(f"{seed}:prenom_verbe").shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    docs = construit(a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out} (un prénom annoté chacun)")


if __name__ == "__main__":
    main()
