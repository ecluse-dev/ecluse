#!/usr/bin/env python3
"""Aligne annotations et predictions pour un type donne.

Repond a la question : quand F1-strict est bas mais F1-souple eleve,
QUELLE partie de l'entite est manquee ?

Usage :
    python diag_type.py corpus.jsonl predictions.jsonl nom
"""

import json
import sys
from collections import Counter


def load(path):
    out = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                d = json.loads(line)
                out[d["id"]] = d
    return out


def main():
    corpus = load(sys.argv[1])
    preds = load(sys.argv[2])
    cible = sys.argv[3]

    exemples = []
    motifs = Counter()
    fuites = Counter()
    n_exact = n_partiel = n_absent = 0

    for doc_id, doc in corpus.items():
        text = doc["text"]
        pred = [e for e in preds.get(doc_id, {}).get("entities", [])]
        couvert = set()
        for e in pred:
            couvert.update(range(e["start"], e["end"]))

        for g in doc.get("entities", []):
            if g["type"] != cible:
                continue
            gfrag = text[g["start"]:g["end"]]

            # Predictions chevauchant cette entite
            chevauche = [p for p in pred
                         if p["start"] < g["end"] and g["start"] < p["end"]]

            if not chevauche:
                n_absent += 1
                motifs["AUCUNE detection"] += 1
                if len(exemples) < 20:
                    exemples.append((gfrag, "(rien)", gfrag))
                continue

            p = chevauche[0]
            pfrag = text[p["start"]:p["end"]]

            if p["start"] == g["start"] and p["end"] == g["end"]:
                n_exact += 1
                motifs["frontieres exactes"] += 1
                continue

            n_partiel += 1
            # Caracteres de l'entite laisses en clair
            perdu = "".join(text[i] for i in range(g["start"], g["end"])
                            if i not in couvert)
            if perdu:
                fuites[perdu] += 1

            if p["start"] > g["start"] and p["end"] >= g["end"]:
                motifs["debut tronque"] += 1
            elif p["start"] <= g["start"] and p["end"] < g["end"]:
                motifs["fin tronquee"] += 1
            elif p["start"] > g["start"] and p["end"] < g["end"]:
                motifs["deux bouts tronques"] += 1
            else:
                motifs["prediction plus large"] += 1

            if len(exemples) < 20:
                exemples.append((gfrag, pfrag, perdu))

    total = n_exact + n_partiel + n_absent
    print(f"Type analyse : {cible}  ({total} entites annotees)\n")
    print(f"  frontieres exactes : {n_exact}")
    print(f"  partielles         : {n_partiel}")
    print(f"  non detectees      : {n_absent}\n")

    print("Motifs :")
    for m, n in motifs.most_common():
        print(f"  {n:5d}  {m}")

    if fuites:
        print("\nFragments laisses en clair (les plus frequents) :")
        for f, n in fuites.most_common(15):
            print(f"  {n:5d}  {f!r}")

    print("\nExemples  annote -> detecte  [fuite] :")
    for g, p, perdu in exemples[:15]:
        print(f"  {g!r:42s} -> {p!r:34s} [{perdu!r}]")


if __name__ == "__main__":
    main()
