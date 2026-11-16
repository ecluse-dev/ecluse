#!/usr/bin/env python3
"""Scoreur du balayage « commune a mot de voie » (P2-213).

D'apres des predictions au format de `run_redact_bench.dart` (donc
**`Ecluse.redact`**, ce que recoit le LLM). Les blancs ne comptent pas.

- **adresse en partie en clair** (fuite) : au moins un caractere d'une
  adresse annotee sous aucune detection, quel qu'en soit le type. Compte par
  document, par axe et par mot de voie, avec **ce qui** reste en clair (vraie
  voie, code postal, commune, seconde adresse) et si le **debut** de
  l'adresse (code postal ou premier mot du nom) est touche, ou la fin du nom
  seule ;
- **ligne « code postal + mot » masquee** : de la lisibilite perdue, pas une
  fuite ; comptee a part.

N'imprime que des comptes, les noms d'axes et les mots de voie du detecteur
(du code versionne) ; jamais un texte, un code postal ni un nom de commune.

Usage :
    python3 score_commune_voie.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json

AXES = (("casse", ("ordinaire", "capitales")),
        ("ecriture", ("postale", "libelle", "libelle_espaces",
                      "capitales_tirets")),
        ("cedex", ("avec", "sans")),
        ("suite", ("sans", "mot", "adresse")),
        ("voie", ("sans", "avec")))
PARTIES = ("voie", "cp", "commune", "seconde")
NOMS = {"voie": "vraie voie", "cp": "code postal", "commune": "commune",
        "seconde": "seconde adresse"}


def lit(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(ligne) for ligne in f if ligne.strip()]


def _premier_mot_en_clair(doc, en_clair):
    debut, fin = doc["parties"]["commune"]
    nom = doc["text"][debut:fin]
    longueur = len(nom)
    for i, c in enumerate(nom):
        if c in " -'’":
            longueur = i
            break
    return en_clair(debut, debut + longueur)


def juge(doc, pred):
    """Rend (en partie en clair ?, {partie en clair}, ligne « mot » masquee :
    None si absente, sinon bool)."""
    texte = doc["text"]
    couverts = set()
    for p in pred.get("entities", []):
        couverts.update(range(p["start"], p["end"]))

    def en_clair(debut, fin):
        return any(i not in couverts for i in range(debut, fin)
                   if not texte[i].isspace())

    defaut = any(en_clair(e["start"], e["end"]) for e in doc["entities"])
    parties = {nom for nom in PARTIES
               if doc["parties"].get(nom) and en_clair(*doc["parties"][nom])}
    # Signature du défaut de P2-213 : le code postal ou le premier mot du nom
    # en clair. La fin du nom seule en clair est une autre cause (commune de
    # plus de quatre mots ou liée par « au », « et », sans CEDEX).
    if "cp" in parties or _premier_mot_en_clair(doc, en_clair):
        parties.add("debut")
    ligne = doc["parties"].get("ligne_mot")
    masquee = None
    if ligne:
        masquee = any(i in couverts for i in range(*ligne)
                      if not texte[i].isspace())
    return defaut, parties, masquee


def compte(corpus, preds):
    t = collections.Counter()
    par_axe = collections.defaultdict(lambda: [0, 0])
    par_mot = collections.defaultdict(lambda: [0, 0])
    parties = collections.Counter()
    communes, touchees = set(), set()
    for doc in corpus:
        if doc["id"] not in preds:
            raise ValueError(f"document {doc['id']} : prédiction absente")
        pred = preds[doc["id"]]
        t["documents"] += 1
        if pred.get("refuse"):
            t["refus"] += 1
            continue
        defaut, clair, masquee = juge(doc, pred)
        t["defaut"] += defaut
        communes.add(doc["com"])
        if defaut:
            touchees.add(doc["com"])
        parties.update(clair)
        if defaut:
            t["debut" if "debut" in clair else "fin_seule"] += 1
        for axe, _ in AXES:
            par_axe[(axe, doc[axe])][0] += 1
            par_axe[(axe, doc[axe])][1] += defaut
        par_mot[doc["mot_de_voie"]][0] += 1
        par_mot[doc["mot_de_voie"]][1] += defaut
        if masquee is not None:
            t["lignes_mot"] += 1
            t["lignes_mot_masquees"] += masquee
    t["communes"] = len(communes)
    t["communes_touchees"] = len(touchees)
    return t, par_axe, par_mot, parties


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--corpus", required=True)
    p.add_argument("--pred", required=True)
    a = p.parse_args()
    preds = {d["id"]: d for d in lit(a.pred)}
    t, par_axe, par_mot, parties = compte(lit(a.corpus), preds)
    print(f"commune à mot de voie : {t['documents']} documents, "
          f"{t['communes']} communes, {t['defaut']} document(s) à adresse en "
          f"partie en clair ({t['communes_touchees']} commune(s)), "
          f"{t['refus']} refus (Ecluse.redact)")
    for axe, valeurs in AXES:
        for v in valeurs:
            n, m = par_axe.get((axe, v), (0, 0))
            print(f"  {axe}={v} : {m} / {n} en défaut")
    for mot in sorted(par_mot):
        n, m = par_mot[mot]
        print(f"  mot de voie={mot} : {m} / {n} en défaut")
    print("  en clair : " + ", ".join(
        f"{NOMS[k]} {parties.get(k, 0)}" for k in PARTIES))
    print(f"  début en clair (code postal ou premier mot de la commune) : "
          f"{t['debut']} document(s) ; fin du nom seule en clair : "
          f"{t['fin_seule']}")
    print(f"  ligne « code postal + mot » masquée (en trop, pas une fuite) : "
          f"{t['lignes_mot_masquees']} / {t['lignes_mot']}")


if __name__ == "__main__":
    main()
