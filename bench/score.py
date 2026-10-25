#!/usr/bin/env python3
"""Compare les prédictions d'un ou plusieurs moteurs au corpus annoté.

Deux modes d'appariement :
  - strict  : span exact (start, end) et type identiques
  - souple  : chevauchement non vide et type identique

Usage :
    python3 score.py --corpus corpus.jsonl \\
        --pred "Écluse=predictions_ecluse.jsonl" \\
        --pred "Presidio=predictions_presidio.jsonl"
"""

import argparse
import json
from collections import defaultdict

TYPES = ["nir", "rpps", "iban", "finess"]


def load(path):
    docs = {}
    for line in open(path, encoding="utf-8"):
        d = json.loads(line)
        docs[d["id"]] = d["entities"]
    return docs


def match(gold, pred, strict):
    """Apparie prédictions et or ; retourne (tp, fp, fn) par type."""
    tp = defaultdict(int)
    fp = defaultdict(int)
    fn = defaultdict(int)
    used = set()
    for p in pred:
        hit = None
        for i, g in enumerate(gold):
            if i in used or g["type"] != p["type"]:
                continue
            if strict:
                good = g["start"] == p["start"] and g["end"] == p["end"]
            else:
                good = p["start"] < g["end"] and g["start"] < p["end"]
            if good:
                hit = i
                break
        if hit is None:
            fp[p["type"]] += 1
        else:
            used.add(hit)
            tp[p["type"]] += 1
    for i, g in enumerate(gold):
        if i not in used:
            fn[g["type"]] += 1
    return tp, fp, fn


def prf(tp, fp, fn):
    p = tp / (tp + fp) if tp + fp else 0.0
    r = tp / (tp + fn) if tp + fn else 0.0
    f = 2 * p * r / (p + r) if p + r else 0.0
    return p, r, f


def evaluate(gold_docs, pred_docs, strict, types=None):
    """Compte TP/FP/FN par type sur `types` (défaut : TYPES).

    Un type prédit mais absent de `types` serait sinon ignoré en silence
    (jamais compté en faux positif) et gonflerait la précision : `main`
    passe donc l'union des types annotés et prédits.
    """
    types = types or TYPES
    tot_tp = defaultdict(int)
    tot_fp = defaultdict(int)
    tot_fn = defaultdict(int)
    for doc_id, gold in gold_docs.items():
        pred = pred_docs.get(doc_id, [])
        tp, fp, fn = match(gold, pred, strict)
        for t in types:
            tot_tp[t] += tp[t]
            tot_fp[t] += fp[t]
            tot_fn[t] += fn[t]
    return tot_tp, tot_fp, tot_fn


def leakage(gold_docs, pred_docs, types):
    """Part des caractères annotés restés en clair, par type.

    Un caractère est protégé s'il est couvert par n'importe quelle
    prédiction, quel que soit son type (même convention que
    `score_flou.py`). Contrairement au mode SOUPLE, un recouvrement d'un
    seul caractère ne cache pas la fuite des autres.
    """
    total = defaultdict(int)
    leaked = defaultdict(int)
    for doc_id, gold in gold_docs.items():
        covered = set()
        for p in pred_docs.get(doc_id, []):
            covered.update(range(p["start"], p["end"]))
        for g in gold:
            if g["type"] not in types:
                continue
            for i in range(g["start"], g["end"]):
                total[g["type"]] += 1
                if i not in covered:
                    leaked[g["type"]] += 1
    return total, leaked


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", default="corpus.jsonl")
    parser.add_argument("--pred", action="append", required=True,
                        help='format "NomMoteur=fichier.jsonl" (répétable)')
    args = parser.parse_args()

    gold = load(args.corpus)
    n_gold = defaultdict(int)
    for ents in gold.values():
        for e in ents:
            n_gold[e["type"]] += 1

    all_preds = {}
    for spec in args.pred:
        name, path = spec.split("=", 1)
        all_preds[name] = load(path)

    # Types au-delà des quatre cibles historiques : annotés (ex. `adeli` du
    # profil extended) **ou prédits**. Un type prédit mais non annoté doit
    # apparaître comme faux positifs, jamais disparaître de la table.
    types = list(TYPES)
    extra = {t for t in n_gold if t not in types}
    for preds in all_preds.values():
        for ents in preds.values():
            extra.update(e["type"] for e in ents if e["type"] not in types)
    types.extend(sorted(extra))

    print(f"Corpus : {len(gold)} documents, "
          + ", ".join(f"{n_gold[t]} {t}" for t in types))

    for mode_name, strict in [("STRICT (span exact)", True),
                              ("SOUPLE (chevauchement)", False)]:
        print(f"\n=== Appariement {mode_name} ===")
        if not strict:
            print("(1 caractère de recouvrement suffit : ne pas citer comme "
                  "rappel ; voir la section FUITE ci-dessous)")
        header = f"{'Moteur':<10} {'Type':<6} {'Préc.':>7} {'Rappel':>7} {'F1':>7} {'TP':>5} {'FP':>5} {'FN':>5}"
        print(header)
        print("-" * len(header))
        for name, preds in all_preds.items():
            tp, fp, fn = evaluate(gold, preds, strict, types)
            for t in types + ["TOTAL"]:
                if t == "TOTAL":
                    a = sum(tp.values())
                    b = sum(fp.values())
                    c = sum(fn.values())
                else:
                    a, b, c = tp[t], fp[t], fn[t]
                p, r, f = prf(a, b, c)
                print(f"{name:<10} {t:<6} {p:>7.1%} {r:>7.1%} {f:>7.1%} {a:>5} {b:>5} {c:>5}")
            print()

    print("=== FUITE au caractère (caractères annotés restés en clair) ===")
    header = f"{'Moteur':<10} {'Type':<6} {'Annotés':>8} {'En clair':>9} {'Fuite':>7}"
    print(header)
    print("-" * len(header))
    for name, preds in all_preds.items():
        total, leaked = leakage(gold, preds, set(types))
        for t in types:
            if total[t]:
                print(f"{name:<10} {t:<6} {total[t]:>8} {leaked[t]:>9} "
                      f"{leaked[t] / total[t]:>7.1%}")
        print()


if __name__ == "__main__":
    main()
