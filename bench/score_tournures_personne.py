#!/usr/bin/env python3
"""Scoreur du témoin élargi des tournures de personne (P2-226).

D'après des prédictions au format de `run_redact_bench.dart` :
**`Ecluse.redact`** (ce que reçoit le LLM), un appel par document, sans
dossier. Pour chaque document, on regarde le seul mot placé dans la tournure
(champ `mot` du corpus) :

- familles sans personne (`roles`, `organismes`, `communs`) : le mot est
  « masqué à tort » si **au moins un** de ses caractères est sous une
  détection, quel qu'en soit le type (lisibilité perdue, pas une fuite) ;
- familles de patronymes : le mot est « masqué » si **tous** ses caractères
  non blancs sont sous une détection ; sinon il est « en clair », c'est une
  fuite (même règle que `leak_hors_civilite.py`).

Les détections hors du mot (en-tête, reste de la phrase) sont comptées à part.
N'imprime que des comptes, jamais un texte ni un mot.

Usage :
    python3 score_tournures_personne.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json

FAMILLES = ["roles", "organismes", "communs", "patronymes_communes",
            "patronymes_noms_communs"]
PERSONNES = {"patronymes_communes", "patronymes_noms_communs"}
TOURNURES = ["dossier de", "à la demande de", "entretien avec",
             "sujet : a confirmé"]


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def couverts(ents, debut, fin):
    """Positions de [debut, fin) sous au moins une détection."""
    vus = set()
    for e in ents:
        for i in range(max(debut, e["start"]), min(fin, e["end"])):
            vus.add(i)
    return vus


def mesure(corpus, pred):
    preds = {p["id"]: p for p in pred}
    par = collections.defaultdict(collections.Counter)
    types = collections.Counter()
    hors_mot = 0
    for doc in corpus:
        ents = preds[doc["id"]].get("entities", [])
        d, f = doc["mot"]["start"], doc["mot"]["end"]
        sous = couverts(ents, d, f)
        if doc["famille"] in PERSONNES:
            utiles = {i for i in range(d, f) if not doc["text"][i].isspace()}
            masque = utiles <= sous
        else:
            masque = bool(sous)
        for e in ents:
            if e["end"] <= d or e["start"] >= f:
                hors_mot += 1
            elif masque:
                types[(doc["famille"] in PERSONNES, e["type"])] += 1
        for cle in ((doc["famille"], "*"), (doc["famille"], doc["tournure"])):
            par[cle]["documents"] += 1
            par[cle]["masques"] += masque
    return par, types, hors_mot


def affiche(corpus, par, types, hors_mot):
    n_ent = sum(len(d["entities"]) for d in corpus)
    tournures = [t for t in TOURNURES if any(d["tournure"] == t for d in corpus)]
    print(f"tournures de personne : {len(corpus)} documents, {len(FAMILLES)} "
          f"familles, {n_ent} noms annotés, {hors_mot} détection(s) hors du mot")
    for fam in FAMILLES:
        c = par[(fam, "*")]
        if fam in PERSONNES:
            print(f"  famille={fam} : {c['masques']} / {c['documents']} "
                  f"masqués, {c['documents'] - c['masques']} en clair (fuite)")
        else:
            print(f"  famille={fam} : {c['masques']} / {c['documents']} "
                  f"masqués à tort")
        for t in tournures:
            c = par[(fam, t)]
            print(f"    tournure={t} : {c['masques']} / {c['documents']}")
    for personne, libelle in ((False, "masquages à tort"),
                              (True, "patronymes masqués")):
        detail = ", ".join(f"{k} {v}" for (p, k), v in sorted(types.items())
                           if p == personne) or "aucun"
        print(f"  types sur les {libelle} : {detail}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    a = ap.parse_args()
    corpus = charge(a.corpus)
    affiche(corpus, *mesure(corpus, charge(a.pred)))


if __name__ == "__main__":
    main()
