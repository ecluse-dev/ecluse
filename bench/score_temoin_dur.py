#!/usr/bin/env python3
"""Score du témoin durci « mots-nombres » (P2-270) : masquages à tort et
signalements « nombre dicté non reconnu » à tort, par famille de phrases et par
type prédit. Chemin : celui des prédictions fournies (`Ecluse.redact`). Ne lit ni
n'imprime aucun texte, sauf avec --exemples (phrases synthétiques).

Usage :
    python3 score_temoin_dur.py --corpus c.jsonl --pred p.jsonl [--exemples N]
"""

import argparse
import collections
import json


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--corpus", required=True)
    p.add_argument("--pred", required=True)
    p.add_argument("--exemples", type=int, default=0)
    a = p.parse_args()
    corpus = [json.loads(l) for l in open(a.corpus, encoding="utf-8") if l.strip()]
    pred = {d["id"]: d for d in map(json.loads, open(a.pred, encoding="utf-8"))}
    n = collections.Counter()
    a_tort = collections.Counter()
    signale = collections.Counter()
    types = collections.defaultdict(collections.Counter)
    exemples = []
    for d in corpus:
        f = d["famille"]
        r = pred[d["id"]]
        n[f] += 1
        if r["entities"]:
            a_tort[f] += 1
            for e in r["entities"]:
                types[f][e["type"]] += 1
            exemples.append((f, [e["type"] for e in r["entities"]], d["text"]))
        if r["signalements"]:
            signale[f] += 1
    print(f"{'famille':12} {'phrases':>7} {'masquées à tort':>16} {'signalées à tort':>17}  par type")
    for f in sorted(n):
        t = ", ".join(f"{k} {v}" for k, v in sorted(types[f].items())) or "—"
        print(f"{f:12} {n[f]:7} {a_tort[f]:16} {signale[f]:17}  {t}")
    tot_t = collections.Counter()
    for f in types:
        tot_t.update(types[f])
    t = ", ".join(f"{k} {v}" for k, v in sorted(tot_t.items())) or "—"
    print(f"{'TOTAL':12} {sum(n.values()):7} {sum(a_tort.values()):16} "
          f"{sum(signale.values()):17}  {t}")
    for f, ts, txt in exemples[:a.exemples]:
        print(f"  exemple [{f}] {ts} : {txt}")


if __name__ == "__main__":
    main()
