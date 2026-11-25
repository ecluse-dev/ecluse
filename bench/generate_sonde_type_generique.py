#!/usr/bin/env python3
"""Sonde de P2-295 (spec) : 32 phrases synthétiques écrites à la main, 18 où le
nom derrière le type est un mot courant (« Résidence Services », « Centre
Social ») et 14 où c'est un nom propre (« Clinique Pasteur », « Foyer Les
Lilas »). Elle n'a **aucune valeur statistique** : elle montre ce que chaque
option laisse passer ou perd hors du corpus qui a servi à les écrire.

Usage : python3 generate_sonde_type_generique.py --out sonde.jsonl
"""
import argparse
import json

GENERIQUES = ["Résidence Autonomie", "Résidence Services", "Résidence Seniors",
              "Résidence Étudiante", "Foyer Logement", "Foyer Jeunes Travailleurs",
              "Foyer Médicalisé", "Foyer D'accueil Médicalisé", "Centre Médical",
              "Centre Social", "Centre Hospitalier Général", "Clinique Générale",
              "Clinique Vétérinaire", "Hôpital Local", "Hôpital Général",
              "Lycée Professionnel", "Lycée Agricole", "Lycée Hôtelier"]
NOMS = ["Clinique Pasteur", "Foyer Les Lilas", "Résidence Les Tilleuls",
        "Résidence du Parc", "Centre Jean Moulin", "Lycée Victor Hugo",
        "Hôpital Saint-Louis", "Foyer Saint-Joseph", "Clinique Bellevue",
        "Résidence Bel Air", "Centre Hospitalier de Gray", "Lycée Pasteur",
        "Foyer Espérance", "Résidence Horizon"]


def construit():
    docs = []
    for genre, liste in (("generique", GENERIQUES), ("nom", NOMS)):
        for x in liste:
            docs.append({"id": len(docs), "genre": genre, "nom": x, "entities": [],
                         "text": f"Note de service : la {x} est fermée lundi."})
    return docs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    with open(a.out, "w", encoding="utf-8") as f:
        for d in construit():
            f.write(json.dumps(d, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
