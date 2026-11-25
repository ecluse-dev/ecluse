#!/usr/bin/env python3
"""P2-285 (mesure) : établissements masqués dans des documents sans aucune
personne, par forme, et coût en établissements nommés manqués de chaque choix.
Rien n'est corrigé.

Entrées : un corpus sans donnée personnelle et ses prédictions (sortie de
`run_temoin_nombres_dictes.dart` : type, début, fin, jamais la valeur), puis des
corpus annotés (`flou` réaliste et adversarial) et leurs prédictions, avec le
code actuel (« base ») et avec la variante testée (« variante »).

Formes (d'après le texte de l'entité `etablissement`) :
  sigle + « à » + ville   un sigle d'établissement, « à », puis un mot en casse
                          de titre : « CHU à Lille », « SSIAD à Angers » ;
  sigle + nom             un sigle, puis des mots en casse de titre (autre que
                          « à ») : « EHPAD Les Tilleuls » ;
  type + mot générique    un type en toutes lettres, puis seulement des mots
                          d'une liste fermée (GENERIQUES) : « Résidence
                          Autonomie » ;
  type + nom              un type en toutes lettres, puis tout autre mot en
                          casse de titre : « Clinique Pasteur ».
« Sigle seul » (le mot-clé sans mot derrière) n'existe pas : le détecteur exige
un nom (`EtablissementDetector._pattern`) ; la ligne est imprimée à 0 pour le
dire.

Usage : python3 analyse_etablissement_sans_personne.py --sans-pii C P
        [--variante-sans-pii P2] --annotes NOM:C:P[:P2] ...
Seuls des nombres et des exemples synthétiques sont imprimés.
"""
import argparse
import json
import math
import os
import re
from collections import Counter

ICI = os.path.dirname(os.path.abspath(__file__))
DART = os.path.join(ICI, "..", "packages", "ecluse_redact", "lib", "src",
                    "heuristics", "etablissement_keywords.dart")
# Liste fermée de mots génériques derrière un type : ceux que le corpus sans
# personne produit (« Résidence Autonomie », « Foyer d'accueil médicalisé » en
# casse de titre). Aucun autre mot n'est supposé générique.
GENERIQUES = {"Autonomie", "D'accueil", "D’accueil", "Médicalisé", "Medicalise"}


def mots_cles():
    src = open(DART, encoding="utf-8").read()
    bloc = src.split("const List<String> etablissementKeywords = [")[1].split("];")[0]
    return re.findall(r"'([^']+)'|\"([^\"]+)\"", bloc)


def charge_mots_cles():
    ks = [a or b for a, b in mots_cles()]
    return sorted(ks, key=len, reverse=True)


KW = charge_mots_cles()


def est_sigle(k):
    return k.isupper() or k in ("IMPro",)


def forme(t):
    for k in KW:
        if t.startswith(k):
            reste = t[len(k):].split()
            if not reste:
                return "sigle seul"
            if est_sigle(k):
                if reste[0] == "à" and len(reste) == 2:
                    return "sigle + « à » + ville"
                return "sigle + nom"
            if all(m in GENERIQUES for m in reste):
                return "type + mot générique"
            return "type + nom"
    return "autre"


def wilson(k, n, z=1.959964):
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    m = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - m), min(1.0, c + m))


def lit(c, p):
    corpus = [json.loads(l) for l in open(c, encoding="utf-8") if l.strip()]
    pred = [json.loads(l) for l in open(p, encoding="utf-8") if l.strip()]
    if len(corpus) != len(pred):
        raise SystemExit("ÉCHEC : corpus et prédictions de longueurs différentes")
    return corpus, pred


FORMES = ["sigle seul", "sigle + « à » + ville", "sigle + nom",
          "type + mot générique", "type + nom", "autre"]


def sans_pii(c, p, titre):
    corpus, pred = lit(c, p)
    n = len(corpus)
    docs, ex = Counter(), {}
    autres = Counter()
    for d, pr in zip(corpus, pred):
        vus = set()
        for e in pr["entities"]:
            if e["type"] != "etablissement":
                autres[e["type"]] += 1
                continue
            f = forme(d["text"][e["start"]:e["end"]])
            vus.add(f)
            ex.setdefault(f, d["text"][e["start"]:e["end"]])
        for f in vus:
            docs[f] += 1
    total = sum(1 for pr in pred if any(e["type"] == "etablissement" for e in pr["entities"]))
    lo, hi = wilson(total, n)
    print(f"## {titre} : {n} documents, {total} avec un établissement masqué "
          f"({100 * total / n:.3f} %, IC 95 % [{100 * lo:.3f} ; {100 * hi:.3f}] %)")
    if autres:
        print("   autres types masqués :", dict(autres))
    for f in FORMES:
        k = docs[f]
        lo, hi = wilson(k, n)
        part = f"{100 * k / total:.1f} %" if total else "-"
        print(f"{f} : {k} / {n} documents ({100 * k / n:.3f} %, IC 95 % "
              f"[{100 * lo:.3f} ; {100 * hi:.3f}] %), {part} des documents à établissement"
              + (f" ; exemple synthétique : {ex[f]}" if f in ex else ""))
    return docs, total


def couvert(e, ivs):
    pos = e["start"]
    for s, f in ivs:
        if f <= pos:
            continue
        if s > pos:
            break
        pos = f
        if pos >= e["end"]:
            return True
    return False


def annotes(nom, c, p):
    """Établissements annotés : total, couverts en entier (toutes entités), par forme."""
    corpus, pred = lit(c, p)
    tot, cov, par_forme = 0, 0, Counter()
    for d, pr in zip(corpus, pred):
        ivs = sorted((x["start"], x["end"]) for x in pr["entities"])
        for e in d["entities"]:
            if e["type"] != "etablissement":
                continue
            tot += 1
            ok = couvert(e, ivs)
            cov += ok
            par_forme[forme(d["text"][e["start"]:e["end"]])] += 1
    return tot, cov, par_forme


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sans-pii", nargs=2, metavar=("CORPUS", "PRED"), required=True)
    ap.add_argument("--variante-sans-pii", metavar="PRED")
    ap.add_argument("--annotes", nargs="*", default=[],
                    help="NOM:CORPUS:PRED_BASE[:PRED_VARIANTE]")
    a = ap.parse_args()
    sans_pii(*a.sans_pii, "code actuel, documents sans personne")
    if a.variante_sans_pii:
        sans_pii(a.sans_pii[0], a.variante_sans_pii,
                 "variante (mot en casse de titre sans minuscule accentuée)")
    # Coût de chaque choix sur les corpus annotés.
    print("## établissements nommés des corpus annotés")
    for spec in a.annotes:
        nom, c, pb, *pv = spec.split(":")
        tot, cov, pf = annotes(nom, c, pb)
        ligne = (f"{nom} : {tot} établissements annotés, {cov} couverts en entier "
                 f"(code actuel) ; par forme : "
                 + ", ".join(f"{f} {pf[f]}" for f in FORMES if pf[f]))
        if pv:
            _, cov2, _ = annotes(nom, c, pv[0])
            ligne += f" ; variante : {cov2} couverts"
        print(ligne)


if __name__ == "__main__":
    main()
