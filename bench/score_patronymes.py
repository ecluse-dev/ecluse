#!/usr/bin/env python3
"""Scoreur du patronyme seul.  (P2-14)

Pour chaque cas de `generate_corpus_patronymes.py` (a, b, c, selon que le
patronyme seul est debut ou milieu de phrase), part des mentions annotees
couvertes par une detection de type `nom` (chevauchement d'au moins un
caractere : le patronyme est masque, meme si le span est plus large). Les
mentions « ancre » (mention complete qui etablit le patronyme) sont comptees a
part et ne servent pas de mesure.

Sur les documents sans entite annotee (leurres) : nombre de documents ou une
detection `nom` existe, c'est-a-dire un faux positif. Le budget de reference
est celui de `agent/specs/P2-01.md` § 4 : au plus 1 % des documents du
temoin avec une detection.

Format des predictions : celui de `bin/run_dossiers_bench.dart`
(`{"id", "mentions": [{"type", "start", "end", "jeton"}], "restaure"}`).

Usage :
    python score_patronymes.py --corpus corpus_patronymes_c.jsonl \\
        --pred pred_patronymes_c.jsonl
"""

import argparse
import json
import re
from collections import defaultdict


def charge(path):
    docs = {}
    for ligne in open(path, encoding="utf-8"):
        if ligne.strip():
            d = json.loads(ligne)
            docs[d["id"]] = d
    return docs


def _chevauche(a, b):
    return a["start"] < b["end"] and b["start"] < a["end"]


def _spans(pred):
    """Detections d'une prediction, au format de run_dossiers_bench
    (« mentions ») ou de run_redact_bench (« entities »)."""
    return pred.get("mentions", pred.get("entities", []))


# Debut de phrase : le mot capitalise suit un point, deux-points, point
# d'interrogation ou d'exclamation, une puce ou un debut de ligne.
_DEBUT_PHRASE = re.compile(r"(?:^|[.!?:;\n•\-–—]\s*)$")
_MOT_CAPITALISE = re.compile(r"[A-ZÀ-Ý][\wÀ-ÿ'’-]*")


def mots_capitalises_isoles(corpus, preds):
    """Mesure de la regle naive « tout mot capitalise hors debut de phrase est
    un nom » : (documents contenant au moins un mot capitalise non couvert par
    une detection, documents). Sur un corpus sans personne, chaque document
    compte est un faux positif de cette regle."""
    touches = 0
    for doc_id, doc in corpus.items():
        couverts = set()
        for m in _spans(preds.get(doc_id, {})):
            couverts.update(range(m["start"], m["end"]))
        texte = doc["text"]
        for m in _MOT_CAPITALISE.finditer(texte):
            if _DEBUT_PHRASE.search(texte[:m.start()]):
                continue
            if any(i in couverts for i in range(m.start(), m.end())):
                continue
            touches += 1
            break
    return touches, len(corpus)


def detections_hors_annotation(corpus, preds):
    """(detections `nom` ne recouvrant aucune mention annotee, detections
    `nom`) : les faux positifs d'un corpus dont toutes les personnes sont
    annotees (corpus de dossiers de `generate_corpus_dossiers.py`)."""
    faux = total = 0
    for doc_id, doc in corpus.items():
        for m in _spans(preds.get(doc_id, {})):
            if m["type"] != "nom":
                continue
            total += 1
            faux += not any(_chevauche(g, m) for g in doc["entities"]
                            if g["type"] == "nom")
    return faux, total


def mesure(corpus, preds):
    """({cas: (detectees, total)}, (documents leurres avec detection,
    documents leurres))."""
    par_cas = defaultdict(lambda: [0, 0])
    leurres = [0, 0]
    for doc_id, doc in corpus.items():
        noms = [m for m in _spans(preds.get(doc_id, {})) if m["type"] == "nom"]
        if not doc["entities"]:
            leurres[1] += 1
            leurres[0] += bool(noms)
            continue
        for g in doc["entities"]:
            par_cas[g["cas"]][1] += 1
            par_cas[g["cas"]][0] += any(_chevauche(g, m) for m in noms)
    return ({c: tuple(v) for c, v in par_cas.items()}, tuple(leurres))


def _pct(a, b):
    return "n/a" if b == 0 else f"{100 * a / b:5.1f} %"


def affiche(nom, resultat):
    par_cas, leurres = resultat
    print(f"=== {nom}")
    for cas in sorted(par_cas):
        a, b = par_cas[cas]
        note = "  (ancrage, hors mesure)" if cas == "ancre" else ""
        print(f"  {cas:10s} {a:4d} / {b:4d}  {_pct(a, b)}{note}")
    if leurres[1]:
        print(f"  documents sans personne avec une detection : "
              f"{leurres[0]} / {leurres[1]}  {_pct(*leurres)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    ap.add_argument("--nom", default=None)
    ap.add_argument("--faux-positifs", action="store_true",
                    help="detections nom hors mention annotee (corpus dont "
                         "toutes les personnes sont annotees)")
    ap.add_argument("--regle-naive", action="store_true",
                    help="mesure la regle « mot capitalise hors debut de "
                         "phrase » sur un corpus sans personne (temoin)")
    args = ap.parse_args()
    if args.faux_positifs:
        a, b = detections_hors_annotation(charge(args.corpus),
                                          charge(args.pred))
        print(f"{args.nom or args.corpus} : detections nom hors annotation "
              f"{a} / {b}  {_pct(a, b)}")
        return
    if args.regle_naive:
        a, b = mots_capitalises_isoles(charge(args.corpus), charge(args.pred))
        print(f"{args.nom or args.corpus} : documents avec un mot capitalise "
              f"isole non detecte {a} / {b}  {_pct(a, b)}")
        return
    affiche(args.nom or args.corpus,
            mesure(charge(args.corpus), charge(args.pred)))


if __name__ == "__main__":
    main()
