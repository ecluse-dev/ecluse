#!/usr/bin/env python3
"""Score du corpus « fuite par OCR sans libellé » (P2-264).

Chemin mesuré : celui des prédictions fournies (`run_redact_bench.dart` =
`Ecluse.redact`, ce que reçoit le LLM). Par type d'identifiant, confusion et
présentation : nombre de documents, part entièrement couverte (aucun caractère
non blanc en clair), fuite au caractère. Sur le témoin négatif : nombre de
documents où au moins une prédiction apparaît (masquage en trop).
Ne lit ni n'imprime aucun texte.

Usage :
    python3 score_ocr.py --corpus flou/corpus_ocr.jsonl --pred flou/pred_ocr.jsonl
"""

import argparse
import collections
import json


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--corpus", required=True)
    p.add_argument("--pred", required=True)
    a = p.parse_args()
    with open(a.corpus, encoding="utf-8") as f:
        corpus = [json.loads(l) for l in f if l.strip()]
    with open(a.pred, encoding="utf-8") as f:
        preds = {d["id"]: d for d in map(json.loads, (l for l in f if l.strip()))}
    n = collections.Counter()
    entiers = collections.Counter()
    chars = collections.Counter()
    perdus = collections.Counter()
    # Témoins négatifs : « temoin » (400 d'origine, P2-264) et « temoin_dur »
    # (450, P2-268). Documents avec au moins une prédiction, et prédictions par
    # type prédit (jamais de texte).
    temoin = collections.Counter()
    temoin_pred = collections.Counter()
    temoin_types = collections.defaultdict(collections.Counter)
    for doc in corpus:
        pred = preds[doc["id"]].get("entities", [])
        if doc["presentation"].startswith("temoin"):
            pr = doc["presentation"]
            temoin[pr] += 1
            temoin_pred[pr] += bool(pred)
            for e in pred:
                temoin_types[pr][e["type"]] += 1
            continue
        couvert = set()
        for e in pred:
            couvert.update(range(e["start"], e["end"]))
        cle = (doc["type_id"], doc["confusion"], doc["presentation"])
        for e in doc["entities"]:
            idx = [i for i in range(e["start"], e["end"])
                   if not doc["text"][i].isspace()]
            n[cle] += 1
            nus = sum(i not in couvert for i in idx)
            entiers[cle] += nus == 0
            chars[cle] += len(idx)
            perdus[cle] += nus
    print(f"{'type':7} {'confusion':9} {'présentation':13} {'n':>4} "
          f"{'couverts':>9} {'fuite car.':>10}")
    tot = collections.Counter()
    for cle in sorted(n):
        t, c, pr = cle
        print(f"{t:7} {c:9} {pr:13} {n[cle]:4} "
              f"{entiers[cle]:4}/{n[cle]:<4} {100 * perdus[cle] / chars[cle]:9.1f} %")
        tot[(t, pr)] += n[cle]
    print()
    for pr in ("libelle", "sans_libelle"):
        for t in ("nir", "rpps", "iban", "finess", "siren"):
            ks = [k for k in n if k[0] == t and k[2] == pr]
            nn = sum(n[k] for k in ks)
            cc = sum(entiers[k] for k in ks)
            ch = sum(chars[k] for k in ks)
            pp = sum(perdus[k] for k in ks)
            print(f"TOTAL {t:7} {pr:13} couverts {cc:4}/{nn:<4} "
                  f"fuite {100 * pp / ch:5.1f} %")
    for pr in sorted(temoin):
        types = ", ".join(f"{t} {c}" for t, c in sorted(temoin_types[pr].items()))
        print(f"\ntémoin négatif {pr} : {temoin_pred[pr]} / {temoin[pr]} documents "
              f"avec une prédiction ({types or 'aucun type'})")


if __name__ == "__main__":
    main()
