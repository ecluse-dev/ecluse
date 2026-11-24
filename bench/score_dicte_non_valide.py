#!/usr/bin/env python3
"""P2-274 (mesure) : sur un corpus d'identifiants dictés abîmés, par type et par
variante, combien sont masqués en entier, signalés « nombre dicté non reconnu »
sans être masqués, et ni l'un ni l'autre (donc en clair sans avertissement).
Entrée : le corpus et la sortie de `run_temoin_nombres_dictes.dart`. Aucun texte
n'est imprimé, seulement des nombres.
"""
import argparse
import json
from collections import Counter, defaultdict


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    a = ap.parse_args()
    pred = {}
    for l in open(a.pred, encoding="utf-8"):
        d = json.loads(l)
        pred[d["id"]] = d
    c = defaultdict(Counter)
    for l in open(a.corpus, encoding="utf-8"):
        d = json.loads(l)
        e = d["entities"][0]
        p = pred[d["id"]]
        inter = sorted((x["start"], x["end"]) for x in p["entities"])
        pos, ok = e["start"], False
        for s, f in inter:
            if f <= pos:
                continue
            if s > pos:
                break
            pos = f
            if pos >= e["end"]:
                ok = True
                break
        sig = p["signalements"] > 0
        etat = ("masqué et signalé" if ok and sig else "masqué" if ok else
                "signalé seulement" if sig else "rien")
        for cle in (e["type"], "TOTAL"):
            c[cle]["n"] += 1
            c[cle][etat] += 1
    for cle in ("nir", "iban", "TOTAL"):
        x = c[cle]
        print(f"{cle:6} n={x['n']:5}  masqués={x['masqué']+x['masqué et signalé']:5} "
              f"(dont signalés {x['masqué et signalé']:4})  signalés seulement={x['signalé seulement']:5}  "
              f"rien={x['rien']:5}")


main()
