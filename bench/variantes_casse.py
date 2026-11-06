#!/usr/bin/env python3
"""Variantes de casse d'un corpus JSONL (P2-117, P2-121).

Ecrit, a cote du corpus, `<nom>_minuscules.jsonl` et `<nom>_majuscules.jsonl` :
meme texte en minuscules ou en capitales, annotations inchangees. Refuse un
document dont la longueur changerait (les offsets ne vaudraient plus).

Usage :
    python3 variantes_casse.py flou/corpus_flou_realiste.jsonl [...]
"""

import json
import sys


def variantes(chemin):
    docs = [json.loads(l) for l in open(chemin, encoding="utf-8") if l.strip()]
    base = chemin[:-len(".jsonl")] if chemin.endswith(".jsonl") else chemin
    for nom, f in (("minuscules", str.lower), ("majuscules", str.upper)):
        sortie = f"{base}_{nom}.jsonl"
        with open(sortie, "w", encoding="utf-8") as out:
            for d in docs:
                t = f(d["text"])
                if len(t) != len(d["text"]):
                    raise SystemExit(f"refus : document {d['id']} change de "
                                     f"longueur en {nom}")
                out.write(json.dumps({**d, "text": t}, ensure_ascii=False)
                          + "\n")
        print(f"{sortie} : {len(docs)} documents")


if __name__ == "__main__":
    for c in sys.argv[1:]:
        variantes(c)
