#!/usr/bin/env python3
"""Corpus TEMOIN « mots-nombres » (P2-160, `agent/specs/P2-155.md` § 5).

Des phrases francaises ordinaires, denses en nombres ecrits en lettres, qui
ne sont **pas** des identifiants : montants, dates, quantites, consignes.
Aucune entite n'est annotee (`"entities": []`) : toute prediction sur ce
corpus est un faux positif. Il sert de garde-fou a la future normalisation
« mots -> chiffres » de la vue de detection : une seule detection a tort
bloque le GO de cette tache. Aujourd'hui aucun detecteur ne lit de nombre en
lettres, le compte attendu est donc 0 ; le corpus existe pour que ce 0 reste
vrai apres la correction.

Moitie des phrases (la premiere, par construction) contiennent au moins 6
mots-nombres consecutifs, le seuil K de la spec ; l'autre moitie en contient
moins. Donnees entierement synthetiques, graine fixe, aucune valeur reelle.

Usage :
    python3 generate_corpus_mots_nombres.py --n 300 --seed 42 \\
        --out transcrit/corpus_temoin_mots_nombres.jsonl
"""

import argparse
import json
import random
import re

from generate_corpus_transcrit import UNITES, nombre

# Mots lus comme des nombres (hors « et », traite a part dans le decompte).
MOTS_NOMBRES = frozenset(UNITES) | {
    "vingt", "vingts", "trente", "quarante", "cinquante", "soixante",
    "cent", "cents", "mille", "million", "millions", "premier"}
JETON = re.compile(r"[^\W\d_]+", re.UNICODE)

SEUIL_K = 6


def grand_nombre(n):
    """0 a 999 999, avec « mille » (orthographe traditionnelle)."""
    assert 0 <= n < 1_000_000
    milliers, reste = divmod(n, 1000)
    if milliers == 0:
        return nombre(reste)
    tete = "mille" if milliers == 1 else nombre(milliers) + " mille"
    return tete if reste == 0 else tete + " " + nombre(reste)


def plus_longue_suite(texte):
    """Plus longue suite de mots-nombres consecutifs (« et » compte quand il
    relie deux mots-nombres ; un trait d'union separe deux mots)."""
    jetons = JETON.findall(texte.lower())
    meilleure = courante = 0
    for i, j in enumerate(jetons):
        suivant = jetons[i + 1] if i + 1 < len(jetons) else ""
        if j in MOTS_NOMBRES or (j == "et" and courante
                                 and suivant in MOTS_NOMBRES):
            courante += 1
            meilleure = max(meilleure, courante)
        else:
            courante = 0
    return meilleure


OBJETS = ["boîtes", "chaises", "tables", "lits", "plateaux", "serviettes",
          "classeurs", "ampoules", "palettes", "colis"]
MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "août", "septembre", "octobre", "novembre", "décembre"]
LIEUX = ["l'atelier", "le hangar", "la salle commune", "le local technique",
         "le magasin", "la cuisine"]


def montant(rng, long):
    n = rng.randrange(100_000, 999_999) if long else rng.randrange(2, 99)
    unite = rng.choice(["euros", "euros par an", "euros de charges"])
    return rng.choice([
        f"Le devis s'élève à {grand_nombre(n)} {unite}.",
        f"Le budget voté est de {grand_nombre(n)} {unite}.",
        f"Prévoir {grand_nombre(n)} {unite} pour les travaux.",
    ])


def quantite(rng, long):
    n = rng.randrange(100_000, 999_999) if long else rng.randrange(2, 20)
    objet = rng.choice(OBJETS)
    return rng.choice([
        f"Le stock compte {grand_nombre(n)} {objet} dans {rng.choice(LIEUX)}.",
        f"La livraison comprend {grand_nombre(n)} {objet}.",
        f"On a recensé {grand_nombre(n)} {objet} à l'inventaire.",
    ])


def date_en_lettres(rng, long):
    jour = rng.randrange(1, 29)
    annee = rng.randrange(2000, 2099)
    mois = rng.choice(MOIS)
    j = "premier" if jour == 1 else nombre(jour)
    if long:
        n = rng.randrange(100_000, 999_999)
        return (f"La réunion du {j} {mois} {grand_nombre(annee)} a rassemblé "
                f"{grand_nombre(n)} participants.")
    return f"La réunion aura lieu le {j} {mois}."


def consigne(rng, long):
    if long:
        debut = rng.randrange(1, 6)
        suite = ", ".join(UNITES[debut:debut + 8])
        return rng.choice([
            f"Comptez à voix haute : {suite}.",
            f"Pour s'endormir, répétez lentement {suite}.",
            f"L'exercice consiste à énumérer {suite} sans se tromper.",
        ])
    a, b = rng.randrange(2, 16), rng.randrange(2, 10)
    return rng.choice([
        f"Comptez {UNITES[a]}, répétez {UNITES[b]} fois.",
        f"Tournez {UNITES[b]} fois, attendez {UNITES[a]} minutes.",
        f"Appuyez {UNITES[b]} secondes, puis comptez jusqu'à {UNITES[a]}.",
    ])


GENERATEURS = (montant, quantite, date_en_lettres, consigne)


def phrase(rng, long):
    """Une phrase de la categorie tiree, jusqu'a respecter le seuil K (ou, pour
    la moitie courte, rester en dessous)."""
    for _ in range(200):
        t = rng.choice(GENERATEURS)(rng, long)
        if (plus_longue_suite(t) >= SEUIL_K) == long:
            return t
    raise RuntimeError("phrase introuvable : generateur mal regle")


def construit(n, seed):
    rng = random.Random(f"{seed}-mots-nombres")
    docs = []
    for i in range(n):
        long = i < (n + 1) // 2
        docs.append({"id": i, "text": phrase(rng, long), "entities": []})
    rng.shuffle(docs)
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--n", type=int, default=300)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="corpus_temoin_mots_nombres.jsonl")
    a = p.parse_args()
    if a.n < 300:
        raise SystemExit("la spec demande au moins 300 phrases")
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    longues = sum(plus_longue_suite(d["text"]) >= SEUIL_K for d in docs)
    print(f"{a.out} : {len(docs)} phrases, dont {longues} avec au moins "
          f"{SEUIL_K} mots-nombres consecutifs, 0 entite annotee")


if __name__ == "__main__":
    main()
