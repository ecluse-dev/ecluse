#!/usr/bin/env python3
"""Scoreur du témoin « tournures de nom de personne, sans personne » (P2-218).

D'après des prédictions au format de `run_redact_bench.dart` : **`Ecluse.redact`**
(ce que reçoit le LLM). Aucune entité annotée : un document dont au moins une
détection existe est un masquage en trop (lisibilité perdue, pas une fuite).
Comptes par tournure, par genre de remplissage et par type détecté. Jamais de
texte.

Usage :
    python3 score_tournures_sans_nom.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def mesure(corpus, pred):
    preds = {p["id"]: p for p in pred}
    par = collections.defaultdict(collections.Counter)
    types = collections.Counter()
    for doc in corpus:
        ents = preds[doc["id"]].get("entities", [])
        for cle in (("tournure", doc["tournure"]), ("genre", doc["genre"]),
                    ("total", "*")):
            par[cle]["documents"] += 1
            par[cle]["masques"] += bool(ents)
        for e in ents:
            types[e["type"]] += 1
    return par, types


def affiche(corpus, par, types):
    t = par[("total", "*")]
    n_ent = sum(d["entities"] != [] for d in corpus)
    print(f"tournures sans nom : {t['documents']} documents, {n_ent} entité(s) "
          f"annotée(s), {t['masques']} masqués à tort")
    for axe in ("tournure", "genre"):
        vus = []
        for d in corpus:
            if d[axe] not in vus:
                vus.append(d[axe])
        for v in vus:
            c = par[(axe, v)]
            print(f"  {axe}={v} : {c['masques']} / {c['documents']} masqués à tort")
    detail = ", ".join(f"{k} {v}" for k, v in sorted(types.items())) or "aucun"
    print(f"  types sur les masquages à tort : {detail}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    a = ap.parse_args()
    corpus = charge(a.corpus)
    par, types = mesure(corpus, charge(a.pred))
    affiche(corpus, par, types)


if __name__ == "__main__":
    main()
