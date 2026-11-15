#!/usr/bin/env python3
"""Corpus TEMOIN « nombre a cinq chiffres + LE/LA/LES/L' + mots ordinaires »
(P2-187).

Des phrases francaises ou un nombre de cinq chiffres (quantite, reference)
est suivi d'un determinant puis de mots ordinaires : « VOIR 12345 LE SERVICE
DES ADMISSIONS. ». Aucune entite n'est annotee (`"entities": []`) : toute
adresse predite est un faux positif, donc un masquage en trop (de la
lisibilite perdue, pas une fuite). Un code postal suivi d'une commune qui
commence par un determinant (« 01097 LA BOISSE ») a la meme forme : c'est le
prix de la correction de P2-187, que ce temoin chiffre.

Deux ecritures de la meme phrase : `capitales` (tout le texte en capitales) et
`ordinaire` (majuscule a chaque mot apres le determinant, comme un nom de
commune, le reste de la phrase en casse ordinaire). Axes : `famille`
(quantite, reference), `suffixe` (le, la, les, l : le determinant),
`position` (le nombre ouvre la phrase ou vient apres des mots) et `casse`.

Les mots sont du vocabulaire courant (services, documents, temps), choisis
sans regarder ce que le detecteur connait. Donnees entierement synthetiques,
graine fixe, aucune valeur reelle.

Usage :
    python3 generate_corpus_determinant.py --n 400 --seed 42 \\
        --out flou/corpus_flou_determinant.jsonl
"""

import argparse
import json
import random

# Suite apres le determinant : (mots, ...). Vocabulaire courant uniquement.
SUITES = [
    "service des admissions", "suite est attendue", "dossier du patient",
    "bureau des entrees", "rapport du mois", "secretariat medical",
    "planning de la semaine", "equipe de nuit", "reunion de service",
    "document joint", "prochain rendez-vous", "total de la commande",
    "livraison de demain", "courrier de la direction", "projet de l'annee",
    "personnel du service", "resultat de l'analyse", "compte rendu",
    "tarif en vigueur", "calendrier des visites", "contrat signe",
    "traitement en cours", "stock de la pharmacie", "bilan de fin d'annee",
]
DETERMINANTS = {"le": "le", "la": "la", "les": "les", "l": "l'"}
FAMILLES = {
    "quantite": ["Commande de", "Stock de", "Un total de", "Environ"],
    "reference": ["Voir", "Reference", "Dossier n°", "Lot"],
}


def nombre5(rng):
    return str(rng.randrange(10_000, 99_999))


def phrase_ordinaire(n, det, suite, intro, position):
    """Casse ordinaire : le determinant et les mots de la suite portent une
    majuscule initiale (forme d'un nom de commune), le reste est en casse
    normale."""
    mots = " ".join(m.capitalize() if m != "de" and m != "des" and m != "du"
                    else m for m in suite.split())
    sep = "" if det.endswith("'") else " "
    corps = f"{det.capitalize()}{sep}{mots}"
    if position == "debut":
        return f"{n} {corps}."
    return f"{intro} {n} {corps}."


def construit_phrase(rng, famille, det_cle, position, casse):
    n = nombre5(rng)
    det = DETERMINANTS[det_cle]
    suite = rng.choice(SUITES)
    intro = rng.choice(FAMILLES[famille])
    texte = phrase_ordinaire(n, det, suite, intro, position)
    if casse == "capitales":
        texte = texte.upper()
    return texte


def construit(n, seed):
    rng = random.Random(f"{seed}-determinant")
    axes = [(f, d, p, c)
            for f in FAMILLES
            for d in DETERMINANTS
            for p in ("debut", "milieu")
            for c in ("capitales", "ordinaire")]
    docs = []
    for i in range(n):
        f, d, p, c = axes[i % len(axes)]
        docs.append({
            "id": i, "text": construit_phrase(rng, f, d, p, c),
            "entities": [], "famille": f, "suffixe": d, "position": p,
            "casse": c})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=400)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_flou_determinant.jsonl")
    a = p.parse_args()
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{a.out} : {len(docs)} phrases, 0 entite annotee")


if __name__ == "__main__":
    main()
