#!/usr/bin/env python3
"""Corpus TEMOIN « cinq chiffres + mot neutre + CEDEX » (P2-200).

Des phrases ordinaires ou un nombre de cinq chiffres, un mot neutre (monnaie,
unite, nom de comptage : « EUROS », « DOSSIERS », « PLACES »), parfois une
parenthese ou un tiret isole, puis « CEDEX n » se suivent : « Virement de 70000
EUROS CEDEX 3 ». Aucune entite n'est annotee (`"entities": []`) : toute adresse
predite est un faux positif, donc un masquage en trop.

Raison d'etre : la regle du mot neutre (`_communeNeutre`, P2-122) ecarte
« 70000 EUROS » en capitales ; P2-201 voudrait la lever **devant CEDEX**, pour
des communes comme « VERS » ou « SOUS PARSAT ». Ce temoin chiffre, avant toute
correction, ce que cette levee coute en masquages a tort. Rare dans de vrais
textes, d'ou un temoin construit : le chiffre dit le pire cas, pas une
frequence.

Axes (champs lus par `run_cinq_chiffres_bench.dart`) : `famille` (quantite,
reference), `suffixe` (la forme de ce qui suit le mot neutre : `mot`,
`parenthese`, `tiret`), `position` (le nombre ouvre la phrase ou vient apres
des mots) et `casse` (`capitales` : tout le texte en capitales ; `ordinaire` :
casse ordinaire, mot neutre en minuscules).

Mots neutres : vocabulaire courant de monnaie, d'unites et de comptage, tire
des familles de `mots_neutres.dart` (liste recopiee ici, a tenir a jour a la
main : un mot absent de la liste du detecteur ne mesure rien). Donnees entierement synthetiques, graine fixe, aucune valeur
reelle.

Usage :
    python3 generate_corpus_neutre_cedex.py --n 400 --seed 42 \\
        --out flou/corpus_flou_neutre_cedex.jsonl
"""

import argparse
import json
import random

MOTS_NEUTRES = [
    "euros", "euro", "dossiers", "places", "personnes", "habitants", "lits",
    "jours", "heures", "appels", "actes", "agents", "patients", "numéros",
]
COMPLEMENTS = {
    "mot": "",
    "parenthese": " (TTC)",
    "tiret": " - HT",
}
QUANTITE = ["Virement de {n} {mot}{c} CEDEX {k}",
            "Total de {n} {mot}{c} CEDEX {k}",
            "Commande de {n} {mot}{c} CEDEX {k}"]
REFERENCE = ["Ref. {n} {mot}{c} CEDEX {k}",
             "Lot {n} {mot}{c} CEDEX {k}",
             "Dossier {n} {mot}{c} CEDEX {k}"]
FAMILLES = {"quantite": QUANTITE, "reference": REFERENCE}
SUITES = ["Merci de votre retour.", "Voir la note jointe."]


def construit_phrase(rng, famille, suffixe, position, casse):
    n = str(rng.randrange(10_000, 99_999))
    mot = rng.choice(MOTS_NEUTRES)
    k = str(rng.randrange(1, 10))
    c = COMPLEMENTS[suffixe]
    if position == "debut":
        texte = f"{n} {mot}{c} CEDEX {k}"
    else:
        texte = rng.choice(FAMILLES[famille]).format(n=n, mot=mot, c=c, k=k)
    texte += "."
    if casse == "capitales":
        return texte.upper()
    return f"{texte} {rng.choice(SUITES)}"


def construit(n, seed):
    rng = random.Random(f"{seed}-neutre-cedex")
    axes = [(f, s, p, c)
            for f in FAMILLES
            for s in COMPLEMENTS
            for p in ("debut", "milieu")
            for c in ("capitales", "ordinaire")]
    docs = []
    for i in range(n):
        f, s, p, c = axes[i % len(axes)]
        docs.append({
            "id": i, "text": construit_phrase(rng, f, s, p, c),
            "entities": [], "famille": f, "suffixe": s, "position": p,
            "casse": c})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=400)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_flou_neutre_cedex.jsonl")
    a = p.parse_args()
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{a.out} : {len(docs)} phrases, 0 entite annotee")


if __name__ == "__main__":
    main()
