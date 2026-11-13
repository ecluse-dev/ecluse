#!/usr/bin/env python3
"""Entites annotees coupees par une fin de ligne : couvertes, en partie en
clair ou entierement en clair (P2-173).

Pourquoi a cote de `score_flou.py` : la fuite au caractere d'un corpus recoupe
melange les entites qui tiennent sur une ligne (inchangees) et celles qu'un
retour a la ligne coupe en deux. Ce script ne regarde que les secondes, par
type : c'est la mesure du defaut « un nom d'etablissement ou de commune coupe
par une fin de ligne reste en clair ».

Chemin mesure : celui des predictions fournies (au tableau de bord,
`run_redact_bench.dart`, donc `Ecluse.redact`). Les documents refuses
(`"refuse": true`) sont exclus : rien n'en est envoye.

Usage :
    python3 entites_coupees.py --corpus corpus_l90.jsonl --pred pred_l90.jsonl
"""

import argparse
import collections
import json

TYPES = ("adresse", "etablissement")


def coupees(corpus, pred, types=TYPES):
    """Rend {type: {"coupees": n, "couvertes": n, "partielles": n,
    "en_clair": n, "caracteres_en_clair": n}} ; blancs ignores."""
    preds = {d["id"]: d for d in pred}
    res = {t: collections.Counter() for t in types}
    for doc in corpus:
        p = preds.get(doc["id"])
        if p is None or p.get("refuse"):
            continue
        texte = doc["text"]
        couvert = set()
        for e in p.get("entities", []):
            couvert.update(range(e["start"], e["end"]))
        for e in doc["entities"]:
            t = e["type"].lower()
            if t not in res or "\n" not in texte[e["start"]:e["end"]]:
                continue
            utiles = [i for i in range(e["start"], e["end"])
                      if not texte[i].isspace()]
            clairs = [i for i in utiles if i not in couvert]
            res[t]["coupees"] += 1
            res[t]["caracteres_en_clair"] += len(clairs)
            if not clairs:
                res[t]["couvertes"] += 1
            elif len(clairs) == len(utiles):
                res[t]["en_clair"] += 1
            else:
                res[t]["partielles"] += 1
    return res


def ligne(res):
    morceaux = []
    for t in sorted(res):
        r = res[t]
        morceaux.append(
            f"{t} {r['coupees']} coupées ({r['couvertes']} couvertes, "
            f"{r['partielles']} en partie en clair, {r['en_clair']} "
            f"entièrement en clair, {r['caracteres_en_clair']} car.)")
    return "  entités coupées par une fin de ligne : " + " ; ".join(morceaux)


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    args = ap.parse_args()
    print(ligne(coupees(charge(args.corpus), charge(args.pred))))


if __name__ == "__main__":
    main()
