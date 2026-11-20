#!/usr/bin/env python3
"""Témoin élargi des tournures de personne (P2-226).

P2-220 lit un mot à majuscule initiale comme un patronyme seul derrière
« le dossier de », « à la demande de », « l'entretien avec », ou devant
« a confirmé ». Le témoin de P2-218 (`generate_corpus_tournures_sans_nom.py`)
ne remplit ces tournures que de douze noms communs, douze communes et douze
organismes. Ce témoin-ci donne le chiffre de départ sur cinq familles plus
larges, **pour mesurer seulement** : rien n'est corrigé (P2-227 à P2-229).

Mêmes quatre tournures que P2-220, mêmes gabarits que P2-218 (mots autour,
ponctuation, en-tête « Dossier de suivi — pièce N »). Chaque mot de chaque
famille est placé une fois dans chaque tournure : le compte se lit donc par
famille et par tournure, sans tirage. La graine ne sert qu'à mélanger l'ordre
des documents.

Familles (au moins 20 mots chacune, choisis pour ce témoin, aucun des douze
noms communs de P2-218 repris) :

- `roles` : civilités seules, parenté, fonctions soignantes et sociales, écrits
  sans article à la manière d'une note (« entretien avec Mère », « Madame a
  confirmé ») ; **pas une personne nommée** ;
- `organismes` : organismes publics ou associatifs et marques, d'un ou deux
  mots ; pas une personne ;
- `communs` : noms communs à majuscule initiale (intitulés, débuts de
  phrase) ; pas une personne ;
- `patronymes_communes` : patronymes qui sont aussi une commune de 10 000
  habitants et plus (P2-220 écartait toutes ces communes derrière « à la
  demande de » ; depuis P2-239, `communes_grandes.dart` ne retient que celles de
  100 000 habitants et plus, aucun de ces 24 noms n'en est) ;
  **annotés `nom`** : en clair, c'est une fuite ;
- `patronymes_noms_communs` : patronymes qui sont aussi un nom commun
  (« Berger », « Boulanger ») ; **annotés `nom`**.

Valeurs synthétiques : aucune personne réelle, aucun document réel. Les
organismes et les marques sont des noms publics, pas des personnes ni des
établissements clients.

Usage :
    python3 generate_corpus_tournures_personne.py --seed 42 \\
        --out flou/corpus_tournures_personne.jsonl
"""

import argparse
import json
import random

TOURNURES = ["dossier de", "à la demande de", "entretien avec",
             "sujet : a confirmé"]

# Gabarits repris de `generate_corpus_tournures_sans_nom.py` (P2-218) ; {} est
# le mot de la famille.
GABARITS = {
    "dossier de": "Note de service : le dossier de {} est transmis à l'équipe.\n",
    "à la demande de": "Rendez-vous reporté à la demande de {} ; une nouvelle "
                       "date sera proposée.\n",
    "entretien avec": "Suite à l'entretien avec {}, le suivi est maintenu.\n",
    "sujet : a confirmé": "Compte rendu : {} a confirmé la réception des "
                          "pièces demandées.\n",
}

FAMILLES = {
    "roles": [
        # Civilités seules.
        "Madame", "Monsieur", "Mademoiselle", "Maître", "Docteur",
        # Parenté.
        "Mère", "Père", "Frère", "Sœur", "Fils", "Fille", "Tante", "Oncle",
        "Grand-mère",
        # Fonctions soignantes et sociales.
        "Infirmière", "Éducateur", "Éducatrice", "Psychologue", "Tuteur",
        "Curatrice", "Mandataire", "Médecin", "Ergothérapeute",
        "Aide-soignante",
    ],
    "organismes": [
        "France Travail", "Assurance Maladie", "Sécurité sociale",
        "Croix-Rouge", "Emmaüs", "Secours populaire", "Mutualité française",
        "CAF", "CPAM", "MDPH", "URSSAF", "MSA", "Ameli", "Doctolib", "SNCF",
        "EDF", "Engie", "Orange", "Bouygues", "Leboncoin", "Amazon", "Google",
        "Microsoft", "Decathlon",
    ],
    "communs": [
        "Rapport", "Formation", "Réunion", "Projet", "Accompagnement",
        "Hébergement", "Transport", "Logement", "Insertion", "Orientation",
        "Prévention", "Admission", "Sortie", "Consultation", "Évaluation",
        "Signalement", "Recrutement", "Partenariat", "Renouvellement",
        "Audit", "Médiation", "Protection", "Scolarité", "Tutelle",
    ],
    "patronymes_communes": [
        "Gaillard", "Laval", "Thiers", "Fontaine", "Vernon", "Rochefort",
        "Lunel", "Vienne", "Dreux", "Granville", "Moulins", "Valence",
        "Massy", "Bron", "Riom", "Sens", "Arras", "Calais", "Menton",
        "Castres", "Beaune", "Belfort", "Cholet", "Nevers",
    ],
    "patronymes_noms_communs": [
        "Berger", "Boulanger", "Marchand", "Boucher", "Charpentier",
        "Meunier", "Mercier", "Pasteur", "Chevalier", "Barbier", "Tailleur",
        "Cordier", "Tonnelier", "Vacher", "Bouvier", "Couturier",
        "Jardinier", "Renard", "Mouton", "Rossignol", "Pinson", "Poirier",
        "Rocher", "Moulin",
    ],
}

# Familles dont le mot est un nom de personne (annoté, fuite s'il reste en
# clair) ; les autres n'en contiennent aucun (masquage en trop).
PERSONNES = {"patronymes_communes", "patronymes_noms_communs"}


def construit(seed):
    docs = []
    for famille, mots in FAMILLES.items():
        for tournure in TOURNURES:
            for mot in mots:
                docs.append((famille, tournure, mot))
    random.Random(f"{seed}:tournures_personne").shuffle(docs)
    sortie = []
    for i, (famille, tournure, mot) in enumerate(docs):
        entete = f"Dossier de suivi — pièce {i % 6 + 1}\n\n"
        phrase = GABARITS[tournure].format(mot)
        texte = entete + phrase
        debut = len(entete) + phrase.index(mot)
        mot_pos = {"start": debut, "end": debut + len(mot)}
        entites = ([{"type": "nom", **mot_pos}] if famille in PERSONNES else [])
        sortie.append({"id": i, "text": texte, "entities": entites,
                       "famille": famille, "tournure": tournure,
                       "mot": mot_pos})
    return sortie


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    docs = construit(a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    n_ent = sum(len(d["entities"]) for d in docs)
    print(f"{len(docs)} documents écrits dans {a.out} ({n_ent} noms annotés)")


if __name__ == "__main__":
    main()
