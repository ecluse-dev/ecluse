#!/usr/bin/env python3
"""Scoreur du temoin « nombre a cinq chiffres + mot neutre », mot par mot
(P2-211, mesure).

D'apres des predictions au format de `run_redact_bench.dart` (donc
**`Ecluse.redact`**, ce que recoit le LLM). Le corpus n'annote aucune entite :

- **nombre masque en adresse** : au moins un chiffre du nombre a cinq chiffres
  est sous une detection de type `adresse`. La liste des mots neutres n'a pas
  protege le nombre. C'est de la lisibilite perdue, pas une fuite ;
- **nombre masque sous un autre type** : meme chose, sous un type qui n'est
  pas `adresse` (compte a part : la liste des mots neutres n'y est pour rien).

Compte par mot, par forme (accentuee, sans accent) et par casse, puis par axe
de construction. N'imprime que des comptes et les mots de la liste (du code
versionne, pas une valeur tiree d'un texte) ; jamais une phrase ni un nombre.

Usage :
    python3 score_mots_neutres.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json
import re

NOMBRE = re.compile(r"(?<!\d)\d{5}(?!\d)")
CASSES = ("capitales", "ordinaire")
FORMES = ("accentuee", "sans_accent")
AXES = (("casse", CASSES), ("forme", FORMES),
        ("position", ("debut", "milieu")), ("suite", ("rien", "neutre", "nom")),
        ("majuscules", ("capitales", "phrase", "mixte")))


def lit(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(ligne) for ligne in f if ligne.strip()]


def juge(doc, pred):
    """Rend (masque en adresse ?, masque sous un autre type ?, types vus sur
    le nombre). Refuse (ValueError) une phrase sans nombre a cinq chiffres."""
    m = NOMBRE.search(doc["text"])
    if m is None:
        raise ValueError(f"document {doc['id']} : pas de nombre à cinq chiffres")
    types = {p["type"] for p in pred.get("entities", [])
             if p["start"] < m.end() and p["end"] > m.start()}
    return "adresse" in types, bool(types - {"adresse"}), types


def compte(corpus, preds):
    """Rend (totaux, {mot: {(forme, casse): [phrases, en adresse]}},
    {(axe, valeur): [phrases, en adresse]}, types, ordre des mots)."""
    t = collections.Counter()
    par_mot = {}
    par_axe = collections.defaultdict(lambda: [0, 0])
    types = collections.Counter()
    for doc in corpus:
        if doc["id"] not in preds:
            raise ValueError(f"document {doc['id']} : prédiction absente")
        adresse, autre, vus = juge(doc, preds[doc["id"]])
        t["phrases"] += 1
        t["adresse"] += adresse
        t["autre"] += autre
        types.update(vus)
        case = par_mot.setdefault(doc["mot"], {}).setdefault(
            (doc["forme"], doc["casse"]), [0, 0])
        case[0] += 1
        case[1] += adresse
        for axe, _ in AXES:
            par_axe[(axe, doc[axe])][0] += 1
            par_axe[(axe, doc[axe])][1] += adresse
    return t, par_mot, par_axe, types


def ligne_mot(mot, cases):
    """« mot=numéros : capitales 0 / 100, ordinaire 0 / 100 ; sans accent :
    capitales 100 / 100, ordinaire 0 / 100 »."""
    morceaux = []
    for forme in FORMES:
        if not any(f == forme for f, _ in cases):
            continue
        detail = ", ".join(
            f"{c} {cases[(forme, c)][1]} / {cases[(forme, c)][0]}"
            for c in CASSES if (forme, c) in cases)
        morceaux.append(detail if forme == "accentuee"
                        else f"sans accent : {detail}")
    return f"  mot={mot} : " + " ; ".join(morceaux)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--corpus", required=True)
    p.add_argument("--pred", required=True)
    a = p.parse_args()
    preds = {d["id"]: d for d in lit(a.pred)}
    t, par_mot, par_axe, types = compte(lit(a.corpus), preds)
    touches = sum(1 for cases in par_mot.values()
                  if any(m for _, m in cases.values()))
    print(f"mots neutres : {len(par_mot)} mots, {t['phrases']} phrases, "
          f"{t['adresse']} nombre(s) masqué(s) en adresse, {t['autre']} sous "
          f"un autre type, {touches} mot(s) touché(s) (Ecluse.redact)")
    for axe, valeurs in AXES:
        for v in valeurs:
            n, m = par_axe.get((axe, v), (0, 0))
            if n:
                print(f"  {axe}={v} : {m} / {n} nombres masqués en adresse")
    for mot in sorted(par_mot):
        print(ligne_mot(mot, par_mot[mot]))
    print("  types sur le nombre : " + (", ".join(
        f"{k} {v}" for k, v in sorted(types.items())) or "aucun"))


if __name__ == "__main__":
    main()
