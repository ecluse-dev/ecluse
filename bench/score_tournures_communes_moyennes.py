#!/usr/bin/env python3
"""Scoreur du témoin « communes moyennes derrière une tournure » (P2-238).

D'après des prédictions au format de `run_redact_bench.dart` : **`Ecluse.redact`**
(ce que reçoit le LLM), document par document. Un lieu est **masqué à tort**
si au moins une détection recouvre la commune (aucune personne dans ce témoin :
de la lisibilité perdue, pas une fuite). N'imprime que des comptes, par tranche
de population et par tournure, avec le détail « à la demande de » par tranche.

Usage :
    python3 score_tournures_communes_moyennes.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json

import generate_corpus_tournures_communes_moyennes as g


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def recouvre(ents, lieu):
    return any(e["start"] < lieu["end"] and e["end"] > lieu["start"]
               for e in ents)


def mesure(corpus, pred):
    preds = {p["id"]: p for p in pred}
    par = collections.defaultdict(collections.Counter)
    for doc in corpus:
        ents = preds[doc["id"]].get("entities", [])
        masque = recouvre(ents, doc["lieu"])
        for cle in (("tranche", doc["tranche"]), ("tournure", doc["tournure"]),
                    ("tranche_tournure", f"{doc['tranche']} / "
                                         f"{doc['tournure']}"),
                    ("total", "*")):
            par[cle]["documents"] += 1
            par[cle]["masques"] += masque
    return par


def affiche(corpus, par):
    t = par[("total", "*")]
    n_ent = sum(d["entities"] != [] for d in corpus)
    print(f"communes moyennes : {t['documents']} documents, {n_ent} entité(s) "
          f"annotée(s), {t['masques']} lieux masqués à tort")
    ordre = {
        "tranche": [n for n, _, _ in g.TRANCHES],
        "tournure": g.TOURNURES,
        "tranche_tournure": [f"{n} / {t}" for n, _, _ in g.TRANCHES
                             for t in g.TOURNURES],
    }
    for axe, valeurs in ordre.items():
        for v in valeurs:
            c = par[(axe, v)]
            if not c["documents"]:
                continue
            print(f"  {axe}={v} : {c['masques']} / {c['documents']} lieux "
                  "masqués à tort")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    a = ap.parse_args()
    corpus = charge(a.corpus)
    affiche(corpus, mesure(corpus, charge(a.pred)))


if __name__ == "__main__":
    main()
