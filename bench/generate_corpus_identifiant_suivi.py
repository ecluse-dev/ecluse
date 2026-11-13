#!/usr/bin/env python3
"""Corpus « identifiant suivi d'une date, d'un age ou d'un nombre » (P2-174).

Un identifiant a chiffres (NIR, RPPS, IBAN, FINESS) est souvent suivi, sur la
meme ligne ou la suivante, d'un nombre qui n'en fait pas partie : la date d'un
controle, un age, une quantite. Deux defauts possibles :

- l'identifiant n'est plus detecte (ses garde-fous de bord voient un nombre
  trop long) : une fuite, traitee par P1-19 ;
- l'identifiant est detecte **sous un autre type** en avalant le debut du
  nombre voisin : un FINESS (9 chiffres) et le jour d'une date (2 chiffres)
  font 11 chiffres, la longueur d'un RPPS ; une fois sur dix la cle de Luhn
  passe. Rien ne part en clair, mais le type est faux et la date abimee.

Chaque document porte un identifiant **valide** (cle calculee, jamais copie
d'une source reelle) annote dans `entities`, et la suite dans `suite` (jamais
annotee comme entite : elle doit rester lisible). Les axes (`type_id`,
`famille`, `separateur`, `contexte`) permettent au scoreur de dire ou se
trouve le defaut :

- famille : `date_chiffres` (« 12/03/2024 »), `date_lettres` (« 12 mars
  2024 »), `age` (« 72 ans »), `nombre` (« 3 comprimes », « 12 seances ») ;
- separateur : `espace`, `virgule` (« , »), `ligne` (retour a la ligne) ;
- contexte : `mot_cle` (« FINESS 123… ») ou `nu` (« etablissement 123… »).

Donnees entierement synthetiques, graine fixe.

Usage :
    python3 generate_corpus_identifiant_suivi.py --n 100 --seed 42 \\
        --out flou/corpus_identifiant_suivi.jsonl
"""

import argparse
import json
import random

from generate_corpus import (fmt_finess, fmt_iban, fmt_nir, fmt_rpps,
                             make_finess, make_iban, make_nir, make_rpps)

TYPES = {
    "nir": (make_nir, fmt_nir),
    "rpps": (make_rpps, fmt_rpps),
    "iban": (make_iban, fmt_iban),
    "finess": (make_finess, fmt_finess),
}

# (contexte, gabarit). `{id}` est suivi du separateur puis de la suite.
INTRODUCTIONS = {
    "nir": [("mot_cle", "NIR {id}"), ("mot_cle", "N° de sécurité sociale : {id}"),
            ("nu", "Assuré {id}")],
    "rpps": [("mot_cle", "RPPS {id}"), ("mot_cle", "N° RPPS : {id}"),
             ("nu", "Prescripteur {id}")],
    "iban": [("mot_cle", "IBAN {id}"), ("mot_cle", "IBAN : {id}"),
             ("nu", "Compte {id}")],
    "finess": [("mot_cle", "FINESS {id}"), ("mot_cle", "N° FINESS : {id}"),
               ("nu", "Établissement {id}")],
}

SEPARATEURS = {"espace": " ", "virgule": ", ", "ligne": "\n"}

MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "août", "septembre", "octobre", "novembre", "décembre"]
NOMS = ["comprimés", "séances", "jours", "fois par jour", "boîtes",
        "unités", "lits", "places", "euros", "pages"]
FAMILLES = ("date_chiffres", "date_lettres", "age", "nombre")


def suite(famille, rng):
    """Rend le texte qui suit l'identifiant. Commence toujours par un chiffre :
    c'est le voisinage qui met les garde-fous de bord a l'epreuve."""
    j, m, a = rng.randrange(1, 29), rng.randrange(1, 13), rng.randrange(2019, 2027)
    if famille == "date_chiffres":
        sep = rng.choice(["/", "/", ".", "-"])
        return f"{j:02d}{sep}{m:02d}{sep}{a}"
    if famille == "date_lettres":
        return f"{j} {MOIS[m - 1]} {a}"
    if famille == "age":
        return f"{rng.randrange(18, 100)} ans"
    return f"{rng.choice([1, 2, 3, 5, 10, 12, 20, 30, 150, 1250])} {rng.choice(NOMS)}"


def construit(n, seed):
    """`n` documents par (type, famille, separateur), dans un ordre stable."""
    rng = random.Random(seed)
    docs = []
    for type_id, (fabrique, formate) in TYPES.items():
        for famille in FAMILLES:
            for nom_sep, sep in SEPARATEURS.items():
                for _ in range(n):
                    contexte, gabarit = rng.choice(INTRODUCTIONS[type_id])
                    valeur = formate(fabrique(rng), rng)
                    debut_phrase = gabarit.split("{id}")[0]
                    s = suite(famille, rng)
                    texte = f"{debut_phrase}{valeur}{sep}{s} noté au dossier."
                    start = len(debut_phrase)
                    end = start + len(valeur)
                    s_start = end + len(sep)
                    docs.append({
                        "id": len(docs),
                        "text": texte,
                        "entities": [{"type": type_id, "start": start, "end": end}],
                        "suite": {"start": s_start, "end": s_start + len(s)},
                        "type_id": type_id,
                        "famille": famille,
                        "separateur": nom_sep,
                        "contexte": contexte,
                    })
    return docs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=100,
                    help="documents par (type, famille, separateur)")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    docs = construit(args.n, args.seed)
    with open(args.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {args.out}")


if __name__ == "__main__":
    main()
