#!/usr/bin/env python3
"""Regles candidates pour les communes en capitales sans « CEDEX » (P2-206).

**Mesure seulement : aucune de ces regles n'est dans `lib/`.** Elles sont
ecrites ici, comme la regle « fin de ligne » de P2-181 l'avait ete « a la
main » (non reproductible), et simulees **sur les predictions de
`Ecluse.redact`** (ce que recoit le LLM) : l'etendue masquee finale d'un
document est l'union des detections de `Ecluse.redact` et de l'etendue que la
regle candidate ajouterait. Limite assumee : un vrai detecteur modifie aussi la
facon dont ses voisins se chevauchent (`resolveOverlaps`), ce que cette union
ne rejoue pas ; les chiffres sont un ordre de grandeur du gain et du cout, pas
la mesure d'une implementation.

Regles simulees. Chacune ajoute, pour un nombre a cinq chiffres suivi d'un
nom, une etendue du code postal a la fin du nom retenu :

- `exact_prefixe` (options A.2, B.2, C.2, D.2 de la spec) : le plus long
  prefixe de la fin de la ligne qui, normalise (sans accent, sans ponctuation,
  blancs reduits), est **exactement** le nom d'une commune du referentiel
  (`geo_communes.csv.gz`, colonne `NORM`, 34 875 entrees) ;
- `exact_ligne` : meme chose, mais seulement si **toute** la fin de la ligne
  (ponctuation finale retiree) est une commune ;
- `fin_de_ligne` (option A.1, celle de P2-181) : tout jusqu'a la fin de la
  ligne **si chaque mot de la fin de ligne est a majuscule ou un mot de liaison
  courant** (`LIAISONS`), sauf si le premier mot est un mot neutre (la regle
  P2-122 reste), a un determinant pres suivi d'un mot non neutre (P2-185). La
  regle de P2-181 avait ete rejouee a la main, jamais versionnee : celle-ci en
  est une lecture, qui donne 4 808 caracteres de suite masques au temoin la ou
  P2-181 en avait compte 4 858 (ecart de 50, non explique : la regle d'origine
  n'est pas retrouvable).

Trois mesures (un sous-commande chacune) :

- `balayage` : adresses encore en partie en clair sur le balayage en capitales
  sans CEDEX, par forme de commune (A a E, voir `classe_communes_capitales.py`) ;
- `suivie` : cout sur le temoin `generate_corpus_commune_suivie.py` (caracteres
  de suite masques en trop, hors blancs ; documents a l'adresse en clair).
  `--casse libre` applique la regle a toute ligne (comme P2-181) ; `--casse
  capitales` seulement au texte sans aucune minuscule (la branche ou la regle
  vivrait) ;
- `neutre` : cout sur le temoin `generate_corpus_commune_neutre.py` (aucune
  adresse annotee) : phrases dont la regle ajouterait un masquage.

N'imprime que des comptes. Donnees : referentiel public, corpus synthetiques.

Usage (depuis la racine, apres `bash bench/etat.sh`) : voir `bench/etat.sh`.
"""

import argparse
import collections
import csv
import gzip
import os
import re
import sys
import unicodedata

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)

from classe_communes_capitales import (DETERMINANTS, forme_sans_cedex,  # noqa: E402
                                       mots_neutres)
from score_cedex import CONNECTEURS, juge, lit  # noqa: E402

COMMUNES = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets",
                        "geo_communes.csv.gz")
REGLES = ("exact_prefixe", "exact_ligne", "fin_de_ligne")
CODE_POSTAL = re.compile(r"(?<![\d])\d{5}(?!\d)")
MOT = re.compile(r"[^\W_]+(?:['’][^\W_]+)*", re.UNICODE)
# Mots de liaison admis en minuscules par `fin_de_ligne` : les connecteurs du
# detecteur d'adresse (`score_cedex.CONNECTEURS`) plus six liaisons d'une fin de
# ligne ordinaire. Liste ecrite pour s'approcher de P2-181, voir l'en-tete.
LIAISONS = CONNECTEURS | {"et", "à", "au", "près", "devant", "entre"}
PLUS_LONG_NOM = 12  # mots ; la commune la plus longue du referentiel en a huit


def norme(texte):
    """Sans accent, en capitales, tout ce qui n'est pas lettre ou chiffre
    devient un blanc, blancs reduits (meme normalisation que la colonne NORM,
    parentheses comprises)."""
    texte = texte.upper().replace("Œ", "OE").replace("Æ", "AE")
    texte = unicodedata.normalize("NFD", texte)
    texte = "".join(c for c in texte if not unicodedata.combining(c))
    return re.sub(r"[^A-Z0-9]+", " ", texte).strip()


