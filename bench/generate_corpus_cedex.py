#!/usr/bin/env python3
"""Corpus « CEDEX apres une commune longue » (P2-178, mesure).

Apres P2-164, « 70000 VESOUL CEDEX 9 » est masque en entier. Reste note dans
`LIMITES.md` : le CEDEX d'une commune de plus de quatre mots. Ce corpus le
chiffre : des adresses synthetiques dont la commune est tiree de
`geo_communes.csv.gz` (noms de lieux du referentiel public, pas des donnees
personnelles), a nombre de mots croissant.

Axes de chaque document :

- `mots` : nombre de mots du nom de la commune, compte sur sa forme postale
  (colonne NORM : capitales, sans accent, espaces a la place des tirets et
  des apostrophes ; « L ABERGEMENT DE VAREY » = 4 mots) ;
- `ecriture` : `postale` (NORM tel quel), `libelle` (libelle officiel, casse
  de titre, tirets), `libelle_espaces` (le meme, tirets remplaces par des
  espaces), `capitales_tirets` (libelle en capitales) ;
- `cedex` : `sans` (controle : seul l'effet de la longueur), `CEDEX n`,
  `Cedex 0n` ;
- `voie` : `avec` (numero et voie devant le code postal, sur la meme ligne) ou
  `sans` (code postal en tete de ligne).

Une adresse annotee par document (`type: adresse`, de la voie ou du code
postal jusqu'au numero de CEDEX), le code INSEE de la commune (`com`, pour
compter les communes distinctes) et ses parties (`parties` : commune, mot
CEDEX, numero) pour dire **ce qui** reste en clair. Le code postal est
fabrique (departement + chiffres tires) : ce n'est pas celui de la commune.
Voies, numeros et CEDEX synthetiques. Graine fixe.

Deux tirages :

- par defaut, `--par-longueur N` communes par nombre de mots (toutes si la
  longueur en compte moins), chacune sous les 24 combinaisons d'axes : dit
  l'effet de la longueur ;
- `--balayage` : **toutes** les communes du referentiel, une fois par
  ecriture, avec « CEDEX n » et sans voie : dit combien de communes sont
  touchees.

Usage :
    python3 generate_corpus_cedex.py --par-longueur 40 --seed 42 \\
        --communes ../packages/ecluse_reference/assets/geo_communes.csv.gz \\
        --out flou/corpus_cedex.jsonl
    python3 generate_corpus_cedex.py --balayage --seed 42 \\
        --communes ... --out flou/corpus_cedex_balayage.jsonl
"""

import argparse
import collections
import gzip
import json
import random

VOIES = ["12 rue des Lilas", "7 impasse des Charmilles", "3 route de Lyon",
         "45 avenue de la Gare", "8 chemin des Vignes", "21 place du Marché"]
ECRITURES = ("postale", "libelle", "libelle_espaces", "capitales_tirets")
CEDEX = ("sans", "CEDEX n", "Cedex 0n")
AVEC_VOIE = ("avec", "sans")


def lit_communes(chemin):
    """Rend {nombre de mots: [(code, dep, norm, libelle), ...]}, dans l'ordre
    du fichier."""
    par_mots = collections.defaultdict(list)
    with gzip.open(chemin, "rt", encoding="utf-8") as f:
        next(f)  # en-tete COM;DEP;REG;PMUN;NORM;LIBELLE
        for ligne in f:
            champs = ligne.rstrip("\n").split(";")
            if len(champs) < 6 or not champs[4]:
                continue
            par_mots[len(champs[4].split())].append(
                (champs[0], champs[1], champs[4], champs[5]))
    return par_mots


def ecrit(norm, libelle, ecriture):
    if ecriture == "postale":
        return norm
    if ecriture == "libelle":
        return libelle
    if ecriture == "libelle_espaces":
        return libelle.replace("-", " ")
    return libelle.upper()


def code_postal(rng, dep):
    """Code postal fabrique a partir du departement (pas celui de la commune)."""
    prefixe = "20" if dep in ("2A", "2B") else dep
    return prefixe + "".join(rng.choice("0123456789")
                             for _ in range(5 - len(prefixe)))


def construit_doc(rng, dep, norm, libelle, ecriture, cedex, voie):
    commune = ecrit(norm, libelle, ecriture)
    cp = code_postal(rng, dep)
    if voie == "avec":
        avant = "Adresse : "
        tete = f"{rng.choice(VOIES)}, {cp} "
    else:
        avant = "Courrier à adresser à :\n"
        tete = f"{cp} "
    debut = len(avant)
    texte = avant + tete
    parties = {"commune": [len(texte), len(texte) + len(commune)]}
    texte += commune
    if cedex == "sans":
        parties["cedex"] = None
        parties["numero"] = None
    else:
        mot = "CEDEX" if cedex == "CEDEX n" else "Cedex"
        numero = (str(rng.randrange(1, 10)) if cedex == "CEDEX n"
                  else f"0{rng.randrange(1, 10)}")
        texte += " "
        parties["cedex"] = [len(texte), len(texte) + len(mot)]
        texte += mot + " "
        parties["numero"] = [len(texte), len(texte) + len(numero)]
        texte += numero
    fin = len(texte)
    texte += "\nMerci de votre retour."
    return texte, debut, fin, parties


def construit(par_mots, par_longueur, seed, balayage=False):
    rng = random.Random(f"{seed}-cedex{'-balayage' if balayage else ''}")
    docs = []
    for mots in sorted(par_mots):
        communes = par_mots[mots]
        tirage = (list(communes)
                  if balayage or len(communes) <= par_longueur
                  else rng.sample(communes, par_longueur))
        for code, dep, norm, libelle in tirage:
            for ecriture in ECRITURES:
                for cedex in (("CEDEX n",) if balayage else CEDEX):
                    for voie in (("sans",) if balayage else AVEC_VOIE):
                        texte, debut, fin, parties = construit_doc(
                            rng, dep, norm, libelle, ecriture, cedex, voie)
                        docs.append({
                            "id": len(docs), "text": texte,
                            "entities": [{"type": "adresse", "start": debut,
                                          "end": fin}],
                            "parties": parties, "com": code, "mots": mots,
                            "ecriture": ecriture, "cedex": cedex,
                            "voie": voie})
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--par-longueur", type=int, default=40)
    p.add_argument("--balayage", action="store_true")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--communes", required=True)
    p.add_argument("--out", default="corpus_cedex.jsonl")
    a = p.parse_args()
    docs = construit(lit_communes(a.communes), a.par_longueur, a.seed,
                     a.balayage)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{a.out} : {len(docs)} documents, {len(docs)} adresses annotees")


if __name__ == "__main__":
    main()
