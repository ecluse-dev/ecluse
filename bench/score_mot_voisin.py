#!/usr/bin/env python3
"""P2-292 (mesure) : coût de la garde du mot voisin (P2-282) sur les
identifiants dictés abîmés précédés d'un mot voisin.

Entrées : `corpus_mot_voisin_<mode>.jsonl` (generate_corpus_mot_voisin.py) et la
sortie de `run_temoin_nombres_dictes.dart` (chemin `Ecluse.redact`). Pour chaque
document : « masqué » (l'identifiant abîmé est entièrement recouvert), « signalé »
(pas masqué en entier, avertissement « nombre dicté non reconnu ») ou « rien »
(ni l'un ni l'autre : l'identifiant part en clair sans avertissement).

Le coût d'un bras est mesuré par paires : même document source, même distance,
comparé au bras « temoin » (mots neutres de même longueur, sans mot voisin).
Seuls des nombres sont imprimés.
"""
import argparse
import json
from collections import Counter, defaultdict


def etat(e, pred):
    pos, ok = e["start"], False
    for s, f in sorted((x["start"], x["end"]) for x in pred["entities"]):
        if f <= pos:
            continue
        if s > pos:
            break
        pos = f
        if pos >= e["end"]:
            ok = True
            break
    if ok:
        return "masqué"
    return "signalé" if pred["signalements"] > 0 else "rien"


def charge(chemin_corpus, chemin_pred):
    pred = {}
    for l in open(chemin_pred, encoding="utf-8"):
        d = json.loads(l)
        pred[d["id"]] = d
    docs = []
    for l in open(chemin_corpus, encoding="utf-8"):
        d = json.loads(l)
        d["etat"] = etat(d["entities"][0], pred[d["id"]])
        docs.append(d)
    return docs


def classe(d):
    """Classe d'un document : le libellé de la fenêtre décide de la garde."""
    if d["bras"] == "temoin":
        return "temoin"
    if d["bras"] == "avec_lib":
        return "avec_lib" if d["lib_fenetre"] else "avec_lib_hors_fenetre"
    return "sans_lib_origine" if d["lib_fenetre"] else "sans_lib"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--paires", nargs="+", required=True,
                    help="corpus:pred, un par mode (mot_perdu, cle_fausse)")
    a = ap.parse_args()
    docs = []
    for p in a.paires:
        c, r = p.split(":")
        docs += charge(c, r)
    temoin = {(d["mode"], d["source"], d["d"]): d["etat"]
              for d in docs if d["bras"] == "temoin"}
    # Tableau 1 : classe × état, tous mots et distances confondus.
    print("## Par classe (tous mots, toutes distances)")
    t = defaultdict(Counter)
    for d in docs:
        t[classe(d)][d["etat"]] += 1
    for k in ("temoin", "sans_lib", "sans_lib_origine", "avec_lib", "avec_lib_hors_fenetre"):
        x = t[k]
        n = sum(x.values())
        print(f"{k:24} n={n:6} masqué={x['masqué']:6} signalé={x['signalé']:6} rien={x['rien']:6}")
    # Tableau 2 : mot × distance, bras sans libellé et bras avec libellé :
    # identifiants passés de « signalé » (témoin) à « rien » (garde).
    for bras, filtre in (("sans_lib", lambda d: not d["lib_fenetre"]),
                         ("avec_lib", lambda d: True)):
        print(f"\n## Bras {bras} : passés de « signalé » à « rien » à cause du mot voisin")
        print("(témoin signalé = identifiants que le témoin sans mot voisin signalait)")
        distances = sorted({d["d"] for d in docs})
        print("mot".ljust(14) + "".join(f"{x:>14}" for x in distances))
        for mot in ("code", "digicode", "mot de passe", "mdp", "pin"):
            ligne = mot.ljust(14)
            for x in distances:
                sel = [d for d in docs if d["bras"] == bras and d["mot"] == mot
                       and d["d"] == x and filtre(d)]
                base_sig = [d for d in sel
                            if temoin[(d["mode"], d["source"], d["d"])] == "signalé"]
                perdus = [d for d in base_sig if d["etat"] == "rien"]
                autres = [d for d in sel
                          if temoin[(d["mode"], d["source"], d["d"])] != d["etat"]
                          and not (temoin[(d["mode"], d["source"], d["d"])] == "signalé"
                                   and d["etat"] == "rien")]
                ligne += f"{len(perdus):>5}/{len(base_sig):<4}+{len(autres):<3}"
            print(ligne)
        print("(cellule : perdus / signalés au témoin + autres changements d'état)")


if __name__ == "__main__":
    main()
