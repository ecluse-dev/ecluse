#!/usr/bin/env python3
"""Scoreur du temoin « commune suivie de mots ordinaires » (P2-181).

D'apres des predictions au format de `run_redact_bench.dart` (donc
**`Ecluse.redact`**, ce que recoit le LLM). Les blancs ne comptent pas.

- **suite masquee** (sur-masquage) : caracteres de la suite sous une
  detection, quel qu'en soit le type ; un document compte des qu'un caractere
  de sa suite est masque. Ce n'est pas une fuite : c'est du texte ordinaire
  que le LLM ne recoit plus.
- **adresse en clair** (fuite) : au moins un caractere de l'adresse annotee
  sous aucune detection.

N'imprime que des comptes, jamais un texte.

Usage :
    python3 score_commune_suivie.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json

AXES = ("famille", "ecriture", "fin", "mots")


def utiles(texte, debut, fin):
    return [i for i in range(debut, fin) if not texte[i].isspace()]


def juge(doc, pred):
    """Rend (caracteres de suite, dont masques, adresse en clair ?)."""
    texte = doc["text"]
    couverts = set()
    for p in pred.get("entities", []):
        couverts.update(range(p["start"], p["end"]))
    suite = utiles(texte, *doc["suite"])
    masques = sum(1 for i in suite if i in couverts)
    e = doc["entities"][0]
    clair = any(i not in couverts for i in utiles(texte, e["start"], e["end"]))
    return len(suite), masques, clair


def compte(corpus, preds):
    stats = collections.defaultdict(lambda: collections.Counter())
    refus = 0
    for doc in corpus:
        pred = preds.get(doc["id"], {"entities": []})
        if pred.get("refuse"):
            refus += 1
            continue
        total, masques, clair = juge(doc, pred)
        for axe in ("tout",) + AXES:
            c = stats[(axe, doc[axe] if axe != "tout" else "")]
            c["documents"] += 1
            c["suite"] += total
            c["masques"] += masques
            c["sur_masques"] += masques > 0
            c["en_clair"] += clair
    return stats, refus


def lit(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(ligne) for ligne in f if ligne.strip()]


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--corpus", required=True)
    p.add_argument("--pred", required=True)
    a = p.parse_args()
    stats, refus = compte(lit(a.corpus), {d["id"]: d for d in lit(a.pred)})
    t = stats[("tout", "")]
    part = 100 * t["masques"] / t["suite"] if t["suite"] else 0
    print(f"commune suivie : {t['documents']} documents, {t['sur_masques']} "
          f"à la suite masquée en partie, {t['masques']} / {t['suite']} "
          f"caractères de suite masqués ({part:.1f} %), {t['en_clair']} "
          f"adresse(s) en partie en clair, {refus} refus (Ecluse.redact)")
    for axe in AXES:
        for (_, valeur), c in sorted(
                ((k, v) for k, v in stats.items() if k[0] == axe),
                key=lambda kv: str(kv[0][1])):
            print(f"  {axe}={valeur} : {c['sur_masques']} / {c['documents']} "
                  f"documents à la suite masquée, {c['masques']} / "
                  f"{c['suite']} caractères ; {c['en_clair']} adresse(s) en "
                  "clair")


if __name__ == "__main__":
    main()
