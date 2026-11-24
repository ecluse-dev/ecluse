#!/usr/bin/env python3
"""P2-279 (mesure) : taux de masquages à tort **par détecteur**, avec un
intervalle de confiance à 95 % (Wilson), sur des corpus sans aucune donnée
personnelle annotée, par `Ecluse.redact` (`run_faux_accords.dart`).

Attribution (l'entité ne porte pas le nom de son détecteur) : la provenance
`lectureOcr` désigne P2-268 ; un IBAN à confiance 0,3 sans provenance, le
détecteur de clé fausse sans libellé (P2-252) ; un NIR à confiance 0,3 sans
provenance, P2-258 (ou la clé fausse derrière un libellé de P2-275, qui n'a pas
de libellé dans ces corpus) ; adresse et FINESS par leur type ; tout autre type
est rangé sous « autre : <type> ». Sur un corpus de phrases dictées en lettres
(`--tout-en-dictees`), toute entité est attribuée aux nombres dictés (P2-267).

Un « taux » est un nombre de **documents** avec au moins une entité du
détecteur, sur le nombre de documents. Les exemples sont des phrases
synthétiques du corpus (jamais une donnée réelle). Aucune valeur d'un texte
n'est imprimée en dehors de ces exemples.

Usage :
    python3 score_faux_accords.py --corpus c.jsonl --pred p.jsonl [--nom NOM]
        [--tout-en-dictees] [--exemples N]
"""
import argparse
import json
import math
from collections import Counter, defaultdict


def wilson(k, n, z=1.959964):
    """Intervalle de Wilson à 95 % pour k succès sur n essais."""
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / d
    marge = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, centre - marge), min(1.0, centre + marge))


def detecteur(e, tout_en_dictees):
    type_, conf, prov = e
    if tout_en_dictees:
        return "nombres dictés (P2-267)"
    if prov == "lectureOcr":
        return "OCR (P2-268)"
    if type_ == "iban" and abs(conf - 0.3) < 1e-9:
        return "IBAN à clé fausse (P2-252)"
    if type_ == "nir" and abs(conf - 0.3) < 1e-9:
        return "NIR à clé fausse (P2-258)"
    if type_ == "iban" and conf == 1.0:
        return "IBAN à clé juste par hasard (P2-252 absent, 1 chance sur 97)"
    if type_ in ("adresse", "finess"):
        return type_
    return f"autre : {type_}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    ap.add_argument("--nom", default="corpus")
    ap.add_argument("--tout-en-dictees", action="store_true")
    ap.add_argument("--exemples", type=int, default=1)
    a = ap.parse_args()
    corpus = [json.loads(l) for l in open(a.corpus, encoding="utf-8") if l.strip()]
    pred = [json.loads(l) for l in open(a.pred, encoding="utf-8") if l.strip()]
    if len(corpus) != len(pred):
        raise SystemExit("ÉCHEC : le corpus et les prédictions n'ont pas la "
                         "même longueur")
    docs = Counter()
    entites = Counter()
    exemples = defaultdict(list)
    for d, p in zip(corpus, pred):
        if d.get("entities"):
            raise SystemExit("ÉCHEC : ce corpus annote des entités : ce n'est "
                             "pas un témoin sans donnée personnelle")
        vus = set()
        for e in p["e"]:
            lab = detecteur(e, a.tout_en_dictees)
            entites[lab] += 1
            vus.add(lab)
        for lab in vus:
            docs[lab] += 1
            if len(exemples[lab]) < a.exemples:
                exemples[lab].append(d["text"][:110])
    n = len(corpus)
    avec = sum(1 for p in pred if p["e"])
    print(f"## {a.nom} : {n} documents, {avec} avec au moins une entité")
    for lab in sorted(docs, key=lambda k: -docs[k]):
        lo, hi = wilson(docs[lab], n)
        print(f"{lab} : {docs[lab]} / {n} documents "
              f"({100 * docs[lab] / n:.3f} %, IC 95 % "
              f"[{100 * lo:.3f} ; {100 * hi:.3f}] %), {entites[lab]} entité(s)")
        for x in exemples[lab]:
            print(f"    exemple : {x}")
    if not docs:
        lo, hi = wilson(0, n)
        print(f"aucun détecteur : 0 / {n} documents "
              f"(IC 95 % [0.000 ; {100 * hi:.4f}] %)")


main()
