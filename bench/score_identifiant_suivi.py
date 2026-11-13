#!/usr/bin/env python3
"""Scoreur du corpus « identifiant suivi d'un nombre » (P2-174).

Pour chaque document, d'apres des predictions au format de
`run_redact_bench.dart` (donc **`Ecluse.redact`**, ce que recoit le LLM) :

- `couvert` : tous les caracteres de l'identifiant (hors blancs) sont sous
  une detection, quel qu'en soit le type. Sinon c'est une fuite ;
- `type_juste` : couvert, et toute detection qui touche l'identifiant porte
  son type ;
- `suite_avalee` : une detection touche a la fois l'identifiant et la suite
  (la date, l'age ou le nombre voisin est abime) ;
- `suite_masquee` : une detection touche la suite sans toucher
  l'identifiant (une autre regle l'a prise ; compte a part).

Usage :
    python3 score_identifiant_suivi.py --corpus c.jsonl --pred p.jsonl
"""

import argparse
import collections
import json

AXES = ("type_id", "famille", "separateur", "contexte")


def juge(doc, pred):
    """Rend un dict de booleens pour un document."""
    texte = doc["text"]
    e = doc["entities"][0]
    s = doc["suite"]
    preds = pred.get("entities", [])
    couverts = set()
    for p in preds:
        couverts.update(range(p["start"], p["end"]))
    utiles = [i for i in range(e["start"], e["end"]) if not texte[i].isspace()]
    couvert = all(i in couverts for i in utiles)

    def touche(p, a, b):
        return p["start"] < b and a < p["end"]

    sur_id = [p for p in preds if touche(p, e["start"], e["end"])]
    return {
        "couvert": couvert,
        "type_juste": couvert and all(p["type"] == e["type"] for p in sur_id),
        "suite_avalee": any(touche(p, s["start"], s["end"]) for p in sur_id),
        "suite_masquee": any(touche(p, s["start"], s["end"]) for p in preds
                             if p not in sur_id),
        "types_predits": sorted({p["type"] for p in sur_id}),
    }


def mesure(corpus, pred):
    preds = {d["id"]: d for d in pred}
    total = collections.Counter()
    par_axe = {a: collections.defaultdict(collections.Counter) for a in AXES}
    confusions = collections.Counter()
    for doc in corpus:
        r = juge(doc, preds[doc["id"]])
        faute = not r["type_juste"] or r["suite_avalee"]
        total["documents"] += 1
        for k in ("couvert", "type_juste", "suite_avalee", "suite_masquee"):
            total[k] += r[k]
        total["en_defaut"] += faute
        for a in AXES:
            par_axe[a][doc[a]]["documents"] += 1
            par_axe[a][doc[a]]["en_defaut"] += faute
            par_axe[a][doc[a]]["non_couvert"] += not r["couvert"]
        if faute:
            vus = "+".join(r["types_predits"]) or "rien"
            confusions[(doc["type_id"], vus, doc["famille"],
                        doc["separateur"])] += 1
    return total, par_axe, confusions


def affiche(total, par_axe, confusions):
    n = total["documents"]
    print(f"identifiant suivi : {n} documents, {n - total['couvert']} "
          f"identifiant(s) non couvert(s), {n - total['type_juste']} type(s) "
          f"faux, {total['suite_avalee']} suite(s) avalée(s), "
          f"{total['en_defaut']} document(s) en défaut")
    print(f"  suite masquée par une autre détection : {total['suite_masquee']}")
    for a in AXES:
        for v in sorted(par_axe[a]):
            c = par_axe[a][v]
            print(f"  {a}={v} : {c['en_defaut']} / {c['documents']} en défaut, "
                  f"{c['non_couvert']} non couvert(s)")
    for (t, vus, fam, sep), k in sorted(confusions.items(),
                                        key=lambda x: (-x[1], x[0])):
        print(f"  défaut : {t} lu « {vus} », {fam}, {sep} : {k}")


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    args = ap.parse_args()
    affiche(*mesure(charge(args.corpus), charge(args.pred)))


if __name__ == "__main__":
    main()
