#!/usr/bin/env python3
"""Scoreur du corpus « identifiant annoncé par un libellé fort » (P2-194).

Les prédictions sont au format de `run_redact_bench.dart` : **`Ecluse.redact`**,
donc ce que reçoit le LLM, et non le moteur seul.

Positifs (un identifiant annoté derrière son libellé) :
- `en_clair` : au moins un caractère de l'identifiant (hors blancs) n'est
  sous aucune détection, quel qu'en soit le type. C'est une fuite ;
- `type_faux` : couvert, mais une détection qui touche l'identifiant porte un
  autre type que celui annoté (compté à part, rien ne fuit).

Négatifs (aucune entité annotée) : chaque prédiction est un masquage de trop,
compté par forme de négatif (`libelle_seul`, `non_communique`,
`mot_ordinaire`, `nombre_sans_libelle`).

Sortie : une ligne de synthèse, une ligne par libellé et par variante, un
total par variante, un total par libellé, un total par forme de négatif.
Le plafond de positifs en clair (zéro, sauf défaut connu) est vérifié par
`verifie_etat.py` d'après `etat_attendu.PLAFOND_LIBELLE_FORT`, pas ici.

Usage :
    python3 score_libelle_fort.py --corpus c.jsonl --pred p.jsonl 
"""

import argparse
import collections
import json

def juge_positif(doc, pred):
    texte = doc["text"]
    e = doc["entities"][0]
    preds = pred.get("entities", [])
    couverts = set()
    for p in preds:
        couverts.update(range(p["start"], p["end"]))
    utiles = [i for i in range(e["start"], e["end"]) if not texte[i].isspace()]
    en_clair = any(i not in couverts for i in utiles)
    sur_id = [p for p in preds if p["start"] < e["end"] and e["start"] < p["end"]]
    type_faux = (not en_clair) and any(p["type"] != e["type"] for p in sur_id)
    return en_clair, type_faux


def mesure(corpus, pred):
    preds = {d["id"]: d for d in pred}
    par_case = collections.defaultdict(collections.Counter)
    par_variante = collections.defaultdict(collections.Counter)
    par_libelle = collections.defaultdict(collections.Counter)
    negatifs = collections.defaultdict(collections.Counter)
    total = collections.Counter()
    for doc in corpus:
        p = preds[doc["id"]]
        if doc["entities"]:
            en_clair, type_faux = juge_positif(doc, p)
            for c in (par_case[(doc["libelle"], doc["variante"])],
                      par_variante[doc["variante"]],
                      par_libelle[doc["libelle"]], total):
                c["positifs"] += 1
                c["en_clair"] += en_clair
                c["type_faux"] += type_faux
        else:
            masques = len(p.get("entities", []))
            for c in (negatifs[doc["temoin_negatif"]],
                      negatifs[("libelle", doc["libelle"])]):
                c["documents"] += 1
                c["masques"] += masques > 0
                c["predictions"] += masques
            total["negatifs"] += 1
            total["negatifs_masques"] += masques > 0
            total["predictions_negatifs"] += masques
    return par_case, par_variante, par_libelle, negatifs, total


def affiche(corpus, resultats):
    par_case, par_variante, par_libelle, negatifs, total = resultats
    print(f"libellé fort : {total['positifs']} identifiants positifs, "
          f"{total['en_clair']} en clair, {total['type_faux']} au type "
          f"faux ; {total['negatifs']} documents témoins, "
          f"{total['negatifs_masques']} masqués à tort "
          f"({total['predictions_negatifs']} prédiction(s))")
    variantes = []
    for d in corpus:
        if d["entities"] and d["variante"] not in variantes:
            variantes.append(d["variante"])
    libelles = []
    for d in corpus:
        if d["entities"] and d["libelle"] not in libelles:
            libelles.append(d["libelle"])
    for v in variantes:
        c = par_variante[v]
        print(f"  variante={v} : {c['en_clair']} / {c['positifs']} en clair, "
              f"{c['type_faux']} au type faux")
    for lib in libelles:
        c = par_libelle[lib]
        print(f"  libellé={lib} : {c['en_clair']} / {c['positifs']} en clair, "
              f"{c['type_faux']} au type faux")
    for lib in libelles:
        for v in variantes:
            c = par_case[(lib, v)]
            print(f"  {lib} x {v} : {c['en_clair']} / {c['positifs']} en "
                  f"clair, {c['type_faux']} au type faux")
    for kind in ("libelle_seul", "non_communique", "mot_ordinaire",
                 "nombre_sans_libelle"):
        c = negatifs[kind]
        print(f"  témoin négatif={kind} : {c['masques']} / {c['documents']} "
              f"masqués à tort ({c['predictions']} prédiction(s))")
    for lib in libelles:
        c = negatifs[("libelle", lib)]
        print(f"  témoin négatif, libellé={lib} : {c['masques']} / "
              f"{c['documents']} masqués à tort")


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    args = ap.parse_args()
    corpus = charge(args.corpus)
    affiche(corpus, mesure(corpus, charge(args.pred)))


if __name__ == "__main__":
    main()
