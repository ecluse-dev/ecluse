#!/usr/bin/env python3
"""P2-280 (mesure) : évalue, hors ligne, des critères du signalement « nombre
dicté non reconnu » à partir du relevé de `mesure_criteres_signalement.sh`
(chemin `Ecluse.redact`, une ligne par suite d'au moins 9 mots-nombres).

Un critère décide si une suite non recouverte par une entité est signalée. Un
document est signalé si au moins une de ses suites l'est (comme le produit).
Rien n'est corrigé : les critères sont simulés ici, jamais dans `lib/`.

Pour chaque critère :
- signalements à tort sur le témoin durci (630 phrases) et le témoin d'origine
  (300) ;
- identifiants dictés abîmés passés **sans avertissement** (non masqués en
  entier et non signalés), par corpus (mot perdu, clé fausse) et par type.

Usage : python3 score_criteres_signalement.py DOSSIER_DU_RELEVE
"""
import json
import os
import re
import sys
import unicodedata
from collections import Counter

ICI = os.path.dirname(os.path.abspath(__file__))


def sans_accent(s):
    return "".join(c for c in unicodedata.normalize("NFD", s.lower())
                   if unicodedata.category(c) != "Mn")


MOTCLE = re.compile(r"\b(?:code|digicode|mot de passe|mdp|pin)\b")
LIBELLE = re.compile(
    r"\b(?:nir|secu|securite sociale|ss|assure|iban|rib|compte|bancaire|banque|"
    r"virement|rpps|finess|siren|adeli|identifiant)\b")


def releve(dossier, nom):
    docs, cur = [], None
    for l in open(os.path.join(dossier, nom + ".criteres"), encoding="utf-8"):
        l = l.strip()
        if l == "DOC":
            cur = []
            docs.append(cur)
        elif l:
            cur.append(json.loads(l))
    return docs


def fenetre(s, n):
    return sans_accent(re.sub(r"\s+", " ", s["avant"]))[-n:]


def motcle(s, n):
    return bool(MOTCLE.search(fenetre(s, n)))


def libelle(s):
    return bool(LIBELLE.search(fenetre(s, 60)))


def forme(s):
    return 13 <= s["mots"] <= 17 or s["mots"] >= 19


CRITERES = [
    ("seuil 9 (actuel)", lambda s: s["mots"] >= 9),
    ("seuil 11", lambda s: s["mots"] >= 11),
    ("seuil 13", lambda s: s["mots"] >= 13),
    ("9 sauf « code », « digicode », « mot de passe » dans les 30 caractères avant",
     lambda s: not motcle(s, 30)),
    ("9 sauf mot voisin dans les 60 caractères avant",
     lambda s: not motcle(s, 60)),
    ("9 sauf mot voisin dans les 100 caractères avant",
     lambda s: not motcle(s, 100)),
    ("9 sauf mot voisin (100), sauf si un libellé d'identifiant l'accompagne",
     lambda s: not motcle(s, 100) or libelle(s)),
    ("9 et libellé d'identifiant dans les 60 caractères avant",
     lambda s: libelle(s)),
    ("9 et (libellé ou au moins 13 mots)",
     lambda s: libelle(s) or s["mots"] >= 13),
    ("9 et (libellé ou au moins 15 mots)",
     lambda s: libelle(s) or s["mots"] >= 15),
    ("9 et forme d'identifiant (13 à 17 ou au moins 19 mots)",
     lambda s: forme(s)),
    ("9, sans mot voisin (100) et (libellé ou au moins 13 mots)",
     lambda s: not motcle(s, 100) and (libelle(s) or s["mots"] >= 13)),
    ("9, sans mot voisin (100) et forme d'identifiant",
     lambda s: not motcle(s, 100) and forme(s)),
    ("9, sans mot voisin (100), libellé ou forme d'identifiant",
     lambda s: not motcle(s, 100) and (libelle(s) or forme(s))),
]


def signale(doc, critere):
    return any((not s["couvert"]) and s["mots"] >= 9 and critere(s) for s in doc)


def couvert(e, entites):
    pos = e["start"]
    for a, b in sorted((x["start"], x["end"]) for x in entites):
        if b <= pos:
            continue
        if a > pos:
            break
        pos = b
        if pos >= e["end"]:
            return True
    return pos >= e["end"]


def main():
    dossier = sys.argv[1]
    dur = releve(dossier, "corpus_temoin_mots_nombres_dur")
    ori = releve(dossier, "corpus_temoin_mots_nombres")
    abimes = {}
    for nom in ("mot_perdu", "cle_fausse"):
        n = f"corpus_dicte_non_valide_{nom}"
        cor = [json.loads(l) for l in open(
            os.path.join(ICI, "transcrit", n + ".jsonl"), encoding="utf-8")]
        pred = {}
        for l in open(os.path.join(dossier, n + ".pred.jsonl"), encoding="utf-8"):
            d = json.loads(l)
            pred[d["id"]] = d
        abimes[nom] = (cor, releve(dossier, n), pred)
    print("| Critère | À tort, durci (630) | À tort, origine (300) | "
          "Rien, mot perdu (NIR / IBAN) | Rien, clé fausse (NIR / IBAN) | Rien, total |")
    print("|---|---|---|---|---|---|")
    for nom, f in CRITERES:
        a = sum(signale(d, f) for d in dur)
        o = sum(signale(d, f) for d in ori)
        cells, total = [], 0
        for k in ("mot_perdu", "cle_fausse"):
            cor, docs, pred = abimes[k]
            rien = Counter()
            for c, d in zip(cor, docs):
                e = c["entities"][0]
                if couvert(e, pred[c["id"]]["entities"]):
                    continue
                if not signale(d, f):
                    rien[e["type"]] += 1
            cells.append(f"{rien['nir'] + rien['iban']} ({rien['nir']} / {rien['iban']})")
            total += rien["nir"] + rien["iban"]
        print(f"| {nom} | {a} | {o} | {cells[0]} | {cells[1]} | {total} |")


if __name__ == "__main__":
    main()
