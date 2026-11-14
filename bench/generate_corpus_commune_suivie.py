#!/usr/bin/env python3
"""Corpus TEMOIN de sur-masquage « commune suivie de mots ordinaires » (P2-181).

Le balayage de P2-178 n'a que des adresses : il dit ce qu'une commune longue
laisse en clair, pas ce qu'un nom de commune accepte plus long masquerait a
tort. Ce temoin le dit. Chaque document porte une adresse « code postal +
commune » (annotee), suivie sur la meme ligne d'une **suite** qui n'en fait
pas partie (champ `suite`, positions exactes) : des mots ordinaires en
capitales (« 25000 BESANCON ET ENVIRONS »), des mots a majuscule, ou un mot de
liaison (« 70000 Vesoul à 9 h », « 70000 Vesoul et Besançon »).

Deux mesures par document, par `Ecluse.redact` (`score_commune_suivie.py`) :

- la **suite masquee** : caracteres de la suite sous une detection. C'est le
  sur-masquage (lisibilite perdue, pas une fuite) ;
- l'**adresse en clair** : garde-fou, elle doit rester a 0.

Axes : `ecriture` (postale : commune en capitales sans accent ; libelle :
casse de titre), `famille` de la suite (capitales, majuscule, liaison),
`mots` (nombre de mots de la commune, 1 a 4 : au-dela c'est le balayage qui
mesure), `fin` (la suite finit la ligne, ou une phrase en minuscules continue).

Noms de communes : une courte liste de noms de lieux publics (aucune donnee
personnelle) ; codes postaux fabriques ; suites ecrites pour le temoin, sans
regarder ce que le detecteur accepte. Graine fixe.

Usage :
    python3 generate_corpus_commune_suivie.py --n 480 --seed 42 \\
        --out flou/corpus_flou_commune_suivie.jsonl
"""

import argparse
import json
import random

# (forme postale, libelle) ; le nombre de mots se compte sur la forme postale.
COMMUNES = [
    ("VESOUL", "Vesoul"), ("BESANCON", "Besançon"), ("LURE", "Lure"),
    ("DOLE", "Dole"), ("BELFORT", "Belfort"),
    ("GRAND CHARMONT", "Grand-Charmont"), ("PORT LESNEY", "Port-Lesney"),
    ("LONS LE SAUNIER", "Lons-le-Saunier"),
    ("VILLERS LE SEC", "Villers-le-Sec"),
    ("BAUME LES DAMES", "Baume-les-Dames"),
    ("SAINT LOUP SUR SEMOUSE", "Saint-Loup-sur-Semouse"),
    ("PORT SUR SAONE", "Port-sur-Saône"),
    ("SAINT REMY EN COMTE", "Saint-Rémy-en-Comté"),
    ("FONTAINE LES LUXEUIL", "Fontaine-lès-Luxeuil"),
]

# Suites en capitales : mots ordinaires d'une ligne d'en-tete ou d'enveloppe.
SUITES_CAPITALES = [
    "ET ENVIRONS", "SERVICE DES ADMISSIONS", "BATIMENT B", "URGENT",
    "A L ATTENTION DU SERVICE COURRIER", "ET COMMUNES VOISINES",
    "SECTEUR NORD", "ACCUEIL DU PUBLIC", "ANTENNE DE PROXIMITE",
    "PLI CONFIDENTIEL", "DOSSIER EN COURS DE TRAITEMENT",
    "RETOUR A L EXPEDITEUR",
]
# Suites a majuscule initiale (casse de titre d'un service, d'une mention).
SUITES_MAJUSCULE = [
    "Service des Admissions", "Bâtiment B", "Secteur Nord",
    "Accueil du Public", "Antenne de Proximité", "Pli Confidentiel",
    "Retour Expéditeur", "Guichet Unique",
]
# Suites introduites par un mot de liaison absent de la liste du detecteur.
SUITES_LIAISON = [
    "et environs", "à 9 h", "au plus tard lundi", "et Besançon",
    "à Lure le lundi", "près de la Gare", "devant la Mairie", "et le Jura",
    "au Printemps prochain", "à Pâques", "et Dole", "près du Centre",
    "devant le Tribunal", "entre Noël et Pâques",
]
FAMILLES = (("capitales", SUITES_CAPITALES), ("majuscule", SUITES_MAJUSCULE),
            ("liaison", SUITES_LIAISON))
AVANT = ["Courrier à adresser à :\n", "Tournée du jour :\n",
         "Point de dépôt :\n", "Adresse de retour :\n"]
APRES_PHRASE = [" selon le planning.", " pour la semaine.",
                " comme convenu."]


def code_postal(rng):
    return "".join(rng.choice("0123456789") for _ in range(5)).replace(
        "00000", "70000")


def construit(n, seed):
    rng = random.Random(f"{seed}-commune-suivie")
    docs = []
    for i in range(n):
        famille, suites = FAMILLES[i % len(FAMILLES)]
        ecriture = "postale" if (i // len(FAMILLES)) % 2 == 0 else "libelle"
        fin = "ligne" if (i // (2 * len(FAMILLES))) % 2 == 0 else "phrase"
        postale, libelle = rng.choice(COMMUNES)
        commune = postale if ecriture == "postale" else libelle
        suite = rng.choice(suites)
        avant = rng.choice(AVANT)
        debut = len(avant)
        texte = f"{avant}{code_postal(rng)} {commune}"
        fin_adresse = len(texte)
        texte += " "
        debut_suite = len(texte)
        texte += suite
        fin_suite = len(texte)
        texte += (rng.choice(APRES_PHRASE) if fin == "phrase" else "")
        texte += "\nMerci de votre retour."
        docs.append({
            "id": i, "text": texte,
            "entities": [{"type": "adresse", "start": debut,
                          "end": fin_adresse}],
            "suite": [debut_suite, fin_suite], "famille": famille,
            "ecriture": ecriture, "fin": fin,
            "mots": len(postale.split())})
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=480)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_flou_commune_suivie.jsonl")
    a = p.parse_args()
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{a.out} : {len(docs)} documents, {len(docs)} adresses annotees")


if __name__ == "__main__":
    main()
