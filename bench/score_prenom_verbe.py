#!/usr/bin/env python3
"""Scoreur de la sonde « prénom + verbe » (P2-240).

D'après des prédictions au format de `run_redact_bench.dart` : **`Ecluse.redact`**
(ce que reçoit le LLM). Un **verbe masqué** : une détection qui recouvre le
verbe. Une **fuite** : le prénom annoté sans aucune détection. N'imprime que des
comptes, par famille. Jamais de texte.

Usage :
    python3 score_prenom_verbe.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def recouvre(ents, plage):
    return any(e["start"] < plage["end"] and e["end"] > plage["start"]
               for e in ents)


def mesure(corpus, pred):
    preds = {p["id"]: p for p in pred}
    par = collections.defaultdict(collections.Counter)
    for doc in corpus:
        ents = preds[doc["id"]].get("entities", [])
        for cle in (doc["famille"], "*"):
            par[cle]["documents"] += 1
            par[cle]["verbes"] += recouvre(ents, doc["verbe"])
            par[cle]["fuites"] += not recouvre(ents, doc["mot"])
    return par


def affiche(par):
    t = par["*"]
    print(f"prénom + verbe : {t['documents']} phrases, {t['verbes']} verbes "
          f"masqués, {t['fuites']} prénoms en clair (fuite)")
    for famille in ("courants", "reserve"):
        c = par[famille]
        print(f"  famille={famille} : {c['verbes']} / {c['documents']} verbes "
              f"masqués, {c['fuites']} prénoms en clair")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    a = ap.parse_args()
    affiche(mesure(charge(a.corpus), charge(a.pred)))


if __name__ == "__main__":
    main()
