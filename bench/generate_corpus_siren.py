#!/usr/bin/env python3
"""Témoin « SIREN pris pour un FINESS » et son pendant FINESS (P2-223).

Le FINESS et le SIREN ont la même structure (neuf chiffres, clé de Luhn) : la
validation structurelle ne peut pas les distinguer (`LIMITES.md` § 1,
`FinessDetector`). Sans le mot « FINESS » à proximité, un SIREN est masqué à
confiance 0,5 (sur-masquage d'un identifiant d'organisation, pas une fuite,
sauf entrepreneur individuel : hors périmètre de cette mesure). P1-03 l'avait
analysé sur le corpus v3 ; ce profil donne un témoin plus large et son pendant,
pour chiffrer des options **hors `lib/`** sans perdre de vrais FINESS.

Deux corpus, graine fixe, `--n` documents chacun (400 par défaut), une phrase
par document, valeurs synthétiques (clés calculées) :

- `corpus_siren.jsonl` : un SIREN valide, **aucune entité annotée**, champ
  `siren` = {start, end}. Axes : `libelle` (`siren_immediat` : « SIREN » juste
  avant le nombre ; `siren_phrase` : « SIREN » plus loin dans la phrase ;
  `siren_apres` : le mot après le nombre ; `sans_mot` : RCS, Kbis, aucun mot
  SIREN) et `ecriture` (`compact`, `groupe` 3-3-3).
- `corpus_finess_pendant.jsonl` : un vrai FINESS annoté (`finess`), parfois avec
  un SIREN voisin non annoté (`siren_voisin`). Axes : `contexte`
  (`finess_immediat`, `finess_phrase`, `sans_mot`, `siren_voisin`) et
  `ecriture` (`compact`, `groupe` 2-3-3-1).

Aucune donnée réelle : numéros tirés au hasard, clés de Luhn calculées.

Usage :
    python3 generate_corpus_siren.py --n 400 --seed 42 --out-dir flou
"""

import argparse
import json
import os
import random

from generate_corpus import luhn_digit, make_finess

LIBELLES = ["siren_immediat", "siren_phrase", "siren_apres", "sans_mot"]
CONTEXTES = ["finess_immediat", "finess_phrase", "sans_mot", "siren_voisin"]
ECRITURES = ["compact", "groupe"]

GABARITS_SIREN = {
    "siren_immediat": ["Société inscrite sous le SIREN {}.",
                       "N° SIREN : {}", "Fournisseur, numéro SIREN {}."],
    "siren_phrase": ["Le SIREN de la société est {}.",
                     "Le numéro SIREN de l'entreprise cliente est le {}."],
    "siren_apres": ["{} (numéro SIREN de la société).",
                    "{}, SIREN de l'entreprise gestionnaire."],
    "sans_mot": ["Société immatriculée au RCS de Metz sous le numéro {}.",
                 "Extrait Kbis : immatriculation {}.",
                 "Entreprise enregistrée sous le numéro {}."],
}
GABARITS_FINESS = {
    "finess_immediat": ["Établissement FINESS {}.", "N° FINESS : {}",
                        "Structure, numéro FINESS {}."],
    "finess_phrase": ["Le FINESS de l'établissement est {}.",
                      "Le numéro FINESS de la structure d'accueil est le {}."],
    "sans_mot": ["Structure d'accueil n° {}.", "Établissement n° {}, "
                 "secteur médico-social."],
}
GABARITS_VOISIN = [
    "Rattachement : SIREN {S} ; FINESS {F}.",
    "Établissement FINESS {F}, rattaché à la société SIREN {S}.",
    "La société {S} exploite la structure FINESS {F}.",
    "Structure {F}, gérée par la société SIREN {S}.",
]


def siren_valide(rng):
    return luhn_digit("".join(rng.choice("0123456789") for _ in range(8)))


def ecrit(nombre, ecriture, finess=False):
    if ecriture == "compact":
        return nombre
    if finess:
        return f"{nombre[:2]} {nombre[2:5]} {nombre[5:8]} {nombre[8]}"
    return f"{nombre[:3]} {nombre[3:6]} {nombre[6:]}"


def corpus_siren(n, seed):
    rng = random.Random(f"{seed}:siren")
    par_case = max(1, n // (len(LIBELLES) * len(ECRITURES)))
    docs = []
    for lib in LIBELLES:
        for eci in ECRITURES:
            for i in range(par_case):
                gab = GABARITS_SIREN[lib][i % len(GABARITS_SIREN[lib])]
                v = ecrit(siren_valide(rng), eci)
                a = gab.index("{}")
                docs.append({"text": gab.format(v), "entities": [],
                             "siren": {"start": a, "end": a + len(v)},
                             "libelle": lib, "ecriture": eci})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def corpus_finess(n, seed):
    rng = random.Random(f"{seed}:finess_pendant")
    par_case = max(1, n // (len(CONTEXTES) * len(ECRITURES)))
    docs = []
    for ctx in CONTEXTES:
        for eci in ECRITURES:
            for i in range(par_case):
                f = ecrit(make_finess(rng), eci, finess=True)
                if ctx == "siren_voisin":
                    gab = GABARITS_VOISIN[i % len(GABARITS_VOISIN)]
                    s = ecrit(siren_valide(rng), eci)
                    texte = gab.format(F=f, S=s)
                    af, as_ = texte.index(f), texte.index(s)
                    d = {"text": texte, "entities": [
                        {"type": "finess", "start": af, "end": af + len(f)}],
                         "siren_voisin": {"start": as_, "end": as_ + len(s)}}
                else:
                    gab = GABARITS_FINESS[ctx][i % len(GABARITS_FINESS[ctx])]
                    a = gab.index("{}")
                    d = {"text": gab.format(f), "entities": [
                        {"type": "finess", "start": a, "end": a + len(f)}]}
                d["contexte"] = ctx
                d["ecriture"] = eci
                docs.append(d)
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def ecrit_jsonl(chemin, docs):
    with open(chemin, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--n", type=int, default=400)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    s, f = corpus_siren(a.n, a.seed), corpus_finess(a.n, a.seed)
    ecrit_jsonl(os.path.join(a.out_dir, "corpus_siren.jsonl"), s)
    ecrit_jsonl(os.path.join(a.out_dir, "corpus_finess_pendant.jsonl"), f)
    print(f"{len(s)} documents SIREN et {len(f)} documents FINESS écrits "
          f"dans {a.out_dir}")


if __name__ == "__main__":
    main()
