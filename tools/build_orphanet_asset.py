#!/usr/bin/env python3
"""Construit `patho_orphanet.tsv.gz` a partir du pack de nomenclature Orphanet.

Decision P2-113 (`DECISIONS.md`, `agent/specs/P2-113.md`) :
  - seules les entites linearisees (un parent preferentiel) sont gardees :
    elles sont actives, et leur parent donne directement la categorie ;
  - les mentions de quatre caracteres ou moins sont ecartees, sauf la liste
    blanche SIGLES_AUTORISES : la plupart sont des sigles qui collisionnent
    avec l'usage soignant (ALD = affection de longue duree, TS = tentative de
    suicide) et produiraient des faux positifs ;
  - les alignements CIM-10 / CIM-11 du pack ne sont pas lus (codes sous
    licences OMS / ATIH).

Pourquoi un script a part de `build_reference_assets.py` : la source a sa
propre licence (CC BY 4.0, pas Licence Ouverte), son propre rythme (pack
annuel, juillet) et n'a besoin que de la bibliotheque standard.

Sortie (UTF-8, gzip deterministe, mtime 0) :
  # ligne d'en-tete : source, version, date d'extraction, licence
  ORPHAcode \t categorie \t nom \t mention \t mention ...
Le nom de la categorie et le nom de l'entite sont ceux du fichier, sans
modification. Les mentions sont le nom et les synonymes retenus, dans
l'ordre du fichier, sans doublon (comparaison en minuscules).

Aucun acces reseau : le ZIP est fourni par le mainteneur.

Usage :
    python3 tools/build_orphanet_asset.py Orphanet_Nomenclature_Pack_FR.zip \\
        packages/ecluse_reference/assets/patho_orphanet.tsv.gz
"""

import argparse
import gzip
import io
import sys
import xml.etree.ElementTree as ET
import zipfile

LINEARISATION = "ORPHAlinearisation_fr_"
NOMENCLATURE = "ORPHAnomenclature_fr_"
LONGUEUR_MIN = 5
SIGLES_AUTORISES = frozenset({"sla"})


def _membre(zf, prefixe):
    noms = [n for n in zf.namelist()
            if n.rsplit("/", 1)[-1].startswith(prefixe) and n.endswith(".xml")]
    if len(noms) != 1:
        raise SystemExit(f"refus : {len(noms)} fichier(s) {prefixe}*.xml "
                         "dans le ZIP, un seul attendu")
    return noms[0]


def _racine(zf, nom):
    racine = ET.parse(zf.open(nom)).getroot()
    licence = racine.findtext("Availability/Licence/ShortIdentifier")
    if licence != "CC-BY-4.0":
        raise SystemExit(f"refus : licence {licence!r} dans {nom}, "
                         "CC-BY-4.0 attendue")
    return racine


def _garde(mention):
    m = mention.strip().lower()
    return len(m) >= LONGUEUR_MIN or m in SIGLES_AUTORISES


def construit(chemin_zip):
    """Rend (lignes, rapport). Refuse explicitement tout pack inattendu."""
    with zipfile.ZipFile(chemin_zip) as zf:
        lin = _racine(zf, _membre(zf, LINEARISATION))
        nom = _racine(zf, _membre(zf, NOMENCLATURE))
    version = nom.get("ExtractionDate", "?")

    categorie = {}
    for d in lin.find("DisorderList"):
        cible = d.find(".//TargetDisorder/Name")
        if cible is not None and cible.text:
            categorie[d.findtext("OrphaCode")] = cible.text.strip()

    lignes, ecartees, sigles = [], 0, 0
    for d in nom.find("DisorderList"):
        code = d.findtext("OrphaCode")
        if code not in categorie:
            ecartees += 1
            continue
        nom_entite = (d.findtext("Name") or "").strip()
        vues, mentions = set(), []
        for s in [nom_entite] + [x.text or "" for x in
                                 d.findall("SynonymList/Synonym")]:
            s = " ".join(s.split())
            if not s or s.lower() in vues:
                continue
            vues.add(s.lower())
            if _garde(s):
                mentions.append(s)
            else:
                sigles += 1
        if not mentions:
            ecartees += 1
            continue
        champs = [code, categorie[code], nom_entite] + mentions
        if any("\t" in c or "\n" in c for c in champs):
            raise SystemExit(f"refus : tabulation ou saut de ligne dans "
                             f"ORPHAcode {code}")
        lignes.append(champs)

    lignes.sort(key=lambda c: int(c[0]))
    rapport = {"version": version, "entites": len(lignes),
               "ecartees": ecartees, "mentions_courtes_ecartees": sigles,
               "categories": len({c[1] for c in lignes})}
    return lignes, rapport


def ecrit(lignes, rapport, sortie):
    buf = io.StringIO()
    buf.write(f"# Orphanet nomenclature FR, extraction {rapport['version']}, "
              "CC BY 4.0, donnees filtrees par Ecluse (voir NOTICE)\n")
    for champs in lignes:
        buf.write("\t".join(champs) + "\n")
    with open(sortie, "wb") as f:
        f.write(gzip.compress(buf.getvalue().encode("utf-8"), 9, mtime=0))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("pack_zip")
    p.add_argument("sortie")
    a = p.parse_args(argv)
    lignes, rapport = construit(a.pack_zip)
    ecrit(lignes, rapport, a.sortie)
    print(rapport)


if __name__ == "__main__":
    sys.exit(main())
