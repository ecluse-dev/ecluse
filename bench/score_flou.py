#!/usr/bin/env python3
"""Scoreur pour les corpus d'entites floues.

Trois niveaux de mesure, jamais un seul :

  1. STRICT   — span exact + type. Borne basse honnete.
  2. SOUPLE   — chevauchement >= 1 caractere + type. A lire EN REGARD du
                strict : l'ecart entre les deux mesure la qualite des
                frontieres de span.
  3. FUITE    — proportion des caracteres sensibles restes en clair.
                LA metrique de reference : c'est la seule qui repond a la
                question « quelle part de l'information sensible part
                reellement vers le LLM ? ».

Pourquoi la fuite prime : « Mademoiselle Camille Verdier » detecte comme
« [NOM_1] Verdier » est un SUCCES en souple alors que le patronyme a fui.
La fuite au caractere, elle, compte correctement les 7 caracteres perdus.

Pour la fuite, un caractere est considere protege s'il est couvert par
N'IMPORTE QUELLE prediction, quel que soit son type : masquer un nom en
croyant masquer une adresse protege quand meme la personne.

Format attendu (corpus et predictions) :
  {"id": int, "text": str, "entities": [{"type": str, "start": int, "end": int}]}
Le champ "text" n'est requis que dans le corpus.

Usage :
    python score_flou.py --corpus corpus_flou_realiste.jsonl \\
        --pred "Ecluse=pred_ecluse_realiste.jsonl" \\
        --pred "Presidio=pred_presidio_realiste.jsonl"
"""

import argparse
import json
from collections import defaultdict


def load(path):
    out = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                d = json.loads(line)
                out[d["id"]] = d
    return out


def covered_chars(spans):
    """Ensemble des indices de caracteres couverts par une liste de spans."""
    s = set()
    for e in spans:
        s.update(range(e["start"], e["end"]))
    return s


def score(corpus, preds):
    # Compteurs par type
    strict_tp = defaultdict(int)
    souple_tp = defaultdict(int)
    n_gold = defaultdict(int)
    n_pred = defaultdict(int)
    chars_gold = defaultdict(int)
    chars_fuite = defaultdict(int)

    # Sur-masquage global
    chars_pred_total = 0
    chars_pred_hors_gold = 0
    chars_texte_total = 0

    for doc_id, doc in corpus.items():
        gold = doc.get("entities", [])
        pred = preds.get(doc_id, {}).get("entities", [])
        chars_texte_total += len(doc.get("text", ""))

        for e in gold:
            n_gold[e["type"]] += 1
        for e in pred:
            n_pred[e["type"]] += 1

        # --- strict : appariement 1-1 sur (type, start, end)
        pred_libres = list(pred)
        for g in gold:
            for i, p in enumerate(pred_libres):
                if (p["type"] == g["type"] and p["start"] == g["start"]
                        and p["end"] == g["end"]):
                    strict_tp[g["type"]] += 1
                    pred_libres.pop(i)
                    break

        # --- souple : appariement 1-1 sur chevauchement + type
        pred_libres = list(pred)
        for g in gold:
            for i, p in enumerate(pred_libres):
                if (p["type"] == g["type"] and p["start"] < g["end"]
                        and g["start"] < p["end"]):
                    souple_tp[g["type"]] += 1
                    pred_libres.pop(i)
                    break

        # --- fuite au caractere : couverture par N'IMPORTE quel span predit
        protege = covered_chars(pred)
        for g in gold:
            longueur = g["end"] - g["start"]
            chars_gold[g["type"]] += longueur
            fuite = sum(1 for i in range(g["start"], g["end"]) if i not in protege)
            chars_fuite[g["type"]] += fuite

        # --- sur-masquage
        gold_chars = covered_chars(gold)
        chars_pred_total += len(protege)
        chars_pred_hors_gold += len(protege - gold_chars)

    return {
        "strict_tp": strict_tp, "souple_tp": souple_tp,
        "n_gold": n_gold, "n_pred": n_pred,
        "chars_gold": chars_gold, "chars_fuite": chars_fuite,
        "chars_pred_total": chars_pred_total,
        "chars_pred_hors_gold": chars_pred_hors_gold,
        "chars_texte_total": chars_texte_total,
    }


