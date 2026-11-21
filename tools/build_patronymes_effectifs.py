#!/usr/bin/env python3
"""Construit `patronymes_effectifs.tsv.gz` a partir du fichier national des
noms de l'INSEE (P2-249, pour P2-250).

Pourquoi : la regle « le dossier de X » (P2-220) et la regle de forme de
P2-241 ont besoin de savoir si un mot est un nom de famille porte en France.
Le fichier national des noms de l'INSEE (« Fichier des noms », edition de mai
2018) donne, pour chaque nom attribue au moins 30 fois a des naissances de
1891 a 2000, l'effectif par decennie. Leur somme permet un seuil, choisi sur
mesure, comme pour les prenoms (P2-149). Limites, a ecrire dans `LIMITES.md`
quand la table servira : noms attribues moins de 30 fois et naissances apres
2000 absents.

Lecture : le ZIP de l'INSEE (`noms2008nat_txt.zip`) ou le texte qu'il
contient, separateur tabulation, premiere colonne `NOM`, colonnes de decennie
`_AAAA_AAAA`. Toute autre forme est refusee avec un motif (regle 4 de
`CLAUDE.md`). La ligne de regroupement de l'INSEE (`AUTRES NOMS`) est
ecartee.

Normalisation identique a `build_reference_assets.py` (`norm_name`) et a
`normName` en Dart. Les formes de moins de 2 caracteres sont ecartees.

Sortie (UTF-8, gzip deterministe, mtime 0) :
  # Source : Insee, <libelle> ; Licence Ouverte v2.0 (Etalab)
  NOM \\t effectif cumule (naissances 1891-2000)
trie par nom.

Aucun acces reseau : le fichier est fourni par le mainteneur.

Usage :
    python3 tools/build_patronymes_effectifs.py noms2008nat_txt.zip \\
        packages/ecluse_reference/assets/patronymes_effectifs.tsv.gz \\
        --libelle "fichier des noms, edition de mai 2018 (naissances 1891-2000)"
"""

import argparse
import gzip
import io
import os
import re
import sys
import unicodedata
import zipfile

REGROUPEMENTS = {"AUTRES NOMS"}
DECENNIE = re.compile(r"^_\d{4}_\d{4}$")


def norm_name(s):
    """Copie exacte de `build_reference_assets.norm_name`."""
    if s is None:
        return ""
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode()
    s = s.upper()
    for ch in "'-’./":
        s = s.replace(ch, " ")
    return " ".join(s.split())


def lire_texte(chemin):
    if zipfile.is_zipfile(chemin):
        with zipfile.ZipFile(chemin) as zf:
            txts = [n for n in zf.namelist() if n.lower().endswith(".txt")]
            if len(txts) != 1:
                raise SystemExit(f"refus : {len(txts)} fichier(s) texte dans le "
                                 "ZIP, un seul attendu")
            brut = zf.read(txts[0])
    else:
        with open(chemin, "rb") as f:
            brut = f.read()
    try:
        return brut.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise SystemExit("refus : fichier qui n'est pas en UTF-8")


def effectifs(texte):
    lignes = texte.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    entete = lignes[0].split("\t") if lignes else []
    if not entete or entete[0].strip().upper() != "NOM" or len(entete) < 2 \
            or not all(DECENNIE.match(c.strip()) for c in entete[1:]):
        raise SystemExit(f"refus : en-tete non reconnu {entete[:3]!r} "
                         "(NOM puis colonnes _AAAA_AAAA attendues)")
    total = {}
    for n, ligne in enumerate(lignes[1:], start=2):
        if not ligne.strip():
            continue
        champs = ligne.split("\t")
        if len(champs) != len(entete):
            raise SystemExit(f"refus : ligne {n} : {len(champs)} champs, "
                             f"{len(entete)} attendus")
        brut = champs[0].strip()
        if brut.upper() in REGROUPEMENTS:
            continue
        try:
            valeur = sum(int(c) for c in champs[1:])
        except ValueError:
            raise SystemExit(f"refus : effectif illisible ligne {n}")
        nom = norm_name(brut)
        if len(nom) < 2:
            continue
        total[nom] = total.get(nom, 0) + valeur
    if not total:
        raise SystemExit("refus : aucun nom lu")
    return total


def ecrire(total, sortie, libelle):
    tampon = io.StringIO()
    tampon.write(f"# Source : Insee, {libelle} ; "
                 "Licence Ouverte v2.0 (Etalab)\n")
    for nom in sorted(total):
        tampon.write(f"{nom}\t{total[nom]}\n")
    with open(sortie, "wb") as f:
        with gzip.GzipFile(fileobj=f, mode="wb", mtime=0, filename="") as gz:
            gz.write(tampon.getvalue().encode("utf-8"))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    p.add_argument("source")
    p.add_argument("sortie")
    p.add_argument("--libelle", required=True,
                   help="intitule et edition du fichier, ecrits dans l'en-tete")
    a = p.parse_args(argv)
    total = effectifs(lire_texte(a.source))
    ecrire(total, a.sortie, a.libelle)
    print(f"{len(total)} noms, {sum(total.values())} naissances, "
          f"{os.path.getsize(a.sortie)} octets", file=sys.stderr)


if __name__ == "__main__":
    main()
