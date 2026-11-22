#!/usr/bin/env python3
"""Mesure préalable de P2-250 : que vaut le référentiel de patronymes de l'INSEE
pour les deux usages décidés le 21 novembre ? Mesure seule, aucune correction.

Deux questions, chiffrées sur le fichier versionné
`packages/ecluse_reference/assets/patronymes_effectifs.tsv.gz` (noms attribués au
moins 30 fois, naissances de 1891 à 2000) :

1. **Couverture** : parmi les patronymes annotés (« nom ») des corpus du dépôt,
   quelle part est absente du référentiel ? C'est la fuite que la règle de forme
   de P2-241 (« jamais étendre un prénom sur un mot en minuscule, sauf mot du
   référentiel ») rendrait en clair, par seuil d'effectif.
2. **Contamination** : parmi les verbes des sondes de P2-240
   (`generate_corpus_prenom_verbe.py`, familles `courants`, `reserve`, `reserve2`),
   combien figurent au référentiel, et avec quel effectif ? Ce sont les verbes que
   la règle laisserait étendre (donc masquer) derrière un prénom ; un seuil
   d'effectif les écarte. La liste fermée de `verbes_conjugues.dart` est comptée à
   part : ses formes sont déjà écartées avant la règle.

Le patronyme d'une mention est son dernier mot, civilité et particule retirées ;
un nom composé est compté par parties.
Ne mesure aucun détecteur : le chemin `Ecluse.redact` n'est pas lancé ici. N'imprime que des
comptes et des mots de listes du dépôt (jamais le texte d'un document).

Usage : python3 bench/mesure_patronymes_referentiel.py
"""

import glob
import gzip
import json
import os
import re
import sys
import unicodedata

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(ICI)
ASSET = os.path.join(RACINE, "packages", "ecluse_reference", "assets",
                     "patronymes_effectifs.tsv.gz")
SEUILS = (30, 100, 300, 1000, 3000)
CIVILITES = {"M", "MME", "MLLE", "MONSIEUR", "MADAME", "MADEMOISELLE", "DR",
             "DOCTEUR", "PR", "PROFESSEUR", "ME", "MAITRE"}
PARTICULES = {"DE", "DU", "DES", "LA", "LE", "D"}


def norm(mot):
    """Capitales sans accents, comme `normName` du paquet de référence."""
    s = unicodedata.normalize("NFD", mot.upper())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def charge_referentiel(chemin=ASSET):
    ref = {}
    with gzip.open(chemin, "rt", encoding="utf-8") as f:
        for ligne in f:
            if ligne.startswith("#") or not ligne.strip():
                continue
            nom, eff = ligne.rstrip("\n").split("\t")
            ref[nom] = int(eff)
    return ref


def patronyme(valeur):
    """Dernier mot du nom, civilité et particules exclues ; None s'il n'y en a pas."""
    mots = [norm(m) for m in re.findall(r"[^\W\d_][\w'’-]*", valeur)]
    mots = [m for m in mots if m not in CIVILITES]
    while mots and mots[0] in PARTICULES:
        mots = mots[1:]
    return mots[-1] if len(mots) >= 1 else None


def couverture(corpus, ref):
    """{seuil: absents} et nombre de patronymes distincts du corpus."""
    noms = set()
    for chemin in corpus:
        with open(chemin, encoding="utf-8") as f:
            for ligne in f:
                d = json.loads(ligne)
                for e in d["entities"]:
                    if e["type"] == "nom":
                        p = patronyme(d["text"][e["start"]:e["end"]])
                        if p and len(p) > 1:
                            # nom composé (« Aubry-Perrot ») : chaque partie
                            # compte séparément ; la règle lit un mot à la fois
                            noms.update(x for x in p.split("-") if len(x) > 1)
    return noms, {s: sorted(n for n in noms if ref.get(n, 0) < s) for s in SEUILS}


def mots_dart(chemin, debut):
    """Mots entre guillemets simples du bloc de constantes qui suit `debut`."""
    with open(chemin, encoding="utf-8") as f:
        src = f.read()
    i = src.index(debut)
    j = src.index("};", i)
    return sorted(set(re.findall(r"'([^'\s]+)'", src[i:j])))


def contamination(mots, ref):
    return {s: sorted((m for m in mots if ref.get(norm(m), 0) >= s),
                      key=lambda m: -ref[norm(m)]) for s in SEUILS}


def verbes_sondes():
    """Verbes des trois familles de la sonde prénom + verbe, par famille."""
    sys_path = sys.path
    sys.path.insert(0, ICI)
    try:
        import generate_corpus_prenom_verbe as g
    finally:
        sys.path[:] = sys_path
    return {nom: sorted(set(m.lower() for m in liste))
            for nom, liste in g.FAMILLES.items()}


def main():
    ref = charge_referentiel()
    print(f"référentiel : {len(ref)} noms, effectif minimal "
          f"{min(ref.values())}, maximal {max(ref.values())}")
    corpus = sorted(glob.glob(os.path.join(ICI, "flou", "corpus_flou_*.jsonl"))
                    + glob.glob(os.path.join(ICI, "dossiers", "corpus_dossiers_*.jsonl"))
                    + [os.path.join(ICI, "corpus.jsonl")])
    noms, absents = couverture(corpus, ref)
    print(f"\n1. couverture : {len(noms)} patronymes distincts annotés "
          f"dans {len(corpus)} corpus")
    for s in SEUILS:
        print(f"  seuil {s:>5} : {len(absents[s]):>4} absents du référentiel "
              f"({100.0 * len(absents[s]) / len(noms):.1f} %)")
    print("  absents au seuil 30 : " + (", ".join(absents[30]) or "aucun"))
    verbes = mots_dart(os.path.join(RACINE, "packages", "ecluse_redact", "lib",
                                    "src", "heuristics", "verbes_conjugues.dart"),
                       "const Set<String> verbesConjuguesCourants = {")
    print(f"\n2. contamination : {len(verbes)} verbes conjugués de la liste fermée")
    c = contamination(verbes, ref)
    for s in SEUILS:
        print(f"  seuil {s:>5} : {len(c[s]):>3} verbes au référentiel"
              + (" : " + ", ".join(f"{m} ({ref[norm(m)]})" for m in c[s][:12])
                 if c[s] else ""))
    print("\n3. verbes des sondes de P2-240 présents au référentiel")
    for famille, liste in verbes_sondes().items():
        c = contamination(liste, ref)
        print(f"  {famille} ({len(liste)} verbes) : " + ", ".join(
            f"seuil {s} : {len(c[s])}" for s in SEUILS))
        print("    au seuil 30 : " + (", ".join(
            f"{m} ({ref[norm(m)]})" for m in c[30]) or "aucun"))


if __name__ == "__main__":
    main()
