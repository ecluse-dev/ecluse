#!/usr/bin/env python3
"""P2-293 (mesure, rien corrigé) : coût et gain des gardes de P2-288 sur l'IBAN
écrit en paires, par écriture.

Entrées : la sonde de `generate_sonde_iban_paires.py` et sa sortie par
`Ecluse.redact` (`run_redact_bench.dart --confiance`) ; en option, le témoin
élargi de P2-279 (5 000 documents sans entité annotée) et sa sortie.

Une garde (cinq, définies dans `mesure_gardes_iban_paires.py`, P2-288) n'autorise
le masquage de la séquence que si son prédicat de forme est vrai. Pour chaque
document dont la séquence est **déjà masquée comme `iban` en entier** par
`Ecluse.redact` :

  - positif (IBAN réel) : « perdu » si la garde refuse ;
  - négatif (référence, témoin élargi) : « évité » si la garde refuse.

Seuls des nombres sont imprimés.
"""
import argparse
import json
from collections import defaultdict

from mesure_gardes_iban_paires import GARDES, P, feats


def masque_iban(entites, debut, fin):
    return any(e["type"] == "iban" and e["start"] <= debut and e["end"] >= fin
               for e in entites)


def lit(chemin):
    return [json.loads(l) for l in open(chemin, encoding="utf-8")]


def sonde(corpus, pred):
    """Pour chaque document de la sonde : (document, séquence, masqué, traits)."""
    pred = {p["id"]: p for p in pred}
    res = []
    for d in corpus:
        m = P.search(d["text"])
        if m is None:
            res.append((d, None, False, None))
            continue
        ent = pred[d["id"]]["entities"]
        res.append((d, m, masque_iban(ent, m.start(), m.end()), feats(d["text"], m)))
    return res


def temoin(corpus, pred):
    pred = {p["id"]: p for p in pred}
    res = []
    for d in corpus:
        m = P.search(d["text"])
        if m is None:
            continue
        ent = pred[d["id"]]["entities"]
        if masque_iban(ent, m.start(), m.end()):
            res.append((d, m, feats(d["text"], m)))
    return res


def tableau(titre, lignes, cle, positif):
    """lignes : (doc, masqué, traits). Une ligne du tableau par valeur de `cle`."""
    groupes = defaultdict(list)
    for d, masque, f in lignes:
        groupes[cle(d, f)].append((masque, f))
    print(f"\n## {titre}")
    noms = list(GARDES)
    print("écriture".ljust(34) + "n".rjust(5) + "masqués".rjust(9)
          + "".join(f"{n[:1]:>9}" for n in noms))
    tot_n, tot_m, tot = 0, 0, [0] * len(noms)
    for k in sorted(groupes):
        g = groupes[k]
        masques = [f for m, f in g if m]
        refus = [sum(1 for f in masques if not GARDES[n](f)) for n in noms]
        print(str(k).ljust(34) + f"{len(g):5}{len(masques):9}"
              + "".join(f"{r:9}" for r in refus))
        tot_n += len(g)
        tot_m += len(masques)
        tot = [a + b for a, b in zip(tot, refus)]
    print("TOTAL".ljust(34) + f"{tot_n:5}{tot_m:9}" + "".join(f"{r:9}" for r in tot))
    mot = "perdus" if positif else "évités"
    print(f"(colonnes A à E = garde refusant le masquage : {mot} sur les masqués)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    ap.add_argument("--temoin")
    ap.add_argument("--pred-temoin")
    a = ap.parse_args()
    docs = sonde(lit(a.corpus), lit(a.pred))
    print("Gardes :")
    for n in GARDES:
        print(" ", n)
    sans_forme = sum(1 for _, m, _, _ in docs if m is None)
    print(f"documents de la sonde hors de la forme paires : {sans_forme}")
    pos = [(d, mq, f) for d, m, mq, f in docs if m and d["famille"] != "reference"]
    neg = [(d, mq, f) for d, m, mq, f in docs if m and d["famille"] == "reference"]
    tableau("Positifs : IBAN en paires, par clé, séparateur et corps", pos,
            lambda d, f: f"{d['famille'][5:]:11} {d['sep']:7} {d['corps']}", True)
    tableau("Positifs : par phrase (mot bancaire ou non)", pos,
            lambda d, f: d["phrase"], True)
    tableau("Positifs : par présence réelle d'une lettre dans le corps", pos,
            lambda d, f: "corps avec lettre" if f["lettres"] else "corps sans lettre",
            True)
    tableau("Négatifs : références en paires, par séparateur et corps", neg,
            lambda d, f: f"{d['sep']:7} {d['corps']}", False)
    if a.temoin:
        t = temoin(lit(a.temoin), lit(a.pred_temoin))
        print(f"\n## Témoin élargi de P2-279 : documents où `Ecluse.redact` masque une "
              f"séquence en paires comme iban : {len(t)}")
        tableau("Témoin élargi : par séparateur", [(d, True, f) for d, m, f in t],
                lambda d, f: {" ": "espace", ".": "point", "-": "tiret",
                              "/": "barre"}[f["sep"]], False)


if __name__ == "__main__":
    main()
