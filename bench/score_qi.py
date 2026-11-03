#!/usr/bin/env python3
"""Scoreur des corpus de quasi-identifiants (QI).  (P2-03a)

Compare les QI extraits (profession, lieu, age) a l'annotation de
`generate_corpus_qi.py`. Quatre mesures, jamais une seule :

  1. STRICT   — span exact + type. Borne basse honnete.
  2. SOUPLE   — chevauchement >= 1 caractere + type. A lire EN REGARD du
                strict : l'ecart mesure la qualite des frontieres de span.
  3. NON COUVERTS — part des caracteres de QI annotes qu'aucune extraction
                du MEME type ne recouvre. C'est l'equivalent de la « fuite au
                caractere » de score_flou.py, mais pour une extraction : un
                QI non extrait ne sera ni estime ni signale.
  4. STATUTS  — si les predictions portent un champ « statut » par document,
                repartition des documents par statut (evalue, aucun QI
                detecte, non evaluable...). Ne juge pas le statut : le
                montre.

Sur le corpus temoin (aucune annotation), toute extraction est un faux
positif : le scoreur donne le nombre de detections et de documents touches.

Format des predictions (une ligne par document) :
  {"id": int, "entities": [{"type": str, "start": int, "end": int}],
   "statut": str (optionnel)}

Usage :
    python score_qi.py --corpus corpus_qi_realiste.jsonl \\
        --pred "Ecluse=pred_qi_realiste.jsonl"
"""

import argparse
import json
from collections import Counter, defaultdict

TYPES = ["profession", "lieu", "age"]


def charge(path):
    docs = {}
    for ligne in open(path, encoding="utf-8"):
        d = json.loads(ligne)
        docs[d["id"]] = d
    return docs


def _chevauche(a, b):
    return a["start"] < b["end"] and b["start"] < a["end"]


def apparie(or_, pred, strict):
    """(tp, fp, fn) par type, appariement un-pour-un.

    Strict : (type, start, end) identiques. Souple : meme type et
    chevauchement non vide, chaque prediction ne servant qu'une fois.
    """
    tp, fp, fn = Counter(), Counter(), Counter()
    for doc_id, golds in or_.items():
        preds = list(pred.get(doc_id, []))
        pris = [False] * len(preds)
        for g in golds:
            trouve = None
            for i, p in enumerate(preds):
                if pris[i] or p["type"] != g["type"]:
                    continue
                if strict:
                    ok = p["start"] == g["start"] and p["end"] == g["end"]
                else:
                    ok = _chevauche(p, g)
                if ok:
                    trouve = i
                    break
            if trouve is None:
                fn[g["type"]] += 1
            else:
                pris[trouve] = True
                tp[g["type"]] += 1
        for i, p in enumerate(preds):
            if not pris[i]:
                fp[p["type"]] += 1
    return tp, fp, fn


def non_couverts(or_, pred):
    """(total, non couverts) de caracteres de QI annotes, par type."""
    total, manque = Counter(), Counter()
    for doc_id, golds in or_.items():
        couvert = defaultdict(set)
        for p in pred.get(doc_id, []):
            couvert[p["type"]].update(range(p["start"], p["end"]))
        for g in golds:
            for k in range(g["start"], g["end"]):
                total[g["type"]] += 1
                if k not in couvert[g["type"]]:
                    manque[g["type"]] += 1
    return total, manque


def repartition_statuts(pred_docs):
    """Nombre de documents par statut, ou None si aucun statut n'est donne."""
    if not any("statut" in d for d in pred_docs.values()):
        return None
    return Counter(d.get("statut", "(absent)") for d in pred_docs.values())


def prf(tp, n_pred, n_gold):
    p = tp / n_pred if n_pred else 0.0
    r = tp / n_gold if n_gold else 0.0
    f = 2 * p * r / (p + r) if p + r else 0.0
    return p, r, f


