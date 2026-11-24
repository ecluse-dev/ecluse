#!/usr/bin/env python3
"""P2-290 (mesure) : établissements annotés et masquages à tort, par variante de
casse et de mise en page, avant et après P2-289. Rien n'est corrigé.

Entrées : des triplets `NOM:CORPUS:PRED_AVANT:PRED_APRES` (corpus JSONL annoté,
prédictions de `run_redact_bench.dart` : type et bornes, jamais la valeur ;
un document refusé (tableau ambigu) n'envoie rien : il est compté à part et
retiré des deux côtés). Chemin mesuré : `Ecluse.redact`, jamais le moteur seul.

Définitions (par entité `etablissement` annotée) :
  couvert       toute entité masquée, de tout type, couvre l'annotation en entier
                (union d'intervalles) : rien de l'établissement ne part en clair ;
  bornes exactes une entité `etablissement` a exactement les bornes annotées ;
  à tort        entité `etablissement` prédite qui ne chevauche aucun
                établissement annoté (comptée en entités et en documents).
Seuls des nombres sont imprimés.
"""
import json
import sys


def lit(chemin):
    return [json.loads(l) for l in open(chemin, encoding="utf-8") if l.strip()]


def couvert(a, ivs):
    pos = a[0]
    for s, f in ivs:
        if f <= pos:
            continue
        if s > pos:
            break
        pos = f
        if pos >= a[1]:
            return True
    return False


def mesure(corpus, pred):
    if len(corpus) != len(pred):
        raise SystemExit("ÉCHEC : corpus et prédictions de longueurs différentes")
    tot = cov = exact = tort = docs_tort = refus = 0
    for d, p in zip(corpus, pred):
        if p.get("refuse"):
            refus += 1
            continue
        ann = [(e["start"], e["end"]) for e in d["entities"]
               if e["type"] == "etablissement"]
        ivs = sorted((e["start"], e["end"]) for e in p["entities"])
        etab = [(e["start"], e["end"]) for e in p["entities"]
                if e["type"] == "etablissement"]
        for a in ann:
            tot += 1
            cov += couvert(a, ivs)
            exact += a in etab
        t = [x for x in etab if not any(x[0] < a[1] and a[0] < x[1] for a in ann)]
        tort += len(t)
        docs_tort += bool(t)
    return tot, cov, exact, tort, docs_tort, refus


def ecarts(corpus, pred):
    """Pour les annotés sans bornes exactes : l'entité `etablissement` qui les
    chevauche est plus longue (débord), plus courte (reste en clair ou couvert
    par une autre entité), ou aucune entité `etablissement` ne les touche."""
    r = {"débord": 0, "plus courte": 0, "décalée": 0, "aucune entité établissement": 0}
    for d, p in zip(corpus, pred):
        if p.get("refuse"):
            continue
        etab = [(e["start"], e["end"]) for e in p["entities"]
                if e["type"] == "etablissement"]
        for e in d["entities"]:
            if e["type"] != "etablissement":
                continue
            a = (e["start"], e["end"])
            if a in etab:
                continue
            ch = [x for x in etab if x[0] < a[1] and a[0] < x[1]]
            if not ch:
                r["aucune entité établissement"] += 1
            elif any(x[0] <= a[0] and x[1] >= a[1] for x in ch):
                r["débord"] += 1
            elif all(x[0] >= a[0] and x[1] <= a[1] for x in ch):
                r["plus courte"] += 1
            else:
                r["décalée"] += 1
    return r


def main():
    ecart_lignes = []
    print("| Corpus / variante | annotés | couverts avant → après | "
          "bornes exactes avant → après | à tort (entités) avant → après | "
          "documents à tort avant → après | documents | refus avant → après |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|")
    for spec in sys.argv[1:]:
        nom, c, pa, pb = spec.split("|")
        corpus = lit(c)
        a = mesure(corpus, lit(pa))
        b = mesure(corpus, lit(pb))
        if a[0]:
            ecart_lignes.append((nom, ecarts(corpus, lit(pa)), ecarts(corpus, lit(pb))))
        print(f"| {nom} | {a[0]} | {a[1]} → {b[1]} | {a[2]} → {b[2]} | "
              f"{a[3]} → {b[3]} | {a[4]} → {b[4]} | {len(corpus)} | {a[5]} → {b[5]} |")

    print()
    print("Annotés sans bornes exactes, par nature d'écart (avant → après) :")
    print("| Corpus / variante | débord | plus courte | décalée | aucune entité établissement |")
    print("|---|---:|---:|---:|---:|")
    for nom, x, y in ecart_lignes:
        print(f"| {nom} | " + " | ".join(f"{x[k]} → {y[k]}" for k in x) + " |")


main()
