#!/usr/bin/env python3
"""Construit `communes_nom_exact.dart` (paquet `ecluse_redact`) a partir du
referentiel des communes deja versionne (P2-214).

Pourquoi une table embarquee : `AdresseDetector` est un detecteur pur et
synchrone, appele par `Ecluse.redact` sans option. Il ne peut ni charger un
asset ni attendre. La regle « nom exact du referentiel » (decision du
16 novembre, `DECISIONS.md`) ne sert qu'aux noms que le motif du detecteur ne
sait pas lire en entier ; ils sont peu nombreux, donc ecrits en dur :

- forme A : cinq mots ou plus (le motif s'arrete au quatrieme) ;
- forme C : parenthese, tiret isole ou blancs multiples dans le libelle
  officiel (« Chateau-Chinon (Ville) », « Sarroux - Saint Julien ») ;
- forme D : determinant puis mot neutre (« LES PLACES »).

La forme B (mot neutre en tete, hors determinant : « SON », « VERS », « SOUS
PARSAT ») est **laissee de cote** par la meme decision : ces noms ne sont pas
dans la table, quelle que soit leur longueur.

Cle : le nom de la colonne `NORM`, ou tout ce qui n'est ni lettre ni chiffre
devient une espace (parentheses comprises), espaces reduites. Le detecteur
normalise le texte de la meme facon avant de comparer.

Source : `packages/ecluse_reference/assets/geo_communes.csv.gz` (INSEE, Code
officiel geographique, Licence Ouverte v2.0 : `DATA_SOURCES.md`). Les mots
neutres sont lus dans `mots_neutres.dart`. Aucun acces reseau, sortie
deterministe (triee).

Usage, depuis la racine :
    python3 tools/build_communes_nom_exact.py
    python3 tools/build_communes_nom_exact.py --verifie   # code 1 si perime
"""

import argparse
import gzip
import os
import re
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
COMMUNES = os.path.join(RACINE, "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")
HEURISTIQUES = os.path.join(RACINE, "packages", "ecluse_redact", "lib", "src",
                            "heuristics")
MOTS_NEUTRES = os.path.join(HEURISTIQUES, "mots_neutres.dart")
SORTIE = os.path.join(HEURISTIQUES, "communes_nom_exact.dart")
DETERMINANTS = {"le", "la", "les", "l"}

_BLOC = re.compile(r"const\s+Set<String>\s+motsNeutres\s*=\s*\{(.*?)\};", re.S)


def lit_mots_neutres(chemin):
    with open(chemin, encoding="utf-8") as f:
        bloc = _BLOC.search(f.read())
    if bloc is None:
        raise ValueError("ensemble motsNeutres introuvable")
    mots = set(re.findall(r"'([^']*)'", re.sub(r"//[^\n]*", "",
                                               bloc.group(1))))
    if not mots:
        raise ValueError("ensemble motsNeutres vide")
    return mots


def cle(norm):
    """« CHATEAU CHINON (VILLE) » -> « CHATEAU CHINON VILLE »."""
    return " ".join(re.sub(r"[^A-Z0-9]+", " ", norm).split())


def forme(norm, libelle, neutres):
    """« A », « C », « D », ou None (nom que le motif lit deja, ou forme B)."""
    mots = cle(norm).lower().split()
    if not mots:
        return None
    if mots[0] in neutres and mots[0] not in DETERMINANTS:
        return None  # forme B, laissee de cote
    if mots[0] in DETERMINANTS and len(mots) > 1 and mots[1] in neutres:
        return "D"
    if "(" in libelle or " - " in libelle or "  " in libelle:
        return "C"
    if len(mots) >= 5:
        return "A"
    return None


def selectionne(lignes, neutres):
    """{cle: forme} pour des lignes `COM;DEP;REG;PMUN;NORM;LIBELLE`."""
    table = {}
    for ligne in lignes:
        champs = ligne.rstrip("\n").split(";")
        if len(champs) < 6 or not champs[4]:
            continue
        f = forme(champs[4], champs[5], neutres)
        if f is not None:
            table.setdefault(cle(champs[4]), f)
    return table


def rend_dart(table):
    compte = {f: sum(1 for v in table.values() if v == f) for f in "ACD"}
    lignes = [
        "// FICHIER GENERE par tools/build_communes_nom_exact.py : ne pas le",
        "// modifier a la main. Regenerer apres tout changement du referentiel",
        "// des communes ou de mots_neutres.dart ; un test en verifie la parite.",
        "",
        "/// Noms de communes que le motif d'`AdresseDetector` ne lit pas en",
        "/// entier (P2-214, regle « nom exact du referentiel ») : "
        f"{compte['A']} de cinq",
        f"/// mots ou plus, {compte['C']} a parenthese ou tiret isole, "
        f"{compte['D']} en « determinant +",
        "/// mot neutre ». Forme postale du referentiel public (INSEE, Code",
        "/// officiel geographique, Licence Ouverte v2.0), sans accent, en",
        "/// capitales, toute ponctuation remplacee par une espace.",
        "///",
        "/// Interne au paquet : non exporte par `ecluse_redact.dart`.",
        "const Set<String> communesNomExact = {",
    ]
    lignes += [f"  '{nom}'," for nom in sorted(table)]
    lignes += ["};", "",
               "/// Nombre de mots du plus long nom de [communesNomExact].",
               "const int communesNomExactMotsMax = "
               f"{max(len(n.split()) for n in table)};", ""]
    return "\n".join(lignes)


def construit():
    neutres = lit_mots_neutres(MOTS_NEUTRES)
    with gzip.open(COMMUNES, "rt", encoding="utf-8") as f:
        next(f)
        table = selectionne(f, neutres)
    if not table:
        raise ValueError("aucune commune retenue : referentiel illisible ?")
    return rend_dart(table)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--verifie", action="store_true",
                   help="ne rien ecrire ; code 1 si le fichier est perime")
    a = p.parse_args()
    contenu = construit()
    if a.verifie:
        with open(SORTIE, encoding="utf-8") as f:
            if f.read() != contenu:
                print("communes_nom_exact.dart est perime : relancer "
                      "tools/build_communes_nom_exact.py")
                sys.exit(1)
        print("communes_nom_exact.dart est a jour")
        return
    with open(SORTIE, "w", encoding="utf-8") as f:
        f.write(contenu)
    print(f"{os.path.relpath(SORTIE, RACINE)} : {contenu.count(chr(39)) // 2} "
          "noms")


if __name__ == "__main__":
    main()
