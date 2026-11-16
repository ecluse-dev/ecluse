#!/usr/bin/env python3
"""Scoreur du corpus de courriers en capitales (P2-210, mesure).

D'apres des predictions au format de `run_redact_bench.dart` (donc
**`Ecluse.redact`**, ce que recoit le LLM). Les blancs ne comptent pas.

- **masquage en trop** : une ligne dont au moins un caractere hors blanc est
  sous une detection, quel qu'en soit le type, **hors de l'adresse annotee**.
  C'est de la lisibilite perdue, pas une fuite. Compte par ligne, par famille
  de ligne et par courrier ;
- **adresse en partie en clair** (fuite) : au moins un caractere de l'adresse
  annotee sous aucune detection ; garde-fou, doit rester a 0.

N'imprime que des comptes, jamais un texte.

Usage :
    python3 score_courriers.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json
import re

# Premier mot derriere un nombre a cinq chiffres (« 39314 NUMEROS EN ATTENTE ») :
# dit quel mot, parmi ceux du vocabulaire du generateur, fait masquer la ligne.
MOT_APRES_NOMBRE = re.compile(r"(?<!\d)\d{5} ([A-Z]+)")

FAMILLES = ("reference", "montant", "quantite", "texte", "adresse",
            "montant_adresse")


def lit(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(ligne) for ligne in f if ligne.strip()]


def juge(doc, pred):
    """Rend (adresses annotees, en partie en clair, {famille: [lignes,
    lignes en trop]}, courrier en trop ?, {type: detections en trop},
    {mot apres un nombre a cinq chiffres: [lignes, lignes en trop]})."""
    texte = doc["text"]
    couverts = {}
    for p in pred.get("entities", []):
        for i in range(p["start"], p["end"]):
            couverts[i] = p["type"]
    annotes = set()
    clair = 0
    for e in doc["entities"]:
        pos = [i for i in range(e["start"], e["end"]) if not texte[i].isspace()]
        annotes.update(range(e["start"], e["end"]))
        clair += any(i not in couverts for i in pos)
    par_famille = collections.defaultdict(lambda: [0, 0])
    en_trop_doc = False
    types = collections.Counter()
    mots = collections.defaultdict(lambda: [0, 0])
    for lg in doc["lignes"]:
        masques = [i for i in range(lg["debut"], lg["fin"])
                   if not texte[i].isspace() and i in couverts
                   and i not in annotes]
        par_famille[lg["famille"]][0] += 1
        m = MOT_APRES_NOMBRE.search(texte[lg["debut"]:lg["fin"]])
        if m:
            mots[m.group(1)][0] += 1
            mots[m.group(1)][1] += bool(masques)
        if masques:
            par_famille[lg["famille"]][1] += 1
            en_trop_doc = True
            types.update({couverts[i] for i in masques})
    return (len(doc["entities"]), clair, par_famille, en_trop_doc, types,
            mots)


def compte(corpus, preds):
    t = collections.Counter()
    fam = {f: [0, 0] for f in FAMILLES}
    types = collections.Counter()
    mots = collections.defaultdict(lambda: [0, 0])
    for doc in corpus:
        adr, clair, pf, trop, ty, mt = juge(doc, preds[doc["id"]])
        t["courriers"] += 1
        t["adresses"] += adr
        t["clair"] += clair
        t["courriers_en_trop"] += trop
        types.update(ty)
        for f, (n, m) in pf.items():
            fam[f][0] += n
            fam[f][1] += m
        for w, (n, m) in mt.items():
            mots[w][0] += n
            mots[w][1] += m
    return t, fam, types, mots


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--corpus", required=True)
    p.add_argument("--pred", required=True)
    a = p.parse_args()
    preds = {d["id"]: d for d in lit(a.pred)}
    t, fam, types, mots = compte(lit(a.corpus), preds)
    lignes = sum(n for n, _ in fam.values())
    trop = sum(m for _, m in fam.values())
    print(f"courriers : {t['courriers']} courriers, {lignes} lignes, "
          f"{t['adresses']} adresses annotées, {t['clair']} courrier(s) à "
          "adresse en partie en clair (Ecluse.redact)")
    print(f"  masquage en trop : {t['courriers_en_trop']} courriers / "
          f"{t['courriers']}, {trop} lignes / {lignes}")
    for f in FAMILLES:
        n, m = fam[f]
        print(f"  famille={f} : {m} / {n} lignes masquées en trop")
    for w, (n, m) in sorted(mots.items()):
        if m:
            print(f"  mot après un nombre={w} : {m} / {n} lignes masquées en trop")
    print("  types en trop : " + (", ".join(
        f"{k} {v}" for k, v in sorted(types.items())) or "aucun"))


if __name__ == "__main__":
    main()
