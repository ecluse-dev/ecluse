#!/usr/bin/env python3
"""Compte les phrases signalées « nombre dicté non reconnu » à tort (P2-291).

Entrée : les prédictions de `run_temoin_nombres_dictes.dart` (`Ecluse.redact`,
chemin du produit) sur un témoin sans aucune entité annotée : toute phrase
signalée, ou masquée, y est un signalement ou un masquage en trop. Ne lit que
les comptes ; aucun texte n'est lu ni imprimé.

Usage : python3 compte_signalements_a_tort.py ETIQUETTE PRED.jsonl
Sortie : `ETIQUETTE : S signalées à tort, M masquées à tort sur N phrases ;
A avertissements « mot voisin »` : depuis P2-299, une suite que la garde du mot
voisin dispense du signalement reçoit un avertissement distinct, compté à part
(pas dans S).
"""
import json
import sys


def compte(chemin):
    n = signalees = masquees = mot_voisin = 0
    for ligne in open(chemin, encoding="utf-8"):
        if not ligne.strip():
            continue
        d = json.loads(ligne)
        n += 1
        signalees += bool(d["signalements"])
        masquees += bool(d["entities"])
        mot_voisin += bool(d.get("signalements_mot_voisin", 0))
    if n == 0:
        raise SystemExit("ÉCHEC : aucune prédiction lue")
    return n, signalees, masquees, mot_voisin


def main(argv):
    if len(argv) != 3:
        raise SystemExit("usage : compte_signalements_a_tort.py ETIQUETTE PRED.jsonl")
    n, s, m, v = compte(argv[2])
    print(f"{argv[1]} : {s} signalées à tort, {m} masquées à tort sur {n} phrases ; "
          f"{v} avertissements « mot voisin »")


if __name__ == "__main__":
    main(sys.argv)
