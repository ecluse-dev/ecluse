#!/usr/bin/env python3
"""Construit `formes_verbales.txt.gz` a partir de Morphalou 3.1 (P2-249, pour
P2-251).

Pourquoi : la regle « prenom + mot » ne doit masquer aucun verbe (decision du
20 novembre). Une liste ecrite a la main generalise mal (P2-242 : 558 formes,
180 verbes de reserve sur 200 encore masques). Morphalou 3.1 (ATILF, CNRS)
donne toutes les formes flechies de 14 760 verbes.

Licence : Morphalou 3.1 est distribue sous LGPL-LR. Ce fichier derive reste
sous LGPL-LR (section 2c) : il vit dans `packages/ecluse_lexique/`, a cote du
texte de la licence, jamais dans le coeur Apache 2.0. La modification
(extraction des formes des lemmes de categorie « Verbe ») et sa date sont
ecrites en tete du fichier, comme l'exige la section 2b.

Lecture : le ZIP « Morphalou3.1_formatCSV_toutEnUn.zip » d'ORTOLANG, ou le CSV
qu'il contient. Format attendu : en-tete libre, puis une ligne
`GRAPHIE;ID;CATÉGORIE;...` ; colonnes 0 (lemme), 2 (categorie), 4
(locution), 9 (forme flechie) ; une ligne de lemme vide reprend le lemme
precedent. Toute autre forme est refusee avec un motif (regle 4 de
`CLAUDE.md`). Les locutions sont ecartees.

Sortie (UTF-8, gzip deterministe, mtime 0) : en-tete `#`, puis une forme par
ligne, telle que dans Morphalou (minuscules, accents conserves), triee.

Aucun acces reseau : le fichier est fourni par le mainteneur.

Usage :
    python3 tools/build_formes_verbales.py Morphalou3.1_formatCSV_toutEnUn.zip \\
        packages/ecluse_lexique/assets/formes_verbales.txt.gz --date 2026-11-21
"""

import argparse
import gzip
import io
import os
import sys
import zipfile

ENTETE = "GRAPHIE;ID;CAT"


def lire_texte(chemin):
    if zipfile.is_zipfile(chemin):
        with zipfile.ZipFile(chemin) as zf:
            csvs = [n for n in zf.namelist() if n.lower().endswith(".csv")]
            if len(csvs) != 1:
                raise SystemExit(f"refus : {len(csvs)} fichier(s) CSV dans le "
                                 "ZIP, un seul attendu")
            brut = zf.read(csvs[0])
    else:
        with open(chemin, "rb") as f:
            brut = f.read()
    try:
        return brut.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise SystemExit("refus : fichier qui n'est pas en UTF-8")


def formes_verbales(texte):
    lignes = texte.replace("\r\n", "\n").split("\n")
    debut = next((i for i, l in enumerate(lignes) if l.startswith(ENTETE)), None)
    if debut is None:
        raise SystemExit("refus : ligne d'en-tete GRAPHIE;ID;CATÉGORIE absente")
    formes, lemmes = set(), set()
    categorie = locution = lemme = None
    for n, ligne in enumerate(lignes[debut + 1:], start=debut + 2):
        if not ligne.strip():
            continue
        c = ligne.split(";")
        if len(c) < 10:
            raise SystemExit(f"refus : ligne {n} : {len(c)} champs, 10 au moins")
        if c[0]:
            lemme, categorie, locution = c[0], c[2], c[4]
        elif lemme is None:
            raise SystemExit(f"refus : ligne {n} : forme sans lemme")
        if categorie == "Verbe" and not locution and c[9]:
            formes.add(c[9])
            lemmes.add(lemme)
    if not formes:
        raise SystemExit("refus : aucune forme verbale lue")
    return formes, len(lemmes)


def ecrire(formes, nb_lemmes, sortie, date):
    tampon = io.StringIO()
    tampon.write("# Derive de Morphalou 3.1 (ATILF, CNRS - Universite de "
                 "Lorraine), ORTOLANG, https://hdl.handle.net/11403/morphalou/v3.1\n")
    tampon.write("# Licence : LGPL-LR (voir LICENSE dans ce paquet)\n")
    tampon.write(f"# Modifie le {date} par le projet Ecluse : extraction des "
                 f"formes flechies des {nb_lemmes} lemmes de categorie Verbe, "
                 "locutions exclues (tools/build_formes_verbales.py)\n")
    for f in sorted(formes):
        tampon.write(f + "\n")
    with open(sortie, "wb") as f:
        with gzip.GzipFile(fileobj=f, mode="wb", mtime=0, filename="") as gz:
            gz.write(tampon.getvalue().encode("utf-8"))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    p.add_argument("source")
    p.add_argument("sortie")
    p.add_argument("--date", required=True, help="date de la modification (AAAA-MM-JJ)")
    a = p.parse_args(argv)
    formes, nb = formes_verbales(lire_texte(a.source))
    ecrire(formes, nb, a.sortie, a.date)
    print(f"{len(formes)} formes, {nb} lemmes, {os.path.getsize(a.sortie)} octets",
          file=sys.stderr)


if __name__ == "__main__":
    main()
