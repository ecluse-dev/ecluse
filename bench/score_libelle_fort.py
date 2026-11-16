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


def format_confiance(compteur):
    """« 0.3=12, 1.0=288 » : valeurs triées, « aucune » en dernier."""
    clefs = sorted(k for k in compteur if k != "aucune")
    morceaux = [f"{k}={compteur[k]}" for k in clefs]
    if compteur.get("aucune"):
        morceaux.append(f"aucune={compteur['aucune']}")
    return ", ".join(morceaux) if morceaux else "(rien)"


def confiance(corpus, pred):
    """P2-203 : répartition des confiances et de l'avertissement « à vérifier ».

    N'a de sens que si les prédictions portent `confidence` et `a_verifier`
    (`run_redact_bench.dart --confiance`) ; sinon rend None. Pour un positif,
    la confiance retenue est la plus haute parmi les détections qui touchent
    l'identifiant annoté (« aucune » si rien ne le touche). Pour un négatif, la
    confiance de chaque détection prédite à tort. Aucun texte ni valeur.
    """
    preds = {d["id"]: d for d in pred}
    if not any("a_verifier" in p for p in preds.values()):
        return None
    pos = collections.defaultdict(collections.Counter)
    neg = collections.Counter()
    verif = collections.defaultdict(collections.Counter)
    incoherent = collections.Counter()
    for doc in corpus:
        p = preds[doc["id"]]
        ents = p.get("entities", [])
        a_verifier = bool(p.get("a_verifier"))
        a_basse = any(abs(e.get("confidence", 1.0) - 0.3) < 1e-9
                      for e in ents)
        if doc["entities"]:
            e0 = doc["entities"][0]
            touche = [x for x in ents
                      if x["start"] < e0["end"] and e0["start"] < x["end"]]
            cle = (f"{max(x['confidence'] for x in touche):g}"
                   if touche else "aucune")
            for groupe in (doc["variante"], "total"):
                pos[groupe][cle] += 1
                verif[groupe]["documents"] += 1
                verif[groupe]["a_verifier"] += a_verifier
            # P2-204 : un ADELI à clé fausse est masqué à confiance 0,6
            # (inchangée, LIMITES § 2) mais porte l'avertissement. Exception
            # connue, comptée à part au lieu de gonfler l'incohérence.
            exception = (e0["type"] == "adeli" and a_verifier
                         and not a_basse and cle == "0.6"
                         and doc["variante"] == "cle_fausse")
            if exception:
                incoherent["exception_adeli"] += 1
            else:
                incoherent["positifs"] += a_verifier != a_basse
        else:
            for x in ents:
                neg[f"{x['confidence']:g}"] += 1
            verif["negatifs"]["documents"] += 1
            verif["negatifs"]["a_verifier"] += a_verifier
            incoherent["negatifs"] += a_verifier != a_basse
    return pos, neg, verif, incoherent


def affiche_confiance(corpus, resultat):
    pos, neg, verif, incoherent = resultat
    print("confiance des masquages (chemin : Ecluse.redact) :")
    variantes = []
    for d in corpus:
        if d["entities"] and d["variante"] not in variantes:
            variantes.append(d["variante"])
    print(f"  confiance positifs : {format_confiance(pos['total'])}")
    for v in variantes:
        print(f"  confiance variante={v} : {format_confiance(pos[v])}")
    print(f"  confiance détections des négatifs : {format_confiance(neg)}")
    t, n = verif["total"], verif["negatifs"]
    print(f"  avertissement à vérifier : positifs {t['a_verifier']} / "
          f"{t['documents']}, négatifs {n['a_verifier']} / {n['documents']}")
    for v in variantes:
        c = verif[v]
        print(f"  à vérifier variante={v} : {c['a_verifier']} / "
              f"{c['documents']}")
    print(f"  incohérence confiance 0.3 / avertissement : positifs "
          f"{incoherent['positifs']}, négatifs {incoherent['negatifs']}")
    print(f"  exception P2-204 (ADELI clé fausse, confiance 0.6, avec "
          f"avertissement) : positifs {incoherent['exception_adeli']}")


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--pred", required=True)
    args = ap.parse_args()
    corpus = charge(args.corpus)
    pred = charge(args.pred)
    affiche(corpus, mesure(corpus, pred))
    c = confiance(corpus, pred)
    if c is not None:
        affiche_confiance(corpus, c)


if __name__ == "__main__":
    main()
