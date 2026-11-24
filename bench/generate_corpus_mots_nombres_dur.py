#!/usr/bin/env python3
"""Témoin DURCI « mots-nombres » (P2-270, mesure).

Le témoin d'origine (`generate_corpus_mots_nombres.py`, 300 phrases) donne 0
prédiction après P2-267, mais trois choses n'y sont pas départagées (PR #511) :
les mots-clés de validation faible (« code » est large), le signalement
« nombre dicté non reconnu » sur une phrase ordinaire dense en nombres, et le
seuil K = 6 contre 4 ou 8. Ce corpus les met à l'épreuve : 7 familles x 90 =
630 phrases ordinaires, écrites avec leur orthographe, **sans aucun
identifiant** (`entities` vide : toute prédiction est un masquage en trop).

Familles (champ `famille`) :
  montants     : prix, loyers, devis en lettres (jusqu'à 999 999)
  horaires     : heures, durées, trajets
  dates        : dates complètes avec l'année en lettres
  adresses     : numéro de voie, code postal en lettres (« code postal » porte
                 le mot « code »)
  posologies   : prises, comprimés, durées de traitement, quantités
  codes        : digicodes et codes d'accès dits chiffre par chiffre, précédés
                 du mot « code » ; **4 à 12 chiffres** (les longueurs 9 à 11 sont
                 celles de SIREN, FINESS, RPPS : cas de stress, pas d'usage
                 courant)
  chambres     : numéros de chambre et de poste dits en nombres

Données entièrement synthétiques, graine fixe, aucune valeur réelle.

Usage :
    python3 generate_corpus_mots_nombres_dur.py --n 90 --seed 42 \\
        --out transcrit/corpus_temoin_mots_nombres_dur.jsonl
"""

import argparse
import json
import random

from generate_corpus_mots_nombres import (MOIS, grand_nombre,
                                          plus_longue_suite)
from generate_corpus_transcrit import UNITES, nombre

FAMILLES = ("montants", "horaires", "dates", "adresses", "posologies",
            "codes", "chambres")

VOIES = ["rue des Lilas", "avenue de la Gare", "impasse du Moulin",
         "chemin des Vignes", "place du Marché", "boulevard Pasteur"]
OBJETS = ["comprimés", "gélules", "ampoules", "sachets", "gouttes"]
LIEUX_CODE = ["du portail", "de la grille", "du local technique", "du coffre",
              "de l'alarme", "de la salle des archives", "du digicode",
              "de la commande"]


def chiffres_dits(rng, n):
    """n chiffres dits un par un (« un neuf trois… »)."""
    return " ".join(UNITES[rng.randrange(0, 10)] for _ in range(n))


def montants(rng):
    n = rng.randrange(1_000, 999_999)
    return rng.choice([
        f"Le loyer est de {grand_nombre(n)} euros par an.",
        f"Le devis s'élève à {grand_nombre(n)} euros toutes taxes comprises.",
        f"Le prix du lot est fixé à {grand_nombre(n)} euros, frais en sus.",
        f"La facture de {grand_nombre(n)} euros a été réglée en trois fois.",
    ])


def horaires(rng):
    h, m = rng.randrange(0, 24), rng.randrange(0, 60)
    h2, m2 = rng.randrange(0, 24), rng.randrange(0, 60)
    d = rng.randrange(2, 400)
    return rng.choice([
        f"Le train part à {nombre(h)} heures {nombre(m)} et arrive à "
        f"{nombre(h2)} heures {nombre(m2)}.",
        f"La visite dure {nombre(d)} minutes, soit environ "
        f"{nombre(rng.randrange(2, 9))} heures.",
        f"Le service ouvre à {nombre(h)} heures {nombre(m)} et ferme à "
        f"{nombre(h2)} heures {nombre(m2)}.",
        f"Le trajet de {grand_nombre(rng.randrange(100, 9999))} mètres prend "
        f"{nombre(d)} secondes.",
    ])


def dates(rng):
    j = "premier" if rng.random() < 0.1 else nombre(rng.randrange(2, 29))
    mois = rng.choice(MOIS)
    annee = grand_nombre(rng.randrange(1900, 2099))
    return rng.choice([
        f"La séance a eu lieu le {j} {mois} {annee} à {nombre(rng.randrange(8, 19))} heures.",
        f"Le contrat est daté du {j} {mois} {annee}.",
        f"Né le {j} {mois} {annee}, il a rejoint l'équipe l'an dernier.",
    ])


def adresses(rng):
    num = nombre(rng.randrange(1, 200))
    cp = grand_nombre(rng.randrange(1000, 99000))
    voie = rng.choice(VOIES)
    return rng.choice([
        f"Le rendez-vous est au {num} {voie}, code postal {cp}.",
        f"L'agence du {num} {voie} est enregistrée sous le code postal {cp}.",
        f"Livraison au {num} {voie}, {cp} pour la tournée du matin.",
    ])


def posologies(rng):
    a, b, c = (rng.randrange(2, 9), rng.randrange(2, 5), rng.randrange(3, 30))
    total = a * b * c
    return rng.choice([
        f"Prendre {nombre(a)} {rng.choice(OBJETS)} {nombre(b)} fois par jour "
        f"pendant {nombre(c)} jours.",
        f"Ordonnance : {nombre(a)} {rng.choice(OBJETS)} par prise, "
        f"{nombre(b)} prises, soit {nombre(total)} au total sur {nombre(c)} jours.",
        f"Renouveler le traitement de {nombre(c)} jours, {nombre(a)} "
        f"{rng.choice(OBJETS)} le matin et {nombre(b)} le soir.",
    ])


def codes(rng):
    n = rng.randrange(4, 13)
    suite = chiffres_dits(rng, n)
    lieu = rng.choice(LIEUX_CODE)
    return rng.choice([
        f"Le code {lieu} est {suite}.",
        f"Pour entrer, composez le code {lieu} : {suite}.",
        f"Le code d'accès {lieu} a changé, c'est maintenant {suite}.",
    ])


def chambres(rng):
    c = rng.randrange(100, 700)
    p = rng.randrange(100, 999)
    return rng.choice([
        f"Le patient de la chambre {nombre(c)} a sonné deux fois.",
        f"Appelez le poste {nombre(p)} pour joindre le secrétariat.",
        f"La chambre {nombre(c)} est libre, le poste {nombre(p)} sonne dans le couloir.",
    ])


GENERATEUR = {"montants": montants, "horaires": horaires, "dates": dates,
              "adresses": adresses, "posologies": posologies,
              "codes": codes, "chambres": chambres}


def construit(n, seed):
    rng = random.Random(f"{seed}-mots-nombres-dur")
    docs = []
    for famille in FAMILLES:
        for _ in range(n):
            docs.append({"text": GENERATEUR[famille](rng), "entities": [],
                         "famille": famille})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=90,
                   help="phrases par famille (7 familles)")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_temoin_mots_nombres_dur.jsonl")
    a = p.parse_args()
    docs = construit(a.n, a.seed)
    if len(docs) < 600:
        raise SystemExit("la fiche demande au moins 600 phrases")
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    for k in (4, 6, 8):
        longues = sum(plus_longue_suite(d["text"]) >= k for d in docs)
        print(f"suite de {k} mots-nombres ou plus : {longues} phrases")
    print(f"{a.out} : {len(docs)} phrases, 0 entité annotée")


if __name__ == "__main__":
    main()