def charge_referentiel(chemin=COMMUNES):
    with gzip.open(chemin, "rt", encoding="utf-8") as f:
        return {norme(r["NORM"]) for r in csv.DictReader(f, delimiter=";")}


def tokens(texte):
    return [(m.start(), m.end(), m.group()) for m in MOT.finditer(texte)]


def fin_ligne(texte, pos):
    i = texte.find("\n", pos)
    fin = len(texte) if i < 0 else i
    while fin > pos and (texte[fin - 1].isspace() or texte[fin - 1] in ".,;:!?"):
        fin -= 1
    return fin


def etendues(texte, regle, communes, neutres, capitales_seules=False):
    """Etendues [debut, fin) que la regle ajouterait dans `texte`."""
    if capitales_seules and texte != texte.upper():
        return []
    sortie = []
    for cp in CODE_POSTAL.finditer(texte):
        debut = cp.start()
        i = cp.end()
        while i < len(texte) and texte[i] in "   \t":
            i += 1
        if i == cp.end():
            continue  # pas de blanc : ce n'est pas « code postal commune »
        fin = fin_ligne(texte, i)
        if fin <= i:
            continue
        mots = tokens(texte[i:fin])
        if not mots:
            continue
        if regle == "exact_ligne":
            if norme(texte[i:fin]) in communes:
                sortie.append((debut, fin))
        elif regle == "exact_prefixe":
            meilleur = None
            for k in range(1, min(len(mots), PLUS_LONG_NOM) + 1):
                bout = i + mots[k - 1][1]
                # Une parenthese fermante finale fait partie du nom.
                reste = texte[bout:fin]
                if reste.startswith(")"):
                    bout += 1
                if norme(texte[i:bout]) in communes:
                    meilleur = bout
            if meilleur:
                sortie.append((debut, meilleur))
        elif regle == "fin_de_ligne":
            premier = [m[2].lower() for m in mots[:2]]
            premier = [re.split(r"['’]", p)[0] if re.match(r"^[dl]['’]", p)
                       else p for p in premier]
            if premier[0] in neutres and not (
                    premier[0] in DETERMINANTS and len(premier) > 1
                    and premier[1] not in neutres):
                continue
            if all(m[2][0].isupper() or m[2].lower() in LIAISONS
                   for m in mots):
                sortie.append((debut, fin))
        else:
            raise ValueError(regle)
    return sortie


def couverts_de(pred, ajouts=()):
    c = set()
    for p in pred.get("entities", []):
        c.update(range(p["start"], p["end"]))
    for a, b in ajouts:
        c.update(range(a, b))
    return c


def en_clair(texte, debut, fin, couverts):
    return any(not texte[i].isspace() and i not in couverts
               for i in range(debut, fin))


def mesure_balayage(corpus, preds, communes, neutres):
    reste = collections.Counter()
    base = collections.Counter()
    for doc in corpus:
        pred = preds[doc["id"]]
        _, clair, _ = juge(doc, pred)
        if not clair:
            continue
        e = doc["entities"][0]
        etab = any(p["type"] == "etablissement" and p["start"] < e["end"]
                   and p["end"] > e["start"] for p in pred["entities"])
        a, b = doc["parties"]["commune"]
        forme = forme_sans_cedex(doc["text"][a:b], doc["mots"], etab, neutres)
        base[forme] += 1
        for regle in REGLES:
            ajouts = etendues(doc["text"], regle, communes, neutres)
            c = couverts_de(pred, ajouts)
            if en_clair(doc["text"], e["start"], e["end"], c):
                reste[(regle, forme)] += 1
    total = sum(base.values())
    hors_e = total - base["E"]
    print(f"balayage sans CEDEX : {total} adresses en partie en clair "
          f"sur {len(corpus)} avec Ecluse.redact seul (règles simulées, "
          "hors lib/)")
    # Forme E : l'adresse est prise par `EtablissementDetector`, autre
    # detecteur ; l'union simulee ne rejoue pas `resolveOverlaps`, un chiffre
    # y serait un artefact. Les formes A a D sont comptees sans elle.
    formes = [f for f in "ABCD"] + ["autre"]
    for regle in REGLES:
        total_r = sum(reste[(regle, f)] for f in formes)
        detail = ", ".join(f"{f} {base[f]} → {reste[(regle, f)]}"
                           for f in formes if base[f])
        print(f"  règle={regle} : {hors_e} → {total_r} en partie en clair "
              f"(formes A à D) ; par forme : {detail}")
    print(f"  forme E : {base['E']} adresses, non simulable (autre "
          "détecteur, EtablissementDetector) ; la même pour toute règle")


