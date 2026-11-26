#!/usr/bin/env python3
"""Sonde de P2-304 (code) : candidats que les trois gardes de P2-276 écartent, et
qu'`Ecluse.redact` doit désormais **signaler** (« à vérifier ») au lieu de les
laisser partir en silence. Un identifiant par document, fabriqué (clés calculées,
jamais copié d'une source réelle) ; synthétique, graine fixe.

- `nir_suitelettre` : NIR à clé fausse en groupes standard suivi d'un groupe
  court à lettre de confusion d'OCR ;
- `finess_suitelettre` : FINESS sans contexte suivi d'un tel groupe ;
- `adr_confusables` : code postal suivi d'un mot de chiffres et de confusions
  d'OCR qui commence par une majuscule (« 05214 OO1l »).

Usage : python3 generate_sonde_gardes_signalees.py --n 40 --seed 42 --out sonde.jsonl
"""
import argparse
import json
import random

from generate_corpus import make_finess, make_nir


def fausse_cle_nir(nir, rng):
    cle = int(nir[13:])
    return nir[:13] + f"{(cle + rng.randrange(1, 90)) % 97 or 5:02d}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=40)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    docs = []

    def ajoute(modele, v, typ, famille, ecriture):
        texte = modele.format(v=v)
        d = texte.index(v)
        docs.append({"id": len(docs), "text": texte,
                     "entities": [{"type": typ, "start": d, "end": d + len(v)}],
                     "famille": famille, "ecriture": ecriture, "presentation": "sonde"})

    for suite in ["I2", "o1", "l9"]:
        for _ in range(a.n // 3 or 1):
            nir = fausse_cle_nir(make_nir(rng), rng)
            p = [nir[0], nir[1:3], nir[3:5], nir[5:7], nir[7:10], nir[10:13], nir[13:15]]
            v = " ".join(p)
            ajoute("Dossier {v} " + suite + " reçu.", v, "nir", "nir_suitelettre", suite)
    for suite in ["I1", "o2", "l7"]:
        for _ in range(a.n // 3 or 1):
            ajoute("Rattaché au {v} " + suite + " depuis janvier.", make_finess(rng),
                   "finess", "finess_suitelettre", suite)
    for mot in ["OO1l", "O8669", "I1O2", "O1I8"]:
        for _ in range(a.n // 4 or 1):
            cp = f"{rng.randrange(1000, 96000):05d}"
            v = f"{cp} {mot}"
            ajoute("Pièce détachée {v} reçue.", v, "adresse", "adr_confusables", mot)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out}")


if __name__ == "__main__":
    main()
