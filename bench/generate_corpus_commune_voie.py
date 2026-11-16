#!/usr/bin/env python3
"""Balayage « commune dont le nom contient un mot de voie » (P2-213).

Constat de P2-210, vu a la main : « 52417 GRAFFIGNY CHEMIN CEDEX 7 » suivi
d'une ligne « 39314 NUMEROS EN ATTENTE » donnait « 52417 GRAFFIGNY
[ADRESSE_1] ». Le mot « CHEMIN » du nom de commune est lu comme un type de
voie, la ligne suivante comme le code postal et la commune de cette voie, et
le vrai code postal avec le debut du nom restent en clair. Ce balayage dit a
quelle echelle : **toutes** les communes du referentiel public versionne dont
la forme postale (colonne NORM) contient un mot de voie du detecteur.

Les mots de voie sont lus dans `adresse_detector.dart` lui-meme (liste
`_voies`, aucune liste recopiee) et compares sans accent, en capitales.

Axes de chaque document :

- `ecriture` x `casse`, six cases : en casse `ordinaire` (le texte autour est
  en casse ordinaire) les quatre ecritures de `generate_corpus_cedex.py`
  (`postale`, `libelle`, `libelle_espaces`, `capitales_tirets`) ; en casse
  `capitales` (tout le document en capitales) `postale` et `capitales_tirets` ;
- `cedex` : `avec` (« CEDEX n ») ou `sans` ;
- `suite`, la ligne qui suit l'adresse : `sans` (une phrase ordinaire), `mot`
  (« 39314 Colis en attente » : cinq chiffres et un mot a majuscule qui n'est
  pas un mot neutre, non annote) ou `adresse` (un autre « code postal +
  commune », annote : deux adresses sur deux lignes, comme dans une liste) ;
- `voie` : `sans`, ou `avec` : une **vraie** ligne de voie devant l'adresse
  (« 12 chemin des Vignes »), annotee avec elle. C'est le controle : une vraie
  voie doit rester masquee.

`entities` : l'adresse (de la voie ou du code postal jusqu'a la commune ou au
numero de CEDEX) et, pour `suite=adresse`, la seconde. `parties` : positions
de la voie, du code postal, de la commune, de la seconde adresse et de la
ligne « code postal + mot », pour dire **ce qui** reste en clair ou est masque
en trop. Codes postaux fabriques (departement + chiffres tires), voies et
numeros synthetiques, aucun nom de personne. Graine fixe.

Usage :
    python3 generate_corpus_commune_voie.py --seed 42 \\
        --communes ../packages/ecluse_reference/assets/geo_communes.csv.gz \\
        --detecteur ../packages/ecluse_redact/lib/src/heuristics/adresse_detector.dart \\
        --out flou/corpus_commune_voie.jsonl
"""

import argparse
import json
import random
import re
import unicodedata

import generate_corpus_cedex as gc

CASES = (("postale", "ordinaire"), ("libelle", "ordinaire"),
         ("libelle_espaces", "ordinaire"), ("capitales_tirets", "ordinaire"),
         ("postale", "capitales"), ("capitales_tirets", "capitales"))
CEDEX = ("avec", "sans")
SUITES = ("sans", "mot", "adresse")
VOIE = ("sans", "avec")
VRAIES_VOIES = ["12 chemin des Vignes", "7 rue des Lilas",
                "3 place du Marché", "45 cours de la Liberté"]
# Mots a majuscule, hors de `mots_neutres.dart` : la ligne « code postal + mot »
# a la forme d'un code postal suivi d'une commune.
MOTS_SUITE = ["Colis", "Formulaires", "Courriers", "Exemplaires"]

_BLOC = re.compile(r"static\s+const\s+_voies\s*=\s*\[(.*?)\];", re.S)
_MOT = re.compile(r"'([^']*)'")


def sans_accent(mot):
    decompose = unicodedata.normalize("NFD", mot)
    return "".join(c for c in decompose if unicodedata.category(c) != "Mn")


def lit_voies(chemin):
    """Les types de voie de `AdresseDetector._voies`, sans accent et en
    capitales. Refuse (ValueError) un fichier ou la liste est introuvable ou
    vide : jamais un balayage vide pris pour « aucune commune touchee »."""
    with open(chemin, encoding="utf-8") as f:
        source = f.read()
    bloc = _BLOC.search(source)
    if bloc is None:
        raise ValueError("liste _voies introuvable dans le fichier")
    corps = re.sub(r"//[^\n]*", "", bloc.group(1))
    voies = {sans_accent(m).upper() for m in _MOT.findall(corps)}
    if not voies:
        raise ValueError("liste _voies vide")
    return voies


