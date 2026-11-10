#!/usr/bin/env python3
"""Construit `first_names_effectifs.tsv.gz` a partir du fichier national des
prenoms de l'INSEE (P2-149, spec `agent/specs/P2-148.md`).

Pourquoi un asset de plus que `first_names.txt.gz` : la « liste des prenoms »
deja embarquee n'a pas d'effectifs ; elle garde tout prenom attribue au moins
trois fois depuis 1900, donc des mots courants (« Bilan », « Maison », « Rue »)
qu'un detecteur ne peut pas distinguer d'un prenom. Le fichier national donne
les effectifs par annee : leur somme permet un seuil, choisi sur mesure.

Lecture : un CSV (ou un ZIP qui en contient un seul) a separateur `;` ou `,`,
ou le fichier Parquet « ensemble des donnees » de l'INSEE. Le Parquet exige
`pyarrow`, importe seulement dans ce cas (aucune dependance ajoutee au depot :
`pip install pyarrow` sur le poste qui construit l'asset). Si une colonne
`niveau_geographique` existe, seules les lignes `FRANCE` sont lues : les
lignes regionales et departementales repetent les memes naissances.
Les colonnes sont reconnues par leur nom, pas par leur position, parce que
leur intitule a change d'une edition a l'autre :
  - prenom : la colonne dont le nom contient « pren », ou `preusuel`
    (intitule des editions anterieures) ;
  - effectif : `valeur`, `nombre` ou `effectif` (casse ignoree).
Toute autre forme est refusee avec un motif (regle 4 de `CLAUDE.md`).
Les lignes de regroupement de l'INSEE (`_PRENOMS_RARES`) sont ecartees.

Normalisation identique a `build_reference_assets.py` (`norm_name`) et a
`normName` en Dart : la parite est la condition pour que les recherches ne
ratent pas en silence. Comme la liste, les formes de moins de 3 caracteres
sont ecartees.

Sortie (UTF-8, gzip deterministe, mtime 0) :
  # Source : Insee, <libelle> ; Licence Ouverte v2.0 (Etalab)
  PRENOM \\t effectif cumule (toutes annees, deux sexes)
trie par prenom.

Aucun acces reseau : le fichier est fourni par le mainteneur.

Usage :
    python3 tools/build_prenoms_effectifs.py prenoms-2025-nat_csv.zip \\
        packages/ecluse_reference/assets/first_names_effectifs.tsv.gz \\
        --libelle "fichier des prenoms, edition de juillet 2026"
"""

import argparse
import csv
import gzip
import io
import os
import sys
import unicodedata
import zipfile

REGROUPEMENTS = {"_PRENOMS_RARES", "PRENOMS_RARES"}
COLONNES_EFFECTIF = ("valeur", "nombre", "effectif")


def norm_name(s):
    """Copie exacte de `build_reference_assets.norm_name`."""
    if s is None:
        return ""
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode()
    s = s.upper()
    for ch in "'-’./":
        s = s.replace(ch, " ")
    return " ".join(s.split())


def lire_parquet(chemin):
    """Lignes du Parquet en texte CSV `;`, pour un seul chemin de lecture."""
    import pyarrow.parquet as pq  # facultatif : seulement pour un Parquet

    table = pq.read_table(chemin)
    noms = table.column_names
    sortie = io.StringIO()
    ecrivain = csv.writer(sortie, delimiter=";", lineterminator="\n")
    ecrivain.writerow(noms)
    for lot in table.to_batches():
        colonnes_lot = [lot.column(i).to_pylist() for i in range(len(noms))]
        for ligne in zip(*colonnes_lot):
            ecrivain.writerow(["" if v is None else v for v in ligne])
    return sortie.getvalue()


def lire_texte(chemin):
    if chemin.lower().endswith(".parquet"):
        return lire_parquet(chemin)
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
    return brut.decode("utf-8-sig")


def colonnes(entete):
    bas = [c.strip().lower() for c in entete]
    prenom = [i for i, c in enumerate(bas) if "pren" in c or c == "preusuel"]
    effectif = [i for i, c in enumerate(bas) if c in COLONNES_EFFECTIF]
    if len(prenom) != 1 or len(effectif) != 1:
        raise SystemExit(f"refus : colonnes non reconnues {entete!r} "
                         "(une colonne « pren… » ou preusuel et une colonne "
                         f"{'/'.join(COLONNES_EFFECTIF)} attendues)")
    return prenom[0], effectif[0]


def effectifs(texte):
    premiere = texte.split("\n", 1)[0]
    sep = ";" if premiere.count(";") >= premiere.count(",") else ","
    lecteur = csv.reader(io.StringIO(texte), delimiter=sep)
    entete = next(lecteur, None)
    if entete is None:
        raise SystemExit("refus : fichier vide")
    i_prenom, i_effectif = colonnes(entete)
    bas = [c.strip().lower() for c in entete]
    i_niveau = bas.index("niveau_geographique") if "niveau_geographique" in bas \
        else None
    total = {}
    for n, ligne in enumerate(lecteur, start=2):
        if not ligne or all(not c.strip() for c in ligne):
            continue
        if i_niveau is not None and ligne[i_niveau].strip().upper() != "FRANCE":
            continue
        brut = ligne[i_prenom].strip()
        if brut.upper() in REGROUPEMENTS:
            continue
        try:
            valeur = int(float(ligne[i_effectif].replace(",", ".")))
        except (ValueError, IndexError):
            raise SystemExit(f"refus : effectif illisible ligne {n} : {ligne!r}")
        nom = norm_name(brut)
        if len(nom) < 3:
            continue
        total[nom] = total.get(nom, 0) + valeur
    if not total:
        raise SystemExit("refus : aucun prenom lu")
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
    print(f"{len(total)} prenoms, {sum(total.values())} naissances, "
          f"{os.path.getsize(a.sortie)} octets", file=sys.stderr)


if __name__ == "__main__":
    main()