def score(corpus, pred_docs):
    """Toutes les mesures d'un moteur sur un corpus, en un dictionnaire."""
    or_ = {i: d["entities"] for i, d in corpus.items()}
    pred = {i: d.get("entities", []) for i, d in pred_docs.items()}
    out = {"documents": len(corpus), "types": {}}
    n_gold = Counter(e["type"] for es in or_.values() for e in es)
    n_pred = Counter(e["type"] for es in pred.values() for e in es)
    res = {m: apparie(or_, pred, m == "strict") for m in ("strict", "souple")}
    total, manque = non_couverts(or_, pred)
    for t in sorted(set(TYPES) | set(n_gold) | set(n_pred)):
        ligne = {"annotes": n_gold[t], "predits": n_pred[t]}
        for m, (tp, fp, fn) in res.items():
            p, r, f = prf(tp[t], n_pred[t], n_gold[t])
            ligne[m] = {"tp": tp[t], "fp": fp[t], "fn": fn[t],
                        "precision": p, "rappel": r, "f1": f}
        ligne["non_couverts"] = (manque[t] / total[t]) if total[t] else None
        out["types"][t] = ligne
    out["documents_avec_detection"] = sum(1 for es in pred.values() if es)
    out["detections"] = sum(n_pred.values())
    out["statuts"] = repartition_statuts(pred_docs)
    # Rappel strict selon le nombre de personnes (documents multi-personnes).
    par_groupe = {}
    for nom, filtre in (("une personne", lambda d: d.get("personnes", 1) == 1),
                        ("plusieurs personnes",
                         lambda d: d.get("personnes", 1) >= 2)):
        ids = [i for i, d in corpus.items() if filtre(d)]
        sous = {i: or_[i] for i in ids}
        tp, _, _ = apparie(sous, pred, True)
        gold = sum(len(v) for v in sous.values())
        par_groupe[nom] = {"documents": len(ids), "annotes": gold,
                           "rappel_strict": (sum(tp.values()) / gold)
                           if gold else None}
    out["par_groupe"] = par_groupe
    return out


def pct(x):
    return "    —  " if x is None else f"{100 * x:6.1f}%"


def rapport(nom, s, sans_annotation):
    print("=" * 78)
    print(nom)
    print("=" * 78)
    if sans_annotation:
        print("Corpus témoin — toute extraction est un faux positif.\n")
        print(f"  Extractions totales      : {s['detections']}")
        print(f"  Documents avec extraction : {s['documents_avec_detection']}"
              f" / {s['documents']}")
    else:
        print(f"{'type':12s} {'annotés':>8s} {'prédits':>8s} {'P-str':>7s} "
              f"{'R-str':>7s} {'F1-str':>7s} {'F1-souple':>9s} "
              f"{'non couverts':>13s}")
        print("-" * 78)
        for t, l in s["types"].items():
            if not l["annotes"] and not l["predits"]:
                continue
            print(f"{t:12s} {l['annotes']:8d} {l['predits']:8d} "
                  f"{pct(l['strict']['precision'])} {pct(l['strict']['rappel'])}"
                  f" {pct(l['strict']['f1'])} {pct(l['souple']['f1']):>9s} "
                  f"{pct(l['non_couverts']):>13s}")
        print("\nRappel strict selon le nombre de personnes :")
        for g, v in s["par_groupe"].items():
            print(f"  {g:20s} {v['documents']:4d} documents, "
                  f"{v['annotes']:4d} QI, rappel {pct(v['rappel_strict'])}")
    if s["statuts"] is not None:
        print("\nDocuments par statut :")
        for statut, n in sorted(s["statuts"].items()):
            print(f"  {statut:28s} {n:5d}  ({100 * n / s['documents']:.1f} %)")
    if not sans_annotation:
        print("\nLecture : « non couverts » est la mesure de référence ; le F1\n"
              "souple ne se cite pas comme rappel.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", action="append", required=True,
                    help='format "NomMoteur=fichier.jsonl" (répétable)')
    args = ap.parse_args()
    corpus = charge(args.corpus)
    sans_annotation = not any(d["entities"] for d in corpus.values())
    print(f"Corpus : {args.corpus} — {len(corpus)} documents, "
          f"{sum(len(d['entities']) for d in corpus.values())} QI annotés\n")
    for spec in args.pred:
        nom, _, chemin = spec.partition("=")
        rapport(nom, score(corpus, charge(chemin)), sans_annotation)


if __name__ == "__main__":
    main()
