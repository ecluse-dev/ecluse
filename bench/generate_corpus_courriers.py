#!/usr/bin/env python3
"""Corpus de COURRIERS synthetiques en capitales (P2-210, mesure).

Le temoin de P2-200 (`generate_corpus_neutre_cedex.py`) est un pire cas
construit : une phrase par forme, toutes « cinq chiffres + mot neutre + CEDEX
n » (113 / 200 masquees en trop depuis P2-201). Il ne dit pas **a quelle
frequence** cette forme apparait dans un courrier. Ce corpus pose la question
sur des courriers entiers, tout en capitales (la branche ou P2-201 a leve la
regle du mot neutre devant CEDEX) : en-tetes, references, montants, nombres de
dossiers, adresses de retour avec CEDEX.

**Motif de construction** (ce que le corpus suppose, sans l'avoir observe) :
un courrier a un titre, une ligne de reference, puis 5 a 9 lignes tirees au
sort, a ces poids (`FAMILLES`) :

| famille | poids | forme | annotee |
|---|---:|---|---|
| `reference` | 20 | « REFERENCE : 70123 », « LOT 39100 » | non |
| `montant` | 22 | « TOTAL : 70000 EUROS HT » | non |
| `quantite` | 18 | « 21000 DOSSIERS TRAITES » | non |
| `texte` | 20 | phrase en capitales, sans chiffre | non |
| `adresse` | 15 | « ADRESSE DE RETOUR : 25000 BESANCON CEDEX 2 » | oui |
| `montant_adresse` | 5 | « TOTAL 70000 EUROS HT, RETOUR A 25000 BESANCON CEDEX 2 » (virgule une fois sur deux) | l'adresse seule |

La derniere famille est la seule ou un nombre suivi d'un mot neutre et un
CEDEX se trouvent sur la meme ligne : c'est la forme que P2-201 a rendue
risquee. Son poids (5 %) est **une hypothese**, pas une mesure ; les autres
familles disent le bruit de fond (nombres a cinq chiffres sans CEDEX, que la
regle du mot neutre protege depuis P2-122). Chaque courrier a au moins une
ligne `adresse`. Les communes viennent du referentiel public versionne ; codes
postaux, montants et references sont fabriques. Aucun nom de personne.

Chaque document porte `lignes` : pour chaque ligne, sa `famille` et ses
positions (`debut`, `fin`) dans le texte, afin de dire **quelle** ligne est
masquee en trop. `entities` : les adresses annotees (du code postal au numero
de CEDEX).

Usage :
    python3 generate_corpus_courriers.py --n 400 --seed 42 \\
        --communes ../packages/ecluse_reference/assets/geo_communes.csv.gz \\
        --out flou/corpus_courriers.jsonl
"""

import argparse
import json
import random

import generate_corpus_cedex as gc

FAMILLES = (("reference", 20), ("montant", 22), ("quantite", 18),
            ("texte", 20), ("adresse", 15), ("montant_adresse", 5))
TITRES = ["FACTURE", "RELANCE DE PAIEMENT", "BON DE COMMANDE",
          "ATTESTATION DE SERVICE FAIT", "AVIS DE VIREMENT",
          "COMPTE RENDU D ACTIVITE"]
NEUTRES = ["EUROS", "EURO", "DOSSIERS", "PLACES", "PERSONNES", "HABITANTS",
           "LITS", "JOURS", "HEURES", "APPELS", "ACTES", "AGENTS", "PATIENTS",
           "NUMEROS"]
MONNAIE = ["EUROS", "EURO"]
TAXES = ["HT", "TTC"]
REFERENCES = ["REFERENCE : {n}", "LOT {n}", "N {n} DU DOSSIER",
              "NUMERO DE COMMANDE : {n}"]
MONTANTS = ["TOTAL : {n} {m} {t}", "MONTANT {n} {m} {t}",
            "REMISE : {n} {m} {t}"]
QUANTITES = ["{n} {w} TRAITES", "{n} {w} EN ATTENTE", "SOIT {n} {w} AU TOTAL"]
TEXTES = ["MERCI DE VOTRE RETOUR.", "VOIR LA NOTE JOINTE.",
          "PAIEMENT SOUS TRENTE JOURS.", "LE SERVICE RESTE A VOTRE DISPOSITION.",
          "CE DOCUMENT NE VAUT PAS RECU.", "SERVICE DES ADMISSIONS",
          "BATIMENT B, SECTEUR NORD", "A L ATTENTION DU SERVICE COURRIER",
          "DOSSIER EN COURS DE TRAITEMENT."]
RETOURS = ["ADRESSE DE RETOUR : ", "A RETOURNER A : ", "COURRIER A ENVOYER A : ",
           "SIEGE : "]


def nombre(rng):
    return str(rng.randrange(10_000, 99_999))


def adresse(rng, communes):
    dep, norm = communes[rng.randrange(len(communes))]
    cp = gc.code_postal(rng, dep)
    return f"{cp} {norm} CEDEX {rng.randrange(1, 10)}"


def ligne(rng, famille, communes):
    """Rend (texte, positions relatives de l'adresse annotee ou None)."""
    if famille == "reference":
        return rng.choice(REFERENCES).format(n=nombre(rng)), None
    if famille == "montant":
        return rng.choice(MONTANTS).format(
            n=nombre(rng), m=rng.choice(MONNAIE), t=rng.choice(TAXES)), None
    if famille == "quantite":
        return rng.choice(QUANTITES).format(
            n=nombre(rng), w=rng.choice(NEUTRES)), None
    if famille == "texte":
        return rng.choice(TEXTES), None
    adr = adresse(rng, communes)
    if famille == "adresse":
        avant = rng.choice(RETOURS)
    else:
        avant = (rng.choice(MONTANTS).format(
            n=nombre(rng), m=rng.choice(MONNAIE), t=rng.choice(TAXES))
            + rng.choice([", RETOUR A ", " RETOUR A "]))
    return avant + adr, (len(avant), len(avant) + len(adr))


def courrier(rng, communes, i):
    familles = [f for f, _ in FAMILLES]
    poids = [p for _, p in FAMILLES]
    choix = ["adresse"] + rng.choices(familles, poids, k=rng.randrange(5, 10))
    rng.shuffle(choix)
    texte = rng.choice(TITRES) + "\n"
    lignes, entites = [], []
    ref = "REFERENCE : " + nombre(rng)
    texte += ref + "\n"
    for fam in choix:
        t, adr = ligne(rng, fam, communes)
        debut = len(texte)
        texte += t + "\n"
        lignes.append({"famille": fam, "debut": debut, "fin": debut + len(t)})
        if adr:
            entites.append({"type": "adresse", "start": debut + adr[0],
                            "end": debut + adr[1]})
    texte += "MERCI DE VOTRE RETOUR."
    return {"id": i, "text": texte, "entities": entites, "lignes": lignes,
            "casse": "capitales"}


def charge(chemin):
    par_mots = gc.lit_communes(chemin)
    return [(dep, norm) for liste in par_mots.values()
            for _, dep, norm, _ in liste]


def construit(n, seed, communes):
    rng = random.Random(f"{seed}-courriers")
    return [courrier(rng, communes, i) for i in range(n)]


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=400)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--communes", required=True)
    p.add_argument("--out", default="corpus_courriers.jsonl")
    a = p.parse_args()
    docs = construit(a.n, a.seed, charge(a.communes))
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    adresses = sum(len(d["entities"]) for d in docs)
    print(f"{a.out} : {len(docs)} courriers, {adresses} adresses annotees")


if __name__ == "__main__":
    main()