def communes_a_mot_de_voie(par_mots, voies):
    """[(code, dep, norm, libelle, mot de voie)] : les communes dont un mot de
    la forme postale est un type de voie, dans l'ordre du referentiel. Le
    premier mot de voie du nom sert d'etiquette."""
    res = []
    for mots in sorted(par_mots):
        for code, dep, norm, libelle in par_mots[mots]:
            trouves = [m for m in norm.split() if m in voies]
            if trouves:
                res.append((code, dep, norm, libelle, trouves[0]))
    return res


def construit_doc(rng, dep, norm, libelle, simples, ecriture, casse, cedex,
                  suite, voie):
    """Rend (texte, entites, parties)."""
    commune = gc.ecrit(norm, libelle, ecriture)
    texte = "Courrier à adresser à :\n"
    parties = {"voie": None, "seconde": None, "ligne_mot": None}
    debut = len(texte)
    if voie == "avec":
        vraie = rng.choice(VRAIES_VOIES)
        parties["voie"] = [len(texte), len(texte) + len(vraie)]
        texte += vraie + "\n"
    cp = gc.code_postal(rng, dep)
    parties["cp"] = [len(texte), len(texte) + 5]
    texte += cp + " "
    parties["commune"] = [len(texte), len(texte) + len(commune)]
    texte += commune
    if cedex == "avec":
        texte += f" CEDEX {rng.randrange(1, 10)}"
    entites = [{"type": "adresse", "start": debut, "end": len(texte)}]
    texte += "\n"
    if suite == "mot":
        ligne = (f"{rng.randrange(10_000, 99_999)} "
                 f"{rng.choice(MOTS_SUITE)} en attente")
        parties["ligne_mot"] = [len(texte), len(texte) + len(ligne)]
        texte += ligne + "\n"
    elif suite == "adresse":
        _, dep2, norm2, libelle2 = rng.choice(simples)
        ligne = (f"{gc.code_postal(rng, dep2)} "
                 f"{gc.ecrit(norm2, libelle2, ecriture)}")
        parties["seconde"] = [len(texte), len(texte) + len(ligne)]
        entites.append({"type": "adresse", "start": len(texte),
                        "end": len(texte) + len(ligne)})
        texte += ligne + "\n"
    texte += "Merci de votre retour."
    if casse == "capitales":
        majuscule = texte.upper()
        if len(majuscule) != len(texte):
            raise ValueError("la mise en capitales change la longueur")
        texte = majuscule
    return texte, entites, parties


def construit(par_mots, voies, seed):
    rng = random.Random(f"{seed}-commune-voie")
    # Secondes adresses : communes d'un seul mot, sans mot de voie.
    simples = [c for c in par_mots.get(1, []) if c[2] not in voies]
    if not simples:
        raise ValueError("aucune commune d'un mot dans le referentiel")
    docs = []
    for code, dep, norm, libelle, mot in communes_a_mot_de_voie(par_mots,
                                                               voies):
        for ecriture, casse in CASES:
            for cedex in CEDEX:
                for suite in SUITES:
                    for voie in VOIE:
                        texte, entites, parties = construit_doc(
                            rng, dep, norm, libelle, simples, ecriture, casse,
                            cedex, suite, voie)
                        docs.append({
                            "id": len(docs), "text": texte,
                            "entities": entites, "parties": parties,
                            "com": code, "mot_de_voie": mot,
                            "ecriture": ecriture, "casse": casse,
                            "cedex": cedex, "suite": suite, "voie": voie})
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--communes", required=True)
    p.add_argument("--detecteur", required=True,
                   help="chemin de adresse_detector.dart (liste _voies)")
    p.add_argument("--out", default="corpus_commune_voie.jsonl")
    a = p.parse_args()
    docs = construit(gc.lit_communes(a.communes), lit_voies(a.detecteur),
                     a.seed)
    if not docs:
        raise SystemExit("aucune commune a mot de voie : balayage vide")
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    communes = len({d["com"] for d in docs})
    print(f"{a.out} : {len(docs)} documents, {communes} communes")


if __name__ == "__main__":
    main()
