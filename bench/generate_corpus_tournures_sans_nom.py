#!/usr/bin/env python3
"""Témoin « tournures de nom de personne, sans personne » (P2-218).

Les corpus de dossiers (`generate_corpus_dossiers.py`) placent un patronyme
seul dans cinq tournures (« le dossier de X », « à la demande de X »,
« l'entretien avec X », « X a confirmé », « courrier adressé à X »). Un
rattrapage du patronyme seul qui s'appuierait sur ces tournures masquerait à
tort tout ce qui les remplit sans être une personne. Ce témoin donne le
chiffre de départ : **aucune personne n'y figure**, aucune entité annotée,
chaque prédiction est un masquage en trop (de la lisibilité perdue, pas une
fuite).

Chaque document reprend l'en-tête des corpus de dossiers (« Dossier de suivi —
pièce N ») et une phrase : une tournure × un genre de remplissage, à parts
égales (n / 20 par case) :

- `commun_minuscule` : nom commun en minuscules (« le dossier de presse »,
  « l'entretien avec succès ») ;
- `commun_majuscule` : mot commun à majuscule initiale (début de phrase ou
  titre : « Succès a confirmé… ») ;
- `lieu` : nom de commune (« à la demande de Paris ») ;
- `organisme` : service, collectivité ou institution (« la Mairie »).

Valeurs synthétiques : aucun nom de personne, aucune donnée réelle, aucune
lecture externe. Seule la tournure change entre les cases.

Usage :
    python3 generate_corpus_tournures_sans_nom.py --n 400 --seed 42 \\
        --out flou/corpus_tournures_sans_nom.jsonl
"""

import argparse
import json
import random

TOURNURES = ["dossier de", "à la demande de", "entretien avec", "sujet : a confirmé",
             "adressé à"]
GENRES = ["commun_minuscule", "commun_majuscule", "lieu", "organisme"]

# Remplissages. Aucun n'est un prénom ni un patronyme de personne employé ici.
COMMUN_MIN = ["presse", "financement", "candidature", "succès", "synthèse",
              "retard", "travaux", "urgence", "rentrée", "bilan", "suivi",
              "contrôle"]
COMMUN_MAJ = ["Presse", "Financement", "Candidature", "Succès", "Synthèse",
              "Retard", "Travaux", "Urgence", "Rentrée", "Bilan", "Suivi",
              "Contrôle"]
LIEUX = ["Paris", "Lyon", "Dijon", "Besançon", "Nancy", "Lille", "Rennes",
         "Nantes", "Toulouse", "Grenoble", "Metz", "Poitiers"]
ORGANISMES = ["la Mairie", "le Département", "la Préfecture", "la Région",
              "le Rectorat", "la Direction", "le Service", "la Caisse",
              "l'Agence régionale", "l'Inspection", "la Commission",
              "le Comité"]

# Gabarits : {} est le remplissage. Même ponctuation et mêmes mots autour que
# dans `generate_corpus_dossiers.py`.
GABARITS = {
    "dossier de": "Note de service : le dossier de {} est transmis à l'équipe.\n",
    "à la demande de": "Rendez-vous reporté à la demande de {} ; une nouvelle "
                       "date sera proposée.\n",
    "entretien avec": "Suite à l'entretien avec {}, le suivi est maintenu.\n",
    "sujet : a confirmé": "Compte rendu : {} a confirmé la réception des "
                          "pièces demandées.\n",
    "adressé à": "Courrier adressé à {}.\n",
}


def remplissage(rng, tournure, genre):
    if genre == "commun_minuscule":
        return rng.choice(COMMUN_MIN)
    if genre == "commun_majuscule":
        return rng.choice(COMMUN_MAJ)
    if genre == "lieu":
        return rng.choice(LIEUX)
    mot = rng.choice(ORGANISMES)
    # En tête de phrase (sujet), un article en minuscule prendrait une majuscule.
    return mot[0].upper() + mot[1:] if tournure == "sujet : a confirmé" else mot


def construit(n, seed):
    rng = random.Random(f"{seed}:tournures_sans_nom")
    par_case = max(1, n // (len(TOURNURES) * len(GENRES)))
    docs = []
    for t in TOURNURES:
        for g in GENRES:
            for _ in range(par_case):
                phrase = GABARITS[t].format(remplissage(rng, t, g))
                docs.append({"tournure": t, "genre": g, "phrase": phrase})
    rng.shuffle(docs)
    sortie = []
    for i, d in enumerate(docs):
        texte = f"Dossier de suivi — pièce {i % 6 + 1}\n\n{d['phrase']}"
        sortie.append({"id": i, "text": texte, "entities": [],
                       "tournure": d["tournure"], "genre": d["genre"]})
    return sortie


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--n", type=int, default=400)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out} (aucune entité annotée)")


if __name__ == "__main__":
    main()
