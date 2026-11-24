#!/usr/bin/env python3
"""Corpus « OCR, derrière un libellé, clé fausse, séparateurs multiples » (P2-275).

Un NIR, un RPPS ou un IBAN FR **à clé volontairement fausse**, lu avec des lettres
d'OCR (« O »/« o » pour 0, « l »/« I » pour 1), annoncé par son libellé (« NIR : »,
« RPPS : », « IBAN : ») et écrit avec des séparateurs **multiples** (deux espaces,
deux espaces insécables, tabulation) : le cas que ni `IdentifiantCleInvalideDetector`
(séparateur simple) ni `IdentifiantOcrDetector` (clé juste seulement) ne couvraient
avant P2-275. Synthétique, graine fixe. Mêmes champs que `generate_corpus_ocr.py`
(`type_id`, `confusion`, `presentation` = « libelle_cle_fausse »), donc lu par
`score_ocr.py`.

Usage :
    python3 generate_corpus_ocr_cle_fausse.py --n 40 --seed 42 --out flou/corpus_ocr_cle_fausse.jsonl
"""
import argparse
import json
import random

from generate_corpus import make_iban, make_nir, make_rpps
from generate_corpus_ocr import confond

LIBELLES = {"nir": "NIR", "rpps": "RPPS", "iban": "IBAN"}
SEPARATEURS = ("  ", "  ", "\t", "  ")


def cle_fausse(type_id, v, rng):
    if type_id == "nir":
        cle = int(v[13:])
        return v[:13] + f"{(cle + rng.randrange(1, 90)) % 97 or 5:02d}"
    if type_id == "rpps":
        d = int(v[-1])
        return v[:-1] + str((d + rng.randrange(1, 10)) % 10)
    cle = int(v[2:4])
    return f"FR{(cle + rng.randrange(1, 90)) % 97 or 5:02d}" + v[4:]


def groupes(type_id, v):
    if type_id == "nir":
        return [v[0], v[1:3], v[3:5], v[5:7], v[7:10], v[10:13], v[13:]]
    if type_id == "rpps":
        return [v[:3], v[3:6], v[6:9], v[9:]]
    return [v[i:i + 4] for i in range(0, len(v), 4)]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--n", type=int, default=40)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", required=True)
    a = p.parse_args()
    rng = random.Random(a.seed)
    fab = {"nir": make_nir, "rpps": make_rpps, "iban": make_iban}
    docs = []
    for type_id in ("nir", "rpps", "iban"):
        for confusion in ("zero", "un", "les_deux"):
            for _ in range(a.n):
                for _essai in range(1000):
                    v = cle_fausse(type_id, fab[type_id](rng), rng)
                    # Les groupes sont écrits avant la confusion : les lettres
                    # remplacent des chiffres à la même position.
                    brut = "".join(groupes(type_id, v))
                    lettre = confond(brut, type_id, confusion, rng)
                    if lettre is None:
                        continue
                    morceaux, k = [], 0
                    for g in groupes(type_id, v):
                        morceaux.append(lettre[k:k + len(g)])
                        k += len(g)
                    valeur = rng.choice(SEPARATEURS).join(morceaux)
                    debut = f"{LIBELLES[type_id]} : "
                    docs.append({
                        "id": len(docs),
                        "text": f"{debut}{valeur} noté au dossier.",
                        "entities": [{"type": type_id, "start": len(debut),
                                      "end": len(debut) + len(valeur)}],
                        "type_id": type_id, "confusion": confusion,
                        "presentation": "libelle_cle_fausse"})
                    break
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents -> {a.out}")


main()
