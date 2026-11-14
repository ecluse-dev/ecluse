#!/usr/bin/env python3
"""Corpus « code postal en tete » (P2-177) : le jeu d'adresses a ne pas perdre.

Pendant du temoin « nombres a cinq chiffres » (`generate_corpus_cinq_chiffres.py`,
P2-167). La-bas, aucune adresse : « 58699 Alpha livres. » est masque a tort.
Ici, **que des adresses**, de la meme forme : un code postal qui ouvre le
texte, une ligne ou une phrase, suivi de sa commune. Toute regle qui
ecarterait les nombres du temoin doit laisser ces adresses masquees : une
adresse perdue est une fuite, un nombre masque a tort ne coute que de la
lisibilite.

Chaque document porte une adresse annotee (`type: adresse`, le code postal et
la commune) et ses axes :

- position : le code postal ouvre le texte (`debut_texte`), une ligne apres
  une ligne sans point final (`debut_ligne` : bloc d'adresse, ou prose
  recoupee par une fin de ligne comme dans un PDF) ou une phrase sur la meme
  ligne (`apres_phrase`) ;
- suite : rien apres la commune (`rien`), une fin de ligne puis une autre
  ligne (`ligne`), une ponctuation (`ponctuation`), ou des mots en minuscules
  sur la meme ligne (`minuscule` : « 25000 Besançon depuis 2019 ») ;
- casse : `ordinaire`, ou `minuscules` (texte tape sans aucune majuscule).

Les suites en minuscules sont des tournures courantes apres un lieu (duree,
date, precision), **pas** des mots choisis d'apres ce que le detecteur sait
ecarter. Les communes sont des noms de lieux, pas des donnees personnelles ;
tout le reste est synthetique. Graine fixe.

Usage :
    python3 generate_corpus_cp_tete.py --n 432 --seed 42 \\
        --out flou/corpus_flou_cp_tete.jsonl
"""

import argparse
import json
import random

# Noms de lieux de formes variees : un mot, accent, tirets, article, « sur ».
COMMUNES = [
    ("70000", "Vesoul"), ("25000", "Besançon"), ("39100", "Dole"),
    ("21000", "Dijon"), ("70400", "Héricourt"), ("39300", "Champagnole"),
    ("21200", "Beaune"), ("70190", "Rioz"), ("90000", "Belfort"),
    ("25300", "Pontarlier"), ("70100", "Gray"), ("70200", "Lure"),
    ("70170", "Port-sur-Saône"), ("25250", "L'Isle-sur-le-Doubs"),
    ("70180", "Dampierre-sur-Salon"), ("39000", "Lons-le-Saunier"),
]

# Ligne qui precede, sans point final : bloc d'adresse ou prose recoupee.
LIGNES_AVANT = [
    "Résidence des Tilleuls", "Bâtiment B", "Adresse postale",
    "Domicile :", "Le courrier est à envoyer au",
    "La famille reste domiciliée au",
]
# Phrase qui precede sur la meme ligne.
PHRASES_AVANT = [
    "Courrier à envoyer.", "Adresse inchangée.", "Dossier complet.",
]
# Ligne qui suit l'adresse.
LIGNES_APRES = [
    "France", "À l'attention du service courrier", "Objet : renouvellement",
]
# Ce qui suit la commune apres une ponctuation.
PONCTUATIONS = [
    ", France", ". Merci de confirmer la réception", " (domicile)",
    " ; ancienne adresse à supprimer", ", à l'attention du secrétariat",
]
# Mots en minuscules qui suivent la commune sur la meme ligne.
SUITES_MINUSCULES = [
    "depuis 2019", "depuis dix ans", "le 3 mai 2026", "et environs",
    "centre", "pour le courrier", "à confirmer", "uniquement",
    "jusqu'à nouvel ordre", "comme l'an dernier",
]

POSITIONS = ("debut_texte", "debut_ligne", "apres_phrase")
SUITES = ("rien", "ligne", "ponctuation", "minuscule")
CASSES = ("ordinaire", "minuscules")


def construit_doc(rng, position, suite, casse):
    """Un document de l'axe donne ; rend (texte, debut, fin) de l'adresse."""
    cp, commune = rng.choice(COMMUNES)
    adresse = f"{cp} {commune}"
    if position == "debut_texte":
        avant = ""
    elif position == "debut_ligne":
        avant = rng.choice(LIGNES_AVANT) + "\n"
    else:
        avant = rng.choice(PHRASES_AVANT) + " "
    if suite == "rien":
        apres = ""
    elif suite == "ligne":
        apres = "\n" + rng.choice(LIGNES_APRES)
    elif suite == "ponctuation":
        apres = rng.choice(PONCTUATIONS) + "."
    else:
        apres = " " + rng.choice(SUITES_MINUSCULES) + "."
    texte = avant + adresse + apres
    debut = len(avant)
    fin = debut + len(adresse)
    if casse == "minuscules":
        minuscules = texte.lower()
        # La mise en minuscules ne change aucune longueur dans ce vocabulaire ;
        # le test du corpus le verifie sur chaque document.
        assert len(minuscules) == len(texte)
        texte = minuscules
    return texte, debut, fin


def construit(n, seed):
    rng = random.Random(f"{seed}-cp-tete")
    axes = [(p, s, c) for p in POSITIONS for s in SUITES for c in CASSES]
    docs = []
    for i in range(n):
        position, suite, casse = axes[i % len(axes)]
        texte, debut, fin = construit_doc(rng, position, suite, casse)
        docs.append({
            "id": i, "text": texte,
            "entities": [{"type": "adresse", "start": debut, "end": fin}],
            "position": position, "suite": suite, "casse": casse})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=432)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_flou_cp_tete.jsonl")
    a = p.parse_args()
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{a.out} : {len(docs)} documents, {len(docs)} adresses annotees")


if __name__ == "__main__":
    main()
