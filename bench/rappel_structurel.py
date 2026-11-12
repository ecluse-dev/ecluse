#!/usr/bin/env python3
"""Rappel par type des identifiants structurels, d'apres des predictions au
format de `run_redact_bench.dart` (P2-153).

Pourquoi a cote de `score.py` : `score.py` compare type a type et compte les
faux positifs, ce qui n'a pas de sens ici (`Ecluse.redact` detecte aussi les
noms et les adresses du corpus structurel). On veut une seule chose : chaque
identifiant annote est-il entierement couvert par une detection, quel qu'en
soit le type ? C'est ce qui decide s'il part en clair.

Usage :
    python3 rappel_structurel.py --corpus corpus.jsonl --pred pred.jsonl
"""

import argparse
import collections
import json


def rappel(corpus, pred):
    """Rend {type: (couverts, total)} ; blancs internes ignores."""
    preds = {d["id"]: d for d in pred}
    total, couverts = collections.Counter(), collections.Counter()
    for doc in corpus:
        couvert = set()
        for e in preds[doc["id"]].get("entities", []):
            couvert.update(range(e["start"], e["end"]))
        for e in doc["entities"]:
            t = e["type"].lower()
            total[t] += 1
            couverts[t] += all(
                i in couvert for i in range(e["start"], e["end"])
                if not doc["text"][i].isspace())
    return {t: (couverts[t], total[t]) for t in sorted(total)}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--corpus", required=True)
    p.add_argument("--pred", required=True)
    a = p.parse_args()
    with open(a.corpus, encoding="utf-8") as f:
        corpus = [json.loads(l) for l in f if l.strip()]
    with open(a.pred, encoding="utf-8") as f:
        pred = [json.loads(l) for l in f if l.strip()]
    r = rappel(corpus, pred)
    ok = sum(c for c, _ in r.values())
    n = sum(t for _, t in r.values())
    print("  ".join(f"{t} {c}/{tot}" for t, (c, tot) in r.items())
          + f"  TOTAL {ok}/{n} ({100 * ok / max(1, n):.1f} %)")


if __name__ == "__main__":
    main()
