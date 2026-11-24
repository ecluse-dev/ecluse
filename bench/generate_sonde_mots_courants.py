#!/usr/bin/env python3
"""Sonde de P2-287 (mesure) : mots courants, en tête de phrase, qu'une commune de
la référence publique porte pour homonyme. Deux jeux, synthétiques :

- `isole` : 112 mots x 2 phrases (« {Mot} numéro de sécurité sociale doit être
  vérifié avant l'envoi. » et « Le dossier est complet. {Mot} était à jour hier. ») ;
- `combine` : un patient fictif (âge, profession, une vraie commune) suivi de la
  même phrase, pour mesurer ce que le faux lieu fait à un rapport qui marchait.

Usage : python3 generate_sonde_mots_courants.py --out-dir DOSSIER
"""
import argparse
import json
import os

MOTS = """Son Sept Huit Six Cinq Quatre Trois Deux Neuf Bourg Aucun Aucune Pour Dans
Vers Cours Salles Mon Ton Elle Nous Vous Tout Toute Avant Après Sur Sous Contre
Entre Chez Notre Votre Leur Mes Ces Cette Ce Les Des Une Un Du Il Ils Ici Rien
Plus Moins Bien Mal Loin Près Fort Bon Mieux Haut Bas Long Grand Petit Vieux Beau
Doux Sain Pont Port Mer Nord Sud Est Ouest Lac Mont Val Bois Champ Plaine Source
Marché Fontaine Église Mairie Ville Rue Place Saint Sainte Madame Monsieur Patient
Patiente Dossier Date Suite Reste Pierre Vigne Chapelle Tour Mort Vie Paix Vaux
Fond Tilleuls Rosiers Chênes Lilas Gare Ferme Moulin""".split()
BASE = "Mme Camille Faure, 45 ans, infirmière à Rioz."


def ecrit(chemin, docs):
    with open(chemin, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    isole = []
    for m in MOTS:
        for forme, t in (("debut", f"{m} numéro de sécurité sociale doit être vérifié avant l'envoi."),
                         ("apres_point", f"Le dossier est complet. {m} était à jour hier.")):
            isole.append({"id": len(isole), "mot": m, "forme": forme, "text": t, "entities": []})
    ecrit(os.path.join(a.out_dir, "sonde_isole.jsonl"), isole)
    combine = [{"id": 0, "mot": "(aucun)", "text": BASE, "entities": []}]
    for m in ["Son", "Aucun", "Mont", "Cours", "Salles", "Vers", "Contre"]:
        combine.append({"id": len(combine), "mot": m, "entities": [],
                        "text": BASE + f" {m} numéro de sécurité sociale doit être vérifié."})
    combine.append({"id": len(combine), "mot": "son (minuscule)", "entities": [],
                    "text": BASE + " Elle vérifie son numéro de sécurité sociale."})
    ecrit(os.path.join(a.out_dir, "sonde_combine.jsonl"), combine)
    print(f"{len(isole)} + {len(combine)} documents écrits dans {a.out_dir}")


main()