def prf(tp, n_pred, n_gold):
    p = tp / n_pred if n_pred else 0.0
    r = tp / n_gold if n_gold else 0.0
    f = 2 * p * r / (p + r) if (p + r) else 0.0
    return p, r, f


def rapport(nom, s):
    types = sorted(set(s["n_gold"]) | set(s["n_pred"]))
    print(f"\n{'=' * 78}\n{nom}\n{'=' * 78}")

    if not s["n_gold"]:
        # Corpus temoin : toute prediction est un faux positif.
        total = sum(s["n_pred"].values())
        pour_mille = (s["chars_pred_total"] / s["chars_texte_total"] * 100
                      if s["chars_texte_total"] else 0.0)
        print("Corpus temoin — toute detection est un faux positif.\n")
        print(f"  Detections totales      : {total}")
        print(f"  Caracteres sur-masques  : {s['chars_pred_total']} "
              f"({pour_mille:.2f} % du texte)")
        for t in types:
            if s["n_pred"][t]:
                print(f"    {t:16s} {s['n_pred'][t]:5d} faux positifs")
        if total == 0:
            print("  Aucun faux positif. ")
        return

    entete = (f"{'type':16s} {'gold':>5s} {'pred':>5s} "
              f"{'P-str':>7s} {'R-str':>7s} {'F1-str':>7s} "
              f"{'F1-soup':>8s} {'FUITE':>8s}")
    print(entete)
    print("-" * len(entete))

    for t in types:
        ps, rs, fs = prf(s["strict_tp"][t], s["n_pred"][t], s["n_gold"][t])
        _, _, fso = prf(s["souple_tp"][t], s["n_pred"][t], s["n_gold"][t])
        fuite = (s["chars_fuite"][t] / s["chars_gold"][t] * 100
                 if s["chars_gold"][t] else 0.0)
        print(f"{t:16s} {s['n_gold'][t]:5d} {s['n_pred'][t]:5d} "
              f"{ps:6.1%} {rs:6.1%} {fs:6.1%} {fso:7.1%} {fuite:7.1f}%")

    g_tp = sum(s["strict_tp"].values())
    g_tp_s = sum(s["souple_tp"].values())
    g_pred = sum(s["n_pred"].values())
    g_gold = sum(s["n_gold"].values())
    ps, rs, fs = prf(g_tp, g_pred, g_gold)
    _, _, fso = prf(g_tp_s, g_pred, g_gold)
    fuite_g = (sum(s["chars_fuite"].values()) / sum(s["chars_gold"].values()) * 100
               if sum(s["chars_gold"].values()) else 0.0)
    print("-" * len(entete))
    print(f"{'GLOBAL':16s} {g_gold:5d} {g_pred:5d} "
          f"{ps:6.1%} {rs:6.1%} {fs:6.1%} {fso:7.1%} {fuite_g:7.1f}%")

    surmasque = (s["chars_pred_hors_gold"] / s["chars_texte_total"] * 100
                 if s["chars_texte_total"] else 0.0)
    print(f"\nSur-masquage : {s['chars_pred_hors_gold']} caracteres masques a tort "
          f"({surmasque:.2f} % du texte)")
    print("\nLecture : FUITE est la metrique de reference. Un ecart large entre "
          "F1-str\net F1-soup signale des frontieres de span mal placees — "
          "souvent une fuite\npartielle que le F1 souple dissimule.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", action="append", default=[],
                    help='format "Nom=chemin.jsonl", repetable')
    args = ap.parse_args()

    corpus = load(args.corpus)
    print(f"Corpus : {args.corpus} — {len(corpus)} documents, "
          f"{sum(len(d.get('entities', [])) for d in corpus.values())} entites annotees")

    if not args.pred:
        print("\nAucune prediction fournie. Statistiques du corpus seulement.")
        return

    for spec in args.pred:
        nom, _, chemin = spec.partition("=")
        rapport(nom, score(corpus, load(chemin)))


if __name__ == "__main__":
    main()
