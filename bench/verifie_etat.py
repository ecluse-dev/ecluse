#!/usr/bin/env python3
"""Vérifie la sortie de `bench/etat.sh` contre `etat_attendu.ATTENDU` (P2-168).

Usage : python3 verifie_etat.py <sortie.log>
Code 0 si chaque section attendue contient ses lignes ; sinon 1, avec la liste
des trous (une section manquante, un motif trop rare) et des lignes ÉCHEC.
"""

import re
import sys

from etat_attendu import ATTENDU, LIGNES_ECHEC


def sections(lignes):
    """{titre: [lignes]} ; un titre « ## … » ouvre une section."""
    res, courant = {}, None
    for l in lignes:
        if l.startswith("## "):
            courant = l
            res.setdefault(courant, [])
            if l.startswith("## commit"):
                res[courant].append(l)
        elif courant is not None:
            res[courant].append(l)
    return res


def verifie(texte):
    """Rend la liste des problèmes (vide si tout est en ordre)."""
    lignes = texte.splitlines()
    problemes = [f"ligne d'échec : {l}" for l in lignes
                 if l.startswith(LIGNES_ECHEC)]
    par_section = sections(lignes)
    for prefixe, regles in ATTENDU:
        titres = [t for t in par_section if t.startswith(prefixe)]
        if not titres:
            problemes.append(f"section manquante : {prefixe}")
            continue
        contenu = par_section[titres[0]]
        for motif, minimum, explication in regles:
            n = sum(1 for l in contenu if re.search(motif, l))
            if n < minimum:
                problemes.append(
                    f"{prefixe} : {n} ligne(s) pour /{motif}/ "
                    f"({explication}), {minimum} attendue(s)")
    return problemes


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 64
    try:
        texte = open(sys.argv[1], encoding="utf-8").read()
    except OSError as e:
        print(f"ÉCHEC : sortie illisible ({e.strerror})")
        return 66
    problemes = verifie(texte)
    for p in problemes:
        print(f"MANQUE : {p}")
    if problemes:
        print(f"ÉCHEC : {len(problemes)} problème(s) dans le tableau de bord")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
