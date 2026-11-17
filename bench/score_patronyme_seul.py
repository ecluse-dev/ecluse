#!/usr/bin/env python3
"""Noms restés en clair hors civilité, par tournure (P2-218).

Compare, sur un corpus de dossiers (`generate_corpus_dossiers.py`), deux jeux
de prédictions de `run_dossiers_bench.dart` : un appel `Ecluse.redact` **par
document** (état d'avant) et un appel **avec session de dossier** (`--dossier`).
Chemin mesuré : `Ecluse.redact` (ce que reçoit le LLM), jamais le moteur seul.

Un nom annoté est « manqué hors civilité » quand au moins un caractère non
blanc d'un de ses mots, civilité exclue, n'est sous aucune détection (quel
qu'en soit le type), comme `leak_hors_civilite.py`. Les noms sont classés :

- `seul` : un mot (patronyme seul, sans prénom ni civilité) ;
- `complet` : plusieurs mots (civilité, prénom, ou les deux avec le nom).

Pour le patronyme seul, la **tournure** est lue dans le texte qui le précède
(« le dossier de », « à la demande de », « l'entretien avec », « adressé à »)
ou qui le suit (« a confirmé », « rappelle », « n'a pas répondu »). Les
tournures sont celles du générateur, reconnues par des expressions
régulières, jamais par le nom lui-même.

N'imprime que des comptes, jamais un texte ni un nom.

Usage :
    python3 score_patronyme_seul.py --corpus c.jsonl \\
        --pred-document p1.jsonl --pred-session p2.jsonl
"""

import argparse
import collections
import json
import re

CIVILITES = {"m.", "monsieur", "mme", "madame", "mademoiselle", "mlle", "dr",
             "docteur", "pr", "professeur"}

# (étiquette, motif sur la fin du texte qui précède, la ligne seule).
AVANT = [
    ("dossier de", re.compile(r"\bdossier\s+de\s*$", re.I)),
    ("à la demande de", re.compile(r"\bdemande\s+de\s*$", re.I)),
    ("entretien avec", re.compile(r"\bentretien\s+avec\s*$", re.I)),
    ("adressé à", re.compile(r"\badress[ée]e?\s+à\s*$", re.I)),
]
# Motif sur le début du texte qui suit, sur la ligne seule.
APRES = [
    ("sujet : a confirmé", re.compile(r"^\s+a\s+confirm[ée]\b", re.I)),
    ("sujet : rappelle", re.compile(r"^\s+rappelle\b", re.I)),
    ("sujet : n'a pas répondu", re.compile(r"^\s+n'a\s+pas\s+r[ée]pondu", re.I)),
]
TOURNURES = [t for t, _ in AVANT] + [t for t, _ in APRES] + ["autre"]


def tournure(texte, debut, fin):
    ligne_avant = texte[:debut].split("\n")[-1]
    ligne_apres = texte[fin:].split("\n")[0]
    for etiquette, motif in AVANT:
        if motif.search(ligne_avant):
            return etiquette
    for etiquette, motif in APRES:
        if motif.search(ligne_apres):
            return etiquette
    return "autre"


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def couverts(pred):
    s = set()
    for m in pred.get("mentions", []):
        s.update(range(m["start"], m["end"]))
    return s


def manque_hors_civilite(texte, debut, fin, protege):
    for m in re.finditer(r"\S+", texte[debut:fin]):
        if m.group().lower() in CIVILITES:
            continue
        a = debut + m.start()
        if any(i not in protege for i in range(a, debut + m.end())):
            return True
    return False


def mesure(corpus, pred_doc, pred_session):
    pd = {p["id"]: p for p in pred_doc}
    ps = {p["id"]: p for p in pred_session}
    res = collections.defaultdict(collections.Counter)
    for doc in corpus:
        texte = doc["text"]
        cd, cs = couverts(pd[doc["id"]]), couverts(ps[doc["id"]])
        for e in doc["entities"]:
            if e["type"] != "nom":
                continue
            seul = len(texte[e["start"]:e["end"]].split()) == 1
            cle = ("seul", tournure(texte, e["start"], e["end"])) if seul \
                else ("complet", "-")
            for c in (res[cle], res[(cle[0], "*")]):
                c["noms"] += 1
                c["document"] += manque_hors_civilite(
                    texte, e["start"], e["end"], cd)
                c["session"] += manque_hors_civilite(
                    texte, e["start"], e["end"], cs)
    return res


def affiche(res):
    for genre, libelle in (("seul", "patronyme seul"),
                           ("complet", "plusieurs mots (civilité ou prénom)")):
        c = res[(genre, "*")]
        print(f"noms hors civilité, {libelle} : {c['noms']} mentions, "
              f"manquées document par document {c['document']}, "
              f"en session {c['session']}")
    for t in TOURNURES:
        c = res[("seul", t)]
        if c["noms"]:
            print(f"  tournure={t} : {c['document']} / {c['noms']} manqués "
                  f"document par document, {c['session']} / {c['noms']} "
                  f"en session")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred-document", required=True)
    ap.add_argument("--pred-session", required=True)
    a = ap.parse_args()
    affiche(mesure(charge(a.corpus), charge(a.pred_document),
                   charge(a.pred_session)))


if __name__ == "__main__":
    main()
