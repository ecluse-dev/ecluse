#!/usr/bin/env python3
"""Sonde de P2-303 (mesure) : vrais identifiants **écartés par une garde** qui ne
figurent pas dans `generate_sonde_gardes.py` (P2-272, P2-276, P2-283). Chaque
document annote un seul identifiant, fabriqué (clés calculées, jamais copié d'une
source réelle) ; `garde` nomme la garde qu'il vise. Synthétique, graine fixe.

Gardes visées :

- `nir_coupures` : NIR à clé fausse écrit en groupes de quatre (les coupures ne
  tombent pas entre les groupes d'un NIR) ;
- `rpps_finess_date` : RPPS dont les neuf premiers chiffres sont de Luhn juste,
  écrit « neuf chiffres, deux chiffres » puis un nom de mois ;
- `siret_sans_mot` : SIRET de clé juste sans le mot « siret » dans la fenêtre ;
- `tva_cle_fausse_sans_libelle` : numéro de TVA à clé fausse sans libellé de TVA ;
- `adeli_sans_libelle` : ADELI de clé juste sans le mot « adeli » ;
- `nir_suitelettre` : NIR à clé fausse en groupes standard suivi d'un groupe court
  à lettre de confusion d'OCR (« … 85 I2 reçu ») ;
- `finess_suitelettre` : FINESS sans contexte suivi d'un tel groupe (« … I1 ») ;
- `rpps_sans_libelle` : RPPS de clé juste précédé d'un mot de lot ou de référence.

Usage : python3 generate_sonde_gardes_silencieuses.py --n 40 --seed 42 --out sonde.jsonl
"""
import argparse
import json
import random

from generate_corpus import (luhn_digit, make_adeli, make_finess, make_nir,
                             make_rpps, make_siren, tva_from_siren)

NEUTRE = ["Valeur reportée sur la fiche : {v} à vérifier.",
          "Merci de recopier {v} dans la case prévue.",
          "Pièce jointe 3 : {v} puis signature."]


def fausse_cle_nir(nir, rng):
    cle = int(nir[13:])
    return nir[:13] + f"{(cle + rng.randrange(1, 90)) % 97 or 5:02d}"


def luhn_ok(s):
    total, dbl = 0, False
    for ch in reversed(s):
        v = int(ch)
        if dbl:
            v = v * 2 - 9 if v * 2 > 9 else v * 2
        total += v
        dbl = not dbl
    return total % 10 == 0


def rpps_neuf_luhn(rng):
    """RPPS (11 chiffres, clé de Luhn juste) dont les 9 premiers chiffres sont
    aussi de Luhn juste : celui qu'un FINESS suivi de deux chiffres imite."""
    while True:
        r = make_rpps(rng)
        if luhn_ok(r[:9]):
            return r


def siret_juste(rng):
    siren = make_siren(rng)
    while True:
        nic = "".join(rng.choice("0123456789") for _ in range(5))
        if luhn_ok(siren + nic):
            return siren, nic


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=40)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    docs = []

    def ajoute(modele, v, typ, garde, variante):
        texte = modele.format(v=v)
        d = texte.index(v)
        docs.append({"id": len(docs), "text": texte,
                     "entities": [{"type": typ, "start": d, "end": d + len(v)}],
                     "garde": garde, "variante": variante,
                     "famille": garde, "ecriture": variante, "presentation": "sonde"})

    for _ in range(a.n):
        nir = fausse_cle_nir(make_nir(rng), rng)
        v = " ".join(nir[i:i + 4] for i in range(0, 15, 4))
        ajoute(rng.choice(NEUTRE), v, "nir", "nir_coupures", "quatre")
    for mois in ["mars", "mai", "juin"]:
        for _ in range(a.n // 3 or 1):
            r = rpps_neuf_luhn(rng)
            v = f"{r[:9]} {r[9:]}"
            ajoute("Numéro noté {v} " + mois + " en marge.", v, "rpps",
                   "rpps_finess_date", "neuf_deux_" + mois)
    for _ in range(a.n):
        siren, nic = siret_juste(rng)
        v = f"{siren[:3]} {siren[3:6]} {siren[6:]} {nic}"
        ajoute(rng.choice(NEUTRE), v, "siren", "siret_sans_mot", "groupes")
    for _ in range(a.n):
        siren = make_siren(rng)
        faux = tva_from_siren(siren)
        cle = (int(faux[2:4]) + rng.randrange(1, 90)) % 97
        v = f"FR{cle:02d}{siren}"
        if v == faux:
            continue
        ajoute(rng.choice(NEUTRE), v, "siren", "tva_cle_fausse_sans_libelle", "compact")
    for _ in range(a.n):
        ajoute(rng.choice(NEUTRE), make_adeli(rng), "adeli", "adeli_sans_libelle", "compact")
    for suite in ["I2", "o1", "l9"]:
        for _ in range(a.n // 3 or 1):
            nir = fausse_cle_nir(make_nir(rng), rng)
            p = [nir[0], nir[1:3], nir[3:5], nir[5:7], nir[7:10], nir[10:13], nir[13:15]]
            v = " ".join(p)
            ajoute("Dossier {v} " + suite + " reçu.", v, "nir", "nir_suitelettre", suite)
    for suite in ["I1", "o2", "l7"]:
        for _ in range(a.n // 3 or 1):
            f = make_finess(rng)
            ajoute("Rattaché au {v} " + suite + " depuis janvier.", f, "finess",
                   "finess_suitelettre", suite)
    for _ in range(a.n):
        ajoute("Référence du lot : {v} reçue.", make_rpps(rng), "rpps",
               "rpps_sans_libelle", "apres_lot")
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out}")


if __name__ == "__main__":
    main()
