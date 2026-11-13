#!/usr/bin/env python3
"""Corpus TEMOIN « nombres a cinq chiffres » (P2-167).

Des phrases francaises ordinaires ou un nombre de cinq chiffres (quantite,
montant, reference, numero de lot ou de dossier) n'est **pas** un code postal.
Aucune entite n'est annotee (`"entities": []`) : toute adresse predite est un
faux positif. Un code postal est suivi d'une commune ; un nombre de cinq
chiffres suivi d'un mot a la meme forme, d'ou le risque.

Chaque phrase porte ses axes (champs `famille`, `suffixe`, `position`,
`casse`) pour que le banc dise ou se trouve le defaut :

- famille : quantite, montant, reference (lot, dossier, numero) ;
- suffixe : mot en minuscules, mot a majuscule, ou rien (fin de phrase) ;
- position : le nombre ouvre la phrase, ou vient apres des mots ;
- casse du texte : `ordinaire` (une majuscule hors debut de phrase) ou
  `phrase` (seule l'initiale de la phrase est en majuscule : les detecteurs de
  casse y recapitalisent).

Les suffixes sont des mots du vocabulaire courant tires d'un lexique general
(noms de comptage, noms communs, codes de lot), **jamais** choisis d'apres les
mots que le detecteur connait deja. Donnees entierement synthetiques, graine
fixe, aucune valeur reelle.

Usage :
    python3 generate_corpus_cinq_chiffres.py --n 400 --seed 42 \\
        --out flou/corpus_flou_cinq_chiffres.jsonl
"""

import argparse
import json
import random

# Noms communs ou de comptage qui suivent un nombre de quantite.
NOMS_MINUSCULES = [
    "unités", "pièces", "exemplaires", "colis", "boîtes", "palettes",
    "visiteurs", "abonnés", "licences", "kilos", "litres", "tonnes",
    "cartes", "mètres", "adhérents", "formulaires", "courriers", "ordonnances",
    "repas", "lots", "références", "articles", "factures", "euros", "dossiers",
]
# Mots a majuscule qui suivent une reference : codes de lot, noms de gamme,
# noms de service. Un tel mot a la forme d'une commune ; le corpus le compte.
MOTS_MAJUSCULES = [
    "Alpha", "Bravo", "Delta", "Archive", "Nord", "Premium", "Standard",
    "Express", "Unités", "Pièces", "Total", "Plan", "Série", "Version",
]
VERBES_FIN = ["en stock", "livrés", "commandés", "expédiés", "clôturé",
              "archivé", "validé"]

QUANTITE = [
    "Commande de {n} {mot}", "Stock de {n} {mot}", "Livraison de {n} {mot}",
    "Un total de {n} {mot}", "Environ {n} {mot}", "Inventaire de {n} {mot}",
]
MONTANT = [
    "Budget de {n} {mot}", "Facture de {n} {mot}", "Devis de {n} {mot}",
]
REFERENCE = [
    "Réf. {n} {mot}", "Référence {n} {mot}", "Dossier n° {n} {mot}",
    "Lot {n} {mot}", "N° de lot {n} {mot}", "Commande {n} {mot}",
]
FAMILLES = {"quantite": QUANTITE, "montant": MONTANT, "reference": REFERENCE}

# Une majuscule hors debut de phrase, pour sortir du mode « casse de phrase ».
SUITE_ORDINAIRE = ["Rapport du service Qualité.", "Merci de répondre à Marie.",
                   "Voir la note de la Direction."]


def nombre5(rng):
    return str(rng.randrange(10_000, 99_999))


def construit_phrase(rng, famille, suffixe, position, casse):
    """Une phrase de l'axe donne ; rend (texte, champs)."""
    n = nombre5(rng)
    modele = rng.choice(FAMILLES[famille])
    if suffixe == "minuscule":
        mot = (rng.choice(["euros", "euros", "euro"]) if famille == "montant"
               else rng.choice(NOMS_MINUSCULES))
    elif suffixe == "majuscule":
        mot = rng.choice(MOTS_MAJUSCULES)
    else:
        mot = ""
    if position == "debut":
        # le nombre ouvre la phrase : « 70000 unités ont été livrées. »
        if suffixe == "rien":
            corps = f"{n} en stock."
        else:
            corps = f"{n} {mot} {rng.choice(VERBES_FIN)}."
        texte = corps
    else:
        phrase = modele.format(n=n, mot=mot).rstrip()
        if suffixe != "rien":
            fin = rng.choice(["", " ce mois-ci", " au dernier relevé"])
            texte = f"{phrase}{fin}."
        else:
            texte = f"{phrase}."
    if casse == "ordinaire":
        texte = f"{texte} {rng.choice(SUITE_ORDINAIRE)}"
    return texte


def construit(n, seed):
    rng = random.Random(f"{seed}-cinq-chiffres")
    axes = [(f, s, p, c)
            for f in FAMILLES
            for s in ("minuscule", "majuscule", "rien")
            for p in ("debut", "milieu")
            for c in ("ordinaire", "phrase")]
    docs = []
    for i in range(n):
        f, s, p, c = axes[i % len(axes)]
        if f == "montant" and s == "majuscule":
            # « Budget de 12500 Alpha » n'a pas de sens : un montant est suivi
            # d'une unite monetaire en minuscules.
            s = "minuscule"
        if s == "majuscule":
            # Un mot a majuscule apres le nombre est une majuscule hors debut
            # de phrase : le texte n'est plus en casse de phrase.
            c = "ordinaire"
        docs.append({
            "id": i, "text": construit_phrase(rng, f, s, p, c),
            "entities": [], "famille": f, "suffixe": s, "position": p,
            "casse": c})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=400)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_flou_cinq_chiffres.jsonl")
    a = p.parse_args()
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{a.out} : {len(docs)} phrases, 0 entite annotee")


if __name__ == "__main__":
    main()
