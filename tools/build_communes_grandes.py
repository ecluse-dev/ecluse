#!/usr/bin/env python3
"""Construit `communes_grandes.dart` (paquet `ecluse_redact`) a partir du
referentiel des communes deja versionne (P2-220).

Pourquoi : « a la demande de Paris », « le dossier de Besancon » ne designent
pas une personne. `NameDetector`, detecteur pur et synchrone, ne peut pas
charger le referentiel ; sa regle « patronyme seul derriere une tournure de
personne » ecarte donc les communes de 100 000 habitants et plus (population
municipale, colonne `PMUN`), ecrites en dur ici (P2-239 : le seuil etait de
10 000 habitants ; il est releve car, derriere « a la demande de », un
patronyme qui est aussi une commune de 10 000 a 100 000 habitants restait en
clair, 24 fuites sur 96 au temoin de P2-226). Les communes sans population
dans le fichier (Paris, Lyon, Marseille, decoupees en arrondissements, et 17
communes de Mayotte) sont retenues. Les communes plus petites ne sont **pas** ecartees : dans le doute,
le mot est masque (un patronyme pris pour une commune serait une fuite).

Cle : le nom de la colonne `NORM`, toute ponctuation remplacee par une espace.
Le detecteur normalise le mot de la meme facon (sans accent, capitales).

Source : `packages/ecluse_reference/assets/geo_communes.csv.gz` (INSEE, Code
officiel geographique, Licence Ouverte v2.0 : `DATA_SOURCES.md`). Aucun acces
reseau, sortie deterministe (triee).

Usage, depuis la racine :
    python3 tools/build_communes_grandes.py
    python3 tools/build_communes_grandes.py --verifie   # code 1 si perime
"""

import argparse
import gzip
import os
import re
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
COMMUNES = os.path.join(RACINE, "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")
SORTIE = os.path.join(RACINE, "packages", "ecluse_redact", "lib", "src",
                      "heuristics", "communes_grandes.dart")
SEUIL = 100000


def cle(norm):
    """« SAINT-DENIS » -> « SAINT DENIS »."""
    return " ".join(re.sub(r"[^A-Z0-9]+", " ", norm).split())


def selectionne(lignes, seuil=SEUIL):
    """Ensemble de cles pour des lignes `COM;DEP;REG;PMUN;NORM;LIBELLE`."""
    noms = set()
    for ligne in lignes:
        champs = ligne.rstrip("\n").split(";")
        if len(champs) < 6 or not champs[4]:
            continue
        pmun = champs[3].strip()
        if pmun == "" or (pmun.isdigit() and int(pmun) >= seuil):
            noms.add(cle(champs[4]))
    noms.discard("")
    return noms


def rend_dart(noms):
    lignes = [
        "// FICHIER GENERE par tools/build_communes_grandes.py : ne pas le",
        "// modifier a la main. Regenerer apres tout changement du referentiel",
        "// des communes ; un test Python en verifie la parite.",
        "",
        "/// Noms des communes de 100 000 habitants et plus (population",
        f"/// municipale >= {SEUIL}, ou non renseignee : Paris, Lyon, Marseille, Mayotte),",
        "/// que `NameDetector` ne prend pas pour un patronyme derriere une",
        "/// tournure de personne (P2-220). Forme du referentiel public (INSEE,",
        "/// Code officiel geographique, Licence Ouverte v2.0), sans accent, en",
        "/// capitales, toute ponctuation remplacee par une espace.",
        "///",
        "/// Interne au paquet : non exporte par `ecluse_redact.dart`.",
        "const Set<String> communesGrandes = {",
    ]
    lignes += [f"  '{nom}'," for nom in sorted(noms)]
    lignes += ["};", ""]
    return "\n".join(lignes)


def construit():
    with gzip.open(COMMUNES, "rt", encoding="utf-8") as f:
        next(f)
        noms = selectionne(f)
    if not noms:
        raise ValueError("aucune commune retenue : referentiel illisible ?")
    return rend_dart(noms)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--verifie", action="store_true",
                   help="ne rien ecrire ; code 1 si le fichier est perime")
    a = p.parse_args()
    contenu = construit()
    if a.verifie:
        with open(SORTIE, encoding="utf-8") as f:
            if f.read() != contenu:
                print("communes_grandes.dart est perime : relancer "
                      "tools/build_communes_grandes.py")
                sys.exit(1)
        print("communes_grandes.dart est a jour")
        return
    with open(SORTIE, "w", encoding="utf-8") as f:
        f.write(contenu)
    print(f"{os.path.relpath(SORTIE, RACINE)} : {contenu.count(chr(39)) // 2} "
          "noms")


if __name__ == "__main__":
    main()