def mesure_suivie(corpus, preds, communes, neutres, capitales_seules):
    base = collections.Counter()
    par_regle = {r: collections.Counter() for r in REGLES}
    for doc in corpus:
        pred = preds[doc["id"]]
        texte = doc["text"]
        a, b = doc["suite"]
        suite = [i for i in range(a, b) if not texte[i].isspace()]
        adr = doc["entities"][0]
        c0 = couverts_de(pred)
        m0 = sum(1 for i in suite if i in c0)
        base["documents"] += 1
        base["suite"] += len(suite)
        base["masques"] += m0
        base["docs_masques"] += m0 > 0
        base["en_clair"] += en_clair(texte, adr["start"], adr["end"], c0)
        for regle in REGLES:
            c = couverts_de(pred, etendues(texte, regle, communes, neutres,
                                           capitales_seules))
            m = sum(1 for i in suite if i in c)
            r = par_regle[regle]
            r["masques"] += m
            r["docs_masques"] += m > 0
            r["en_clair"] += en_clair(texte, adr["start"], adr["end"], c)
    regime = ("texte sans aucune minuscule seulement" if capitales_seules
              else "toute ligne, sans condition de casse")
    print(f"commune suivie, règles candidates ({regime}) : "
          f"{base['documents']} documents, {base['masques']} / "
          f"{base['suite']} caractères de suite masqués avec Ecluse.redact "
          f"seul ({base['docs_masques']} documents), "
          f"{base['en_clair']} adresse(s) en partie en clair")
    for regle in REGLES:
        r = par_regle[regle]
        print(f"  règle={regle} : {r['masques']} / {base['suite']} caractères "
              f"de suite masqués ({r['masques'] - base['masques']:+d}), "
              f"{r['docs_masques']} documents ({r['docs_masques'] - base['docs_masques']:+d}), "
              f"{r['en_clair']} adresse(s) en partie en clair")


def mesure_neutre(corpus, preds, communes, neutres):
    base = collections.Counter()
    ajout = {r: collections.Counter() for r in REGLES}
    total = collections.Counter()
    for doc in corpus:
        pred = preds[doc["id"]]
        cle = (doc.get("casse", "toute"),)
        total[cle] += 1
        total[("tout",)] += 1
        predite = any(p["type"] == "adresse" for p in pred["entities"])
        base[cle] += predite
        base[("tout",)] += predite
        c0 = couverts_de(pred)
        for regle in REGLES:
            # Une phrase compte si la regle masque un caractere de plus.
            nouveau = any(i not in c0 for a, b in etendues(
                doc["text"], regle, communes, neutres,
                capitales_seules=True) for i in range(a, b)
                if not doc["text"][i].isspace())
            ajout[regle][cle] += nouveau
            ajout[regle][("tout",)] += nouveau
    print(f"témoin sans adresse annotée, règles candidates : {total[('tout',)]} phrases, "
          f"{base[('tout',)]} avec une adresse prédite par Ecluse.redact, "
          "aucune adresse annotée")
    for casse in sorted(c for (c,) in total if c != "tout"):
        k = (casse,)
        print(f"  casse={casse} : {base[k]} / {total[k]} phrases à adresse "
              "prédite avec Ecluse.redact seul ; " + " ; ".join(
                  f"{r} +{ajout[r][k]}" for r in REGLES))


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sp = p.add_subparsers(dest="mesure", required=True)
    for nom in ("balayage", "suivie", "neutre"):
        s = sp.add_parser(nom)
        s.add_argument("--corpus", required=True)
        s.add_argument("--pred", required=True)
        if nom == "suivie":
            s.add_argument("--casse", choices=("libre", "capitales"),
                           default="libre")
    a = p.parse_args()
    corpus = lit(a.corpus)
    preds = {d["id"]: d for d in lit(a.pred)}
    communes = charge_referentiel()
    neutres = mots_neutres()
    if a.mesure == "balayage":
        mesure_balayage(corpus, preds, communes, neutres)
    elif a.mesure == "suivie":
        mesure_suivie(corpus, preds, communes, neutres, a.casse == "capitales")
    else:
        mesure_neutre(corpus, preds, communes, neutres)


if __name__ == "__main__":
    main()
