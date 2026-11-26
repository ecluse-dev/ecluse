#!/usr/bin/env python3
"""Sonde de P2-296 (mesure) : vrais tableaux de noms, pour chiffrer ce
qu'une règle plus stricte sur les en-têtes ferait perdre.

Pourquoi : le détecteur de tableaux (`tableau_csv.dart`) refuse en entier un
document dont une « ligne d'en-tête » est suivie de lignes de largeur
différente. Une règle qui refuserait moins de faux tableaux (de la prose
recoupée à 60 colonnes) pourrait aussi ne plus reconnaître de vrais tableaux de
noms, dont les cellules partiraient alors en clair. Aucun corpus du dépôt ne
contient de tableau de noms : cette sonde les fournit, avec les cellules
annotées (nom, date de naissance), pour que `Ecluse.redact` soit mesuré sur le
chemin qui compte (ce que reçoit le LLM).

Deux jeux, synthétiques (noms et dates tirés au hasard, graine 42), un fichier
JSONL chacun, au format des corpus flous (`id`, `text`, `entities`) :

- `vrais` : tableaux conformes, une variante d'en-tête par groupe de 40
  documents (séparateurs `;` tabulation `|` `,`, libellés avec deux-points ou
  parenthèses, en-tête anglais, colonne de naissance seule, HTML, cellule
  d'en-tête de plus de quatre mots) ;
- `irreguliers` : les mêmes tableaux avec une ligne de données de largeur
  différente. Le refus (`TableauAmbiguException`) est le comportement voulu :
  une règle qui cesse de refuser envoie ces cellules.

Usage : python3 generate_sonde_tableaux.py --out-dir DOSSIER [--seed 42]
"""
import argparse
import json
import os
import random

PRENOMS = """Alix Basile Clarisse Dorian Elsa Fabien Gaëlle Hugo Inès Jonas Karine
Lucien Maëlle Noé Océane Paulin Quitterie Rémy Salomé Tristan Ulysse Valentine
Wilfried Yanis Zoé Armand Blandine Cyprien Delphine Eliott""".split()
NOMS = """Aubertin Bocquet Cadiou Delorme Esnault Fougerat Gaillot Hamelin Jouanne
Kerbrat Lemaire Mazoyer Nadaud Oberlé Pasquier Quéré Rosset Sabatier Tellier
Uguen Vaucher Weiss Yvon Zeller Armand Brisset Chauvin Dufrène Escoffier""".split()
MOIS = ("janvier février mars avril mai juin juillet août septembre octobre "
        "novembre décembre").split()
SERVICES = ["Cardiologie", "Gériatrie", "Pédiatrie", "Psychiatrie", "Accueil"]

# (nom_variante, séparateur, en-tête, index des colonnes annotées, colonnes
#  supplémentaires). Le type annoté est « nom » ou « date_naissance ».
VARIANTES = [
    ("pv_nom_prenom", ";", ["Nom", "Prénom"], {0: "nom", 1: "nom"}),
    ("tab_service", "\t", ["Nom", "Prénom", "Service"], {0: "nom", 1: "nom"}),
    ("pipe_naissance", " | ", ["Nom", "Prénom", "Date de naissance"],
     {0: "nom", 1: "nom", 2: "date_naissance"}),
    ("virgule_naissance", ",", ["Nom", "Prénom", "Date de naissance"],
     {0: "nom", 1: "nom", 2: "date_naissance"}),
    ("libelle_deux_points", ";", ["Nom :", "Prénom :"], {0: "nom", 1: "nom"}),
    ("libelle_parentheses", ";", ["Nom (usage)", "Prénom(s)", "Service"],
     {0: "nom", 1: "nom"}),
    ("nom_de_naissance", ";", ["Nom de naissance", "Prénom", "Date de naissance"],
     {0: "nom", 1: "nom", 2: "date_naissance"}),
    ("naissance_seule", ";", ["Service", "Date de naissance"],
     {1: "date_naissance"}),
    ("anglais", ",", ["LastName", "FirstName", "DOB"],
     {0: "nom", 1: "nom", 2: "date_naissance"}),
    ("cellule_longue", ";", ["Nom", "Prénom", "Établissement d'accueil et de soins"],
     {0: "nom", 1: "nom"}),
    ("phrase_autour", ";", ["Nom", "Prénom"], {0: "nom", 1: "nom"}),
    ("libelle_numerote", ";", ["Nom 1", "Prénom 1", "Nom 2", "Prénom 2"],
     {0: "nom", 1: "nom", 2: "nom", 3: "nom"}),
]
NB_PAR_VARIANTE = 40
LIGNES = 6


