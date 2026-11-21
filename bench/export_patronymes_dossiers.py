#!/usr/bin/env python3
"""Listes de patronymes fournies à `Dossier(patronymesConnus:)` (P2-243).

Protocole de la § 7 de `agent/specs/P2-219.md`. Tout est synthétique : les
patronymes viennent des listes du générateur (`generate_corpus_dossiers.py`),
les noms de remplissage sont tirés au hasard par syllabes (graine 42) ; jamais
un document ni une liste réels (règle 1 de `CLAUDE.md`).

Trois fichiers JSON dans `--out-dir`, lus par `run_dossiers_bench.dart
--patronymes=…` :

- `patronymes_exacte.json` : pour chaque dossier, les patronymes de ses
  personnes, rien d'autre (« liste exacte ») ;
- `patronymes_large.json` : pour tous les dossiers, les patronymes de toutes
  les personnes du corpus, les patronymes ambigus du générateur (« Petit »,
  « Boulanger »…) et 10 000 noms tirés au hasard (« liste large ») ;
- `patronymes_sans.json` : la liste large privée, pour chaque dossier, des
  patronymes de **ses** personnes (« liste sans la bonne personne »).

Format : `{"commun": [...], "par_dossier": {"<id>": {"ajoute": [...],
"retire": [...]}}}`. N'imprime que des comptes, jamais un nom.

Usage : python3 export_patronymes_dossiers.py --corpus c.jsonl --out-dir d/
"""

import argparse
import json
import os
import random

from generate_corpus_dossiers import TOUS_NOMS
from generate_corpus_flou import NOMS_AMBIGUS

SYLLABES = ["ba", "be", "bo", "ca", "ce", "co", "da", "de", "do", "fa", "fe",
            "fo", "ga", "ge", "go", "ha", "he", "ho", "ja", "je", "jo", "ka",
            "ke", "ko", "la", "le", "lo", "ma", "me", "mo", "na", "ne", "no",
            "pa", "pe", "po", "ra", "re", "ro", "sa", "se", "so", "ta", "te",
            "to", "va", "ve", "vo", "za", "ze", "zo", "bran", "dor", "gal",
            "mer", "nel", "tor", "val", "vin"]


def noms_aleatoires(n, graine):
    """n noms distincts de trois syllabes, tirés avec la graine donnée.
    Des collisions avec des mots du français sont possibles et non cherchées."""
    rng = random.Random(graine)
    noms = set()
    while len(noms) < n:
        noms.add("".join(rng.choice(SYLLABES) for _ in range(3)).capitalize())
    return sorted(noms)


def personnes_par_dossier(chemin):
    """Dossier -> patronymes de ses personnes (dernier mot d'une mention de nom,
    retenu s'il est un patronyme du générateur)."""
    res = {}
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            if not ligne.strip():
                continue
            doc = json.loads(ligne)
            for e in doc["entities"]:
                if e["type"] != "nom":
                    continue
                mot = doc["text"][e["start"]:e["end"]].split()[-1]
                if mot in TOUS_NOMS or mot in NOMS_AMBIGUS:
                    res.setdefault(str(doc["dossier"]), set()).add(mot)
    return {k: sorted(v) for k, v in res.items()}


def leurres_isoles(chemin, sortie, out_dir, large):
    """Corpus de leurres (documents sans personne) dont chaque document est son
    propre dossier : aucun ancrage par une pièce précédente, donc ce qui est
    masqué l'est par la liste seule. La liste de chaque document porte le
    patronyme du dossier d'origine (« Petit »…), qui y est aussi un mot courant.
    Écrit le corpus dans `sortie` et les trois jeux de listes dans `out_dir`."""
    noms = personnes_par_dossier(chemin)
    docs = [json.loads(l) for l in open(chemin, encoding="utf-8") if l.strip()]
    isoles, exacte, sans = [], {}, {}
    for d in docs:
        if d["entities"]:
            continue
        cle = f"l{d['id']}"
        isoles.append({"id": d["id"], "text": d["text"], "entities": [],
                       "dossier": cle})
        exacte[cle] = {"ajoute": noms.get(str(d["dossier"]), []), "retire": []}
        sans[cle] = {"ajoute": [], "retire": noms.get(str(d["dossier"]), [])}
    with open(sortie, "w", encoding="utf-8") as f:
        for d in isoles:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    os.makedirs(out_dir, exist_ok=True)
    for nom, jeu in {
        "exacte": {"commun": [], "par_dossier": exacte},
        "large": {"commun": large, "par_dossier": {}},
        "sans": {"commun": large, "par_dossier": sans},
    }.items():
        with open(os.path.join(out_dir, f"patronymes_{nom}.json"), "w",
                  encoding="utf-8") as f:
            json.dump(jeu, f, ensure_ascii=False)
    print(f"leurres isolés : {len(isoles)} documents, un dossier chacun")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--graine", type=int, default=42)
    ap.add_argument("--extra", type=int, default=10000)
    ap.add_argument("--leurres-isoles", metavar="CORPUS_SORTIE",
                    help="écrit aussi le corpus de leurres, un dossier par "
                         "document, et ses listes dans <out-dir>/isoles")
    a = ap.parse_args()
    pers = personnes_par_dossier(a.corpus)
    toutes = sorted({n for v in pers.values() for n in v})
    large = sorted(set(toutes) | set(NOMS_AMBIGUS)
                   | set(noms_aleatoires(a.extra, a.graine)))
    jeux = {
        "exacte": {"commun": [],
                   "par_dossier": {k: {"ajoute": v, "retire": []}
                                   for k, v in pers.items()}},
        "large": {"commun": large, "par_dossier": {}},
        "sans": {"commun": large,
                 "par_dossier": {k: {"ajoute": [], "retire": v}
                                 for k, v in pers.items()}},
    }
    os.makedirs(a.out_dir, exist_ok=True)
    for nom, jeu in jeux.items():
        with open(os.path.join(a.out_dir, f"patronymes_{nom}.json"), "w",
                  encoding="utf-8") as f:
            json.dump(jeu, f, ensure_ascii=False)
    if a.leurres_isoles:
        leurres_isoles(a.corpus, a.leurres_isoles,
                       os.path.join(a.out_dir, "isoles"), large)
    print(f"patronymes : {len(pers)} dossiers, {len(toutes)} patronymes de "
          f"personnes, liste large {len(large)} noms distincts")


if __name__ == "__main__":
    main()
