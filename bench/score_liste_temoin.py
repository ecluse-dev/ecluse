#!/usr/bin/env python3
"""Documents sans personne où une liste de patronymes provoque un masquage (P2-243).

Compte, dans les prédictions de `run_dossiers_bench.dart`, les documents d'un
corpus **sans entité annotée** qui ont au moins une détection de type `nom` :
chacun est un masquage en trop. Chemin mesuré : `Ecluse.redact` (ce que reçoit
le LLM). N'imprime que des comptes, jamais un texte ni un nom.

Usage : python3 score_liste_temoin.py ÉTIQUETTE corpus.jsonl pred.jsonl
"""

import json
import sys


def main():
    if len(sys.argv) != 4:
        sys.exit("usage : score_liste_temoin.py ÉTIQUETTE corpus.jsonl pred.jsonl")
    etiquette, corpus, pred = sys.argv[1:]
    sans_personne = {}
    for ligne in open(corpus, encoding="utf-8"):
        if ligne.strip():
            d = json.loads(ligne)
            if not d["entities"]:
                sans_personne[d["id"]] = False
    for ligne in open(pred, encoding="utf-8"):
        if ligne.strip():
            p = json.loads(ligne)
            if p["id"] in sans_personne:
                sans_personne[p["id"]] = any(
                    m["type"] == "nom" for m in p["mentions"])
    n = sum(sans_personne.values())
    print(f"{etiquette} : {n} / {len(sans_personne)} documents sans personne "
          f"avec un nom masqué")


if __name__ == "__main__":
    main()