def cellule(rng, type_annote, colonne):
    if type_annote == "nom" and colonne % 2 == 0:
        return rng.choice(NOMS)
    if type_annote == "nom":
        return rng.choice(PRENOMS)
    if type_annote == "date_naissance":
        return "%02d/%02d/%d" % (rng.randint(1, 28), rng.randint(1, 12),
                                 rng.randint(1925, 2015))
    return rng.choice(SERVICES)


def tableau_texte(rng, nom, sep, entete, types, irregulier):
    """Renvoie (texte, entités). Un tableau HTML est produit à part."""
    texte = ""
    entites = []
    if nom == "phrase_autour":
        texte += "Voici la liste transmise ce matin, à vérifier avant l'envoi.\n\n"
    texte += sep.join(entete) + "\n"
    ragged = 2 if irregulier else -1
    for r in range(LIGNES):
        cells = []
        for k in range(len(entete)):
            cells.append(cellule(rng, types.get(k), k))
        ligne = ""
        for k, c in enumerate(cells):
            if k:
                ligne += sep
            if k in types:
                d = len(texte) + len(ligne)
                entites.append({"type": types[k], "start": d, "end": d + len(c)})
            ligne += c
        if r == ragged:
            ligne += sep + "à revoir"
        texte += ligne + "\n"
    if nom == "phrase_autour":
        texte += "\nMerci de confirmer la réception de ce tableau."
    return texte, entites


def tableau_html(rng, irregulier):
    entete = ["Nom", "Prénom", "Date de naissance"]
    types = {0: "nom", 1: "nom", 2: "date_naissance"}
    texte = "<table>\n<tr>" + "".join("<th>%s</th>" % h for h in entete) + "</tr>\n"
    entites = []
    for r in range(LIGNES):
        texte += "<tr>"
        n = len(entete) - (1 if irregulier and r == 2 else 0)
        for k in range(n):
            c = cellule(rng, types.get(k), k)
            texte += "<td>"
            d = len(texte)
            entites.append({"type": types[k], "start": d, "end": d + len(c)})
            texte += c + "</td>"
        texte += "</tr>\n"
    texte += "</table>"
    return texte, entites


def jeu(rng, irregulier):
    docs = []
    for nom, sep, entete, types in VARIANTES:
        if irregulier and nom in ("naissance_seule", "phrase_autour"):
            continue
        for _ in range(NB_PAR_VARIANTE):
            t, e = tableau_texte(rng, nom, sep, entete, types, irregulier)
            docs.append({"id": len(docs), "variante": nom, "text": t,
                         "entities": e})
    for _ in range(NB_PAR_VARIANTE):
        t, e = tableau_html(rng, irregulier)
        docs.append({"id": len(docs), "variante": "html", "text": t,
                     "entities": e})
    return docs


def ecrit(chemin, docs):
    with open(chemin, "w", encoding="utf-8") as f:
        for d in docs:
            for e in d["entities"]:
                assert 0 <= e["start"] < e["end"] <= len(d["text"])
            f.write(json.dumps(d, ensure_ascii=False) + "\n")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out-dir", required=True)
    p.add_argument("--seed", type=int, default=42)
    a = p.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    rng = random.Random(a.seed)
    for nom, irr in (("vrais", False), ("irreguliers", True)):
        docs = jeu(rng, irr)
        chemin = os.path.join(a.out_dir, "sonde_tableaux_%s.jsonl" % nom)
        ecrit(chemin, docs)
        print("%s : %d documents, %d cellules annotées" % (
            chemin, len(docs), sum(len(d["entities"]) for d in docs)))


if __name__ == "__main__":
    main()
