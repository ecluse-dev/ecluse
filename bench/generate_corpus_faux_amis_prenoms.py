#!/usr/bin/env python3
"""Corpus temoin des « faux amis » prenoms en minuscules (P2-124).

Des mots du gazetteer de prenoms qui sont aussi des mots courants
(« claire », « pierre », « rose », « iris », « marine »...), employes comme
mots courants dans des transmissions ecrites tout en minuscules. Aucune
personne n'y figure : toute entite `nom` detectee est un faux positif du
detecteur de noms en minuscules (P2-119).

Format : {"id": int, "text": str, "entities": []}. Graine fixe, aucune
lecture de fichier externe.

Usage :
    python generate_corpus_faux_amis_prenoms.py --n 400 --seed 42 --out f.jsonl
"""

import argparse
import json
import random

GABARITS = [
    "situation {claire} depuis la reprise du traitement, à revoir lundi.",
    "la plaie est {rose} pâle, pansement refait ce matin.",
    "peau {rose} vif au niveau du sacrum, effleurage fait.",
    "pupille droite réactive, {iris} sans particularité.",
    "nuit {blanche} agitée, a déambulé dans le couloir.",
    "porte un pull bleu {marine} et des chaussons neufs.",
    "le mur en {pierre} de la terrasse est glissant par temps de pluie.",
    "a reçu un bouquet de {fleur} séchées pour son anniversaire.",
    "humeur {claire} et stable, participe à l'atelier mémoire.",
    "aime regarder l'{aurore} depuis la fenêtre de sa chambre.",
    "parle de la {victoire} finale de son équipe de foot.",
    "eau de {rose} appliquée sur le visage à sa demande.",
    "infusion de {violette} proposée au goûter.",
    "jardinage : plantation de {capucine} et de soucis avec le groupe.",
    "réveil à l'{aurore} comme chaque jour, petit déjeuner pris seul.",
    "vision {claire} à l'œil gauche selon l'orthoptiste.",
    "sa {constance} dans les exercices de marche est remarquable.",
    "chambre {blanche} repeinte, retour prévu jeudi.",
    "goût de {pierre} à fusil dans le vin servi au repas des familles.",
    "veut décorer le sapin de {noel} avec les autres résidents.",
]

MOTS = {"claire": "claire", "rose": "rose", "iris": "iris",
        "blanche": "blanche", "marine": "marine", "pierre": "pierre",
        "fleur": "fleurs", "aurore": "aurore", "victoire": "victoire",
        "violette": "violette", "capucine": "capucines",
        "constance": "constance", "noel": "noël"}


def doc(i, rng):
    phrases = rng.sample(GABARITS, rng.randint(1, 3))
    texte = " ".join(p.format(**MOTS) for p in phrases)
    return {"id": i, "text": "transmission : " + texte, "entities": []}


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=400)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_faux_amis_prenoms.jsonl")
    a = p.parse_args()
    rng = random.Random(f"{a.seed}-faux-amis")
    with open(a.out, "w", encoding="utf-8") as f:
        for i in range(a.n):
            f.write(json.dumps(doc(i, rng), ensure_ascii=False) + "\n")
    print(f"{a.out} : {a.n} documents")


if __name__ == "__main__":
    main()
