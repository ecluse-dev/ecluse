#!/usr/bin/env python3
"""Part de la fuite des noms qui n'est pas la civilite.  (P2-12)

Le README du benchmark attribuait la fuite des noms du corpus realiste a la
civilite conservee volontairement (« M. », « Mme »...). Ce script verifie
l'affirmation, mot par mot : pour chaque nom annote, il releve les caracteres
non blancs restes en clair (non couverts par un span predit, quel que soit son
type, comme `score_flou.py`) et les attribue a une civilite ou a autre chose
(prenom, patronyme, titre professionnel...).

Les comptes excluent les espaces : leurs pourcentages ne sont pas comparables
a ceux de `score_flou.py`, seule la PART hors civilite l'est.

Usage :
    python leak_hors_civilite.py --corpus corpus_flou_adversarial.jsonl \\
        --pred pred_redact_adversarial.jsonl
"""

import argparse
import json
import re
from collections import Counter

CIVILITES = {"m.", "monsieur", "mme", "madame", "mademoiselle", "mlle"}


def charge(path):
    docs = {}
    for ligne in open(path, encoding="utf-8"):
        if ligne.strip():
            d = json.loads(ligne)
            docs[d["id"]] = d
    return docs


def couverts(spans):
    s = set()
    for e in spans:
        s.update(range(e["start"], e["end"]))
    return s


def mesure(corpus, preds):
    """(fuite totale, dont civilite, dont hors civilite, mots hors civilite
    restes en clair) en caracteres non blancs, pour les entites de type nom."""
    total = civ = autre = 0
    mots = Counter()
    for doc_id, doc in corpus.items():
        protege = couverts(preds.get(doc_id, {}).get("entities", []))
        for g in doc["entities"]:
            if g["type"] != "nom":
                continue
            for m in re.finditer(r"\S+", doc["text"][g["start"]:g["end"]]):
                debut = g["start"] + m.start()
                clair = sum(1 for i in range(debut, g["start"] + m.end())
                            if i not in protege)
                if not clair:
                    continue
                total += clair
                if m.group().lower() in CIVILITES:
                    civ += clair
                else:
                    autre += clair
                    mots[m.group()] += clair
    return total, civ, autre, mots


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    ap.add_argument("--top", type=int, default=8)
    args = ap.parse_args()
    total, civ, autre, mots = mesure(charge(args.corpus), charge(args.pred))
    part = "n/a" if total == 0 else f"{100 * autre / total:.1f} %"
    print(f"Fuite des noms (caracteres non blancs) : {total}")
    print(f"  civilite          : {civ}")
    print(f"  hors civilite     : {autre} / {total}  ({part})")
    for mot, n in mots.most_common(args.top):
        print(f"    {mot:16s} {n}")


if __name__ == "__main__":
    main()
