#!/usr/bin/env python3
"""Corpus TEMOIN « nombre a cinq chiffres + mot neutre », un mot a la fois
(P2-211, mesure).

Le corpus de courriers de P2-210 ne dit rien des mots que son generateur ne
tire pas : il a montre « NUMEROS » sans accent masque en adresse, et rien sur
« SALARIES », « RESIDENTS » ni sur le reste de la liste. Ce temoin prend **tous**
les mots de `mots_neutres.dart`, lus dans le fichier Dart lui-meme (aucune
liste recopiee a tenir a jour), et ecrit pour chacun `--n` phrases « nombre a
cinq chiffres + mot », reparties a parts egales entre ses cases :

- `forme` : `accentuee` (le mot tel qu'il est dans la liste) et, **seulement
  quand elle differe**, `sans_accent` (« numeros », « salaries », « a ») ;
- `casse` : `capitales` (toute la phrase en capitales, la branche ou la regle
  du mot neutre d'`AdresseDetector` joue) et `ordinaire` (le mot en
  minuscules).

Un mot sans accent a donc deux cases de `--n / 2` phrases, un mot accentue
quatre cases de `--n / 4`.

**Motif de construction** (ce que le corpus suppose, sans l'avoir observe).
Dans chaque case, les phrases tournent sur trois axes :

- `position` : le nombre ouvre la phrase (`debut`) ou vient apres une
  tournure de quantite ou de reference (`milieu` : « Total de », « Lot ») ;
- `suite` : ce qui suit le mot. `rien` (fin de phrase), `neutre` (« en
  attente », « par an » : des mots de la liste ou sans majuscule possible de
  commune), `nom` (un nom commun : « traites », « valides »). La suite `nom`
  est celle ou un determinant de la liste (« le », « la », « les », « l »)
  prend la forme d'un debut de commune (« 70000 LES PIECES ») : c'est le cout
  connu de P2-187, que ce temoin chiffre mot par mot sans le rouvrir ;
- `majuscules` (casse ordinaire seulement) : `phrase` (seule l'initiale de la
  phrase est en majuscule, les detecteurs de casse y recapitalisent) ou
  `mixte` (une seconde phrase porte une majuscule hors debut de phrase).

Les tournures et les suites sont ecrites **sans accent**, pour que la seule
difference entre les formes `accentuee` et `sans_accent` soit le mot lui-meme.
Aucune entite n'est annotee (`"entities": []`) : toute detection qui couvre le
nombre est un masquage en trop (de la lisibilite perdue, pas une fuite).
Nombres fabriques, aucun nom de personne ni de commune, graine fixe.

Usage :
    python3 generate_corpus_mots_neutres.py --n 400 --seed 42 \\
        --mots ../packages/ecluse_redact/lib/src/heuristics/mots_neutres.dart \\
        --out flou/corpus_flou_mots_neutres.jsonl
"""

import argparse
import json
import random
import re
import unicodedata

DEBUT_MILIEU = ["Total de {n} {mot}", "Reste {n} {mot}", "Lot {n} {mot}",
                "Soit {n} {mot}", "Compte de {n} {mot}", "Suivi : {n} {mot}"]
SUITES = {
    "rien": [""],
    "neutre": [" en attente", " par an", " au total", " ce mois-ci"],
    "nom": [" traites", " valides", " restants", " ouverts"],
}
SUITE_MIXTE = ["Voir la note du service Qualite.",
               "Rapport transmis a la Direction."]
POSITIONS = ("debut", "milieu")
MAJUSCULES = ("phrase", "mixte")

_BLOC = re.compile(r"const\s+Set<String>\s+motsNeutres\s*=\s*\{(.*?)\};", re.S)
_MOT = re.compile(r"'([^']*)'")


def lit_mots(chemin):
    """Les mots de `motsNeutres`, dans l'ordre du fichier Dart, sans doublon.
    Refuse (ValueError) un fichier ou l'ensemble est introuvable ou vide :
    jamais un temoin vide pris pour « rien a mesurer »."""
    with open(chemin, encoding="utf-8") as f:
        source = f.read()
    bloc = _BLOC.search(source)
    if bloc is None:
        raise ValueError("ensemble motsNeutres introuvable dans le fichier")
    # Les commentaires peuvent citer des mots entre guillemets francais, pas
    # entre apostrophes ; on les retire quand meme avant de lire.
    corps = re.sub(r"//[^\n]*", "", bloc.group(1))
    mots = list(dict.fromkeys(_MOT.findall(corps)))
    if not mots:
        raise ValueError("ensemble motsNeutres vide")
    return mots


def sans_accent(mot):
    """« numéros » -> « numeros ». Ne touche que les signes diacritiques."""
    decompose = unicodedata.normalize("NFD", mot)
    return "".join(c for c in decompose if unicodedata.category(c) != "Mn")


def formes(mot):
    """[(nom de forme, ecriture)] : la forme sans accent seulement si elle
    differe."""
    res = [("accentuee", mot)]
    nu = sans_accent(mot)
    if nu != mot:
        res.append(("sans_accent", nu))
    return res


def construit_phrase(rng, ecriture, casse, position, suite, majuscules):
    n = str(rng.randrange(10_000, 99_999))
    if position == "debut":
        corps = f"{n} {ecriture}"
    else:
        corps = rng.choice(DEBUT_MILIEU).format(n=n, mot=ecriture)
    texte = corps + rng.choice(SUITES[suite]) + "."
    if casse == "capitales":
        return texte.upper()
    if majuscules == "mixte":
        texte = f"{texte} {rng.choice(SUITE_MIXTE)}"
    return texte


def construit(mots, n, seed):
    """`n` phrases par mot, a parts egales entre ses cases (forme x casse).
    Refuse (ValueError) un `n` qui ne se partage pas en quatre."""
    if n <= 0 or n % 4:
        raise ValueError("--n doit etre un multiple de 4 strictement positif")
    rng = random.Random(f"{seed}-mots-neutres")
    docs = []
    for mot in mots:
        fs = formes(mot)
        par_case = n // (len(fs) * 2)
        for forme, ecriture in fs:
            for casse in ("capitales", "ordinaire"):
                axes = [(p, s, m) for p in POSITIONS for s in SUITES
                        for m in MAJUSCULES]
                for i in range(par_case):
                    p, s, m = axes[i % len(axes)]
                    if casse == "capitales":
                        m = "capitales"
                    docs.append({
                        "text": construit_phrase(rng, ecriture, casse, p, s, m),
                        "entities": [], "mot": mot, "forme": forme,
                        "ecriture": ecriture, "casse": casse, "position": p,
                        "suite": s, "majuscules": m})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=400,
                   help="phrases par mot de la liste")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--mots", required=True,
                   help="chemin de mots_neutres.dart")
    p.add_argument("--out", default="corpus_flou_mots_neutres.jsonl")
    a = p.parse_args()
    mots = lit_mots(a.mots)
    docs = construit(mots, a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{a.out} : {len(mots)} mots, {len(docs)} phrases, 0 entite annotee")


if __name__ == "__main__":
    main()
