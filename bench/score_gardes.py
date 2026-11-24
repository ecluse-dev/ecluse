#!/usr/bin/env python3
"""Compte pour P2-272 (mesure) : identifiants entièrement couverts, par type et
par validité de clé, et documents sans entité annotée qui reçoivent une
prédiction, par type. Imprime un JSON (aucune valeur du texte, seulement des
nombres). `--corpus` et `--pred` comme les autres scoreurs ; `--sous-ensemble`
limite aux documents dont `presentation` vaut la valeur donnée (témoin durci).
"""
import argparse
import json
import re
from collections import Counter


def _sans_sep(s):
    return re.sub(r"[\s\-./]", "", s).upper()


def iban_juste(s):
    s = _sans_sep(s)
    if len(s) != 27 or not re.match(r"^FR\d{2}", s):
        return None
    n = "".join(str(int(c, 36)) for c in s[4:] + s[:4])
    return int(n) % 97 == 1


def nir_juste(s):
    s = _sans_sep(s)
    if len(s) != 15 or not s[13:].isdigit():
        return None
    b = s[:13].replace("2A", "19").replace("2B", "18")
    if not b.isdigit():
        return None
    return 97 - int(b) % 97 == int(s[13:])


def couvert(debut, fin, intervalles):
    pos = debut
    for a, b in sorted(intervalles):
        if b <= pos:
            continue
        if a > pos:
            break
        pos = b
        if pos >= fin:
            return True
    return pos >= fin


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    ap.add_argument("--sous-ensemble", default=None)
    ap.add_argument("--par", default=None,
                    help="champs du corpus ajoutés à la clé, séparés par des virgules")
    a = ap.parse_args()
    corpus = [json.loads(l) for l in open(a.corpus, encoding="utf-8")]
    pred = {}
    for l in open(a.pred, encoding="utf-8"):
        d = json.loads(l)
        pred[d["id"]] = d["entities"]
    pos, tot, neg_docs, neg_types, n_neg = Counter(), Counter(), 0, Counter(), 0
    for d in corpus:
        if a.sous_ensemble and d.get("presentation") != a.sous_ensemble:
            continue
        ents = pred.get(d["id"], [])
        inter = [(e["start"], e["end"]) for e in ents]
        if not d["entities"]:
            n_neg += 1
            if ents:
                neg_docs += 1
                for t in {e["type"] for e in ents}:
                    neg_types[t] += 1
            continue
        for e in d["entities"]:
            v = d["text"][e["start"]:e["end"]]
            cle = ""
            if e["type"] == "iban":
                j = iban_juste(v)
                cle = "" if j is None else ("juste" if j else "fausse")
            elif e["type"] == "nir":
                j = nir_juste(v)
                cle = "" if j is None else ("juste" if j else "fausse")
            if a.par:
                sep = "/".join(str(d.get(c, "")) for c in a.par.split(","))
            else:
                sep = (d.get("presentation") or "") if a.sous_ensemble is None else ""
            k = f"{e['type']}|{cle}|{sep}"
            tot[k] += 1
            if couvert(e["start"], e["end"], inter):
                pos[k] += 1
    print(json.dumps({"positifs": {k: [pos[k], tot[k]] for k in sorted(tot)},
                      "negatifs": {"documents": n_neg, "avec_prediction": neg_docs,
                                   "types": dict(neg_types)}},
                     ensure_ascii=False))


main()
