#!/usr/bin/env python3
"""Analyse de P2-296 (mesure) : refus de tableau et cellules envoyées.

Entrée : des triplets `ETIQUETTE|CORPUS.jsonl|PREDICTIONS.jsonl`, produits par
`packages/ecluse_redact/bin/run_redact_bench.dart` (donc par `Ecluse.redact`,
le chemin du produit : ce que reçoit le LLM). Pour chaque triplet :

- documents refusés (`refuse` : `TableauAmbiguException`, rien n'est envoyé) ;
- entités annotées couvertes en entier par une entité prédite, sur les
  documents non refusés (une entité annotée est « envoyée » quand elle ne l'est
  pas) ;
- documents envoyés avec au moins une entité annotée non couverte (« envoyés à
  tort » : un tableau non reconnu laisse ses cellules en clair).

Aucune valeur du texte n'est imprimée : des comptes seulement.

Usage : python3 analyse_tableaux_faux.py 'etiquette|corpus|pred' ...
"""
import json
import sys


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def couvert(e, preds):
    """Vrai si [start, end) est entièrement couvert par l'union des prédictions."""
    pos = e["start"]
    for p in sorted(preds, key=lambda p: p["start"]):
        if p["end"] <= pos:
            continue
        if p["start"] > pos:
            return False
        pos = p["end"]
        if pos >= e["end"]:
            return True
    return pos >= e["end"]


def analyse(corpus, pred):
    par_id = {d["id"]: d for d in pred}
    refuses, envoyes_a_tort = [], []
    annotees = couvertes = 0
    for d in corpus:
        p = par_id[d["id"]]
        if p.get("refuse"):
            refuses.append(d["id"])
            continue
        non_couverts = 0
        for e in d["entities"]:
            annotees += 1
            if couvert(e, p["entities"]):
                couvertes += 1
            else:
                non_couverts += 1
        if non_couverts:
            envoyes_a_tort.append(d["id"])
    return refuses, annotees, couvertes, envoyes_a_tort


def main():
    print("%-44s %5s %7s %9s %9s %9s" % (
        "série", "docs", "refusés", "annotées", "couvertes", "docs à tort"))
    for arg in sys.argv[1:]:
        etiquette, c, p = arg.split("|")
        corpus, pred = charge(c), charge(p)
        refuses, annot, couv, tort = analyse(corpus, pred)
        print("%-44s %5d %7d %9d %9d %9d" % (
            etiquette, len(corpus), len(refuses), annot, couv, len(tort)))
        if len(refuses) <= 6 and refuses:
            print("    refusés : %s" % refuses)


if __name__ == "__main__":
    main()
