#!/usr/bin/env python3
"""P2-295 (spec) : options pour « type + mot générique » (« Résidence
Autonomie »), mesurées par `Ecluse.redact` (`run_redact_bench.dart`).

Entrée : le dossier de travail de `mesure_type_mot_generique.sh` (corpus et
prédictions `pred_<variante>_<corpus>.jsonl`). Variantes : base (code actuel),
generiques, nomprop (patch du détecteur) et `referentiel`, **simulée hors ligne**
sur les entités de la base : une entité « type en toutes lettres + nom » n'est
conservée que si un mot du nom est un prénom, un patronyme ou une commune connus
du référentiel (assets d'`ecluse_reference`) ; elle ne mesure pas l'effet sur les
autres détecteurs. Seuls des nombres et des exemples synthétiques sont imprimés.
"""
import argparse
import glob
import gzip
import json
import os
import re
import sys
import unicodedata
from collections import Counter

from analyse_etablissement_sans_personne import couvert, forme

ICI = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets")
VARIANTES = ["base", "generiques", "nomprop", "referentiel"]


def norme(m):
    m = unicodedata.normalize("NFD", m.upper())
    m = "".join(c for c in m if unicodedata.category(c) != "Mn")
    return re.sub(r"[^A-Z0-9]+", " ", m).strip()


def charge_referentiel():
    mots = set()
    for l in gzip.open(f"{ASSETS}/first_names.txt.gz", "rt", encoding="utf-8"):
        mots.add(norme(l))
    for l in gzip.open(f"{ASSETS}/patronymes_effectifs.tsv.gz", "rt", encoding="utf-8"):
        if not l.startswith("#"):
            mots.add(norme(l.split("\t")[0]))
    for i, l in enumerate(gzip.open(f"{ASSETS}/geo_communes.csv.gz", "rt", encoding="utf-8")):
        if i:
            mots.add(norme(l.split(";")[4]))
    mots.discard("")
    return mots


REF = None


def garde_referentiel(texte):
    """Vrai si l'entité (texte) est conservée par l'option « nom propre connu »."""
    global REF
    if REF is None:
        REF = charge_referentiel()
    f = forme(texte)
    if f in ("sigle + nom", "sigle + « à » + ville", "sigle seul"):
        return True
    from analyse_etablissement_sans_personne import KW
    for k in KW:
        if texte.startswith(k):
            reste = texte[len(k):]
            break
    else:
        return True
    return any(norme(m) in REF for m in re.split(r"[ \t]+", reste) if m)


def lit(chemin):
    return [json.loads(l) for l in open(chemin, encoding="utf-8") if l.strip()]


def preds(w, variante, nom, corpus):
    """Prédictions d'une variante ; `referentiel` est dérivée de la base."""
    if variante != "referentiel":
        return lit(f"{w}/pred_{variante}_{nom}.jsonl")
    base = lit(f"{w}/pred_base_{nom}.jsonl")
    sortie = []
    for d, p in zip(corpus, base):
        ents = [e for e in p["entities"]
                if e["type"] != "etablissement"
                or garde_referentiel(d["text"][e["start"]:e["end"]])]
        sortie.append({**p, "entities": ents})
    return sortie


def corpus_de(w, nom):
    for chemin in (f"{w}/{nom}.jsonl", f"{w}/flou/corpus_flou_{nom}.jsonl"):
        if os.path.exists(chemin):
            return lit(chemin)
    sys.exit(f"corpus introuvable : {nom}")


def docs_a_etablissement(corpus, pred):
    return sum(1 for p in pred if any(e["type"] == "etablissement" for e in p["entities"]))


def annotes(corpus, pred):
    tot = cov = exact = 0
    for d, p in zip(corpus, pred):
        if p.get("refuse"):
            continue
        ivs = sorted((e["start"], e["end"]) for e in p["entities"])
        etabs = {(e["start"], e["end"]) for e in p["entities"] if e["type"] == "etablissement"}
        for e in d["entities"]:
            if e["type"] != "etablissement":
                continue
            tot += 1
            cov += couvert(e, ivs)
            exact += (e["start"], e["end"]) in etabs
    return tot, cov, exact


def autres_types(base, var):
    """Documents où une entité d'un autre type apparaît ou disparaît."""
    n = 0
    for b, v in zip(base, var):
        sb = {(e["type"], e["start"], e["end"]) for e in b["entities"] if e["type"] != "etablissement"}
        sv = {(e["type"], e["start"], e["end"]) for e in v["entities"] if e["type"] != "etablissement"}
        n += sb != sv
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dossier")
    ap.add_argument("--total-sans-personne", type=int, default=200000)
    a = ap.parse_args()
    w = a.dossier
    # 1. Documents sans personne
    c = corpus_de(w, "sanspii_filtre")
    base = preds(w, "base", "sanspii", c)
    print(f"## Documents sans personne ({a.total_sans_personne} ; {len(c)} retenus, les autres "
          "ne peuvent produire aucune entité établissement)")
    for v in VARIANTES:
        p = preds(w, v, "sanspii", c)
        k = docs_a_etablissement(c, p)
        formes = Counter()
        for d, x in zip(c, p):
            for f in {forme(d["text"][e["start"]:e["end"]]) for e in x["entities"]
                      if e["type"] == "etablissement"}:
                formes[f] += 1
        print(f"{v:12} masqués à tort : {k} / {a.total_sans_personne} "
              f"({100 * k / a.total_sans_personne:.3f} %) ; "
              + ", ".join(f"{f} {n}" for f, n in sorted(formes.items()))
              + f" ; documents où un autre type change : {autres_types(base, p)}")
    # 2. Témoin 480, corpus principal
    for nom, titre in (("temoin480", "Témoin de 480 documents"), ("principal", "Corpus principal (v3, 1000)")):
        c = corpus_de(w, nom)
        print(f"## {titre} : documents avec un établissement masqué (aucun annoté)")
        for v in VARIANTES:
            p = preds(w, v, nom, c)
            print(f"{v:12} {docs_a_etablissement(c, p)} / {len(c)}")
    # 3. Annotés
    print("## Établissements annotés (réaliste, adversarial) : couverts en entier / bornes exactes / à tort")
    tot = {v: [0, 0, 0, 0] for v in VARIANTES}
    for corp in ("realiste", "adversarial"):
        for suf in ("", "_minuscules", "_majuscules", "_phrase", "_mixte", "_l60", "_l90"):
            nom = corp + suf
            c = corpus_de(w, nom)
            ligne = f"{nom:24}"
            for v in VARIANTES:
                p = preds(w, v, nom, c)
                t, cov, ex = annotes(c, p)
                tort = sum(1 for d, x in zip(c, p) for e in x["entities"]
                           if e["type"] == "etablissement"
                           and not any(f["type"] == "etablissement" and f["start"] < e["end"]
                                       and f["end"] > e["start"] for f in d["entities"]))
                ligne += f" | {v}: {cov}/{t} {ex} {tort}"
                for i, x in enumerate((t, cov, ex, tort)):
                    tot[v][i] += x
            print(ligne)
    print("TOTAL (annotés, couverts, bornes exactes, à tort) :")
    for v in VARIANTES:
        print(f"{v:12} {tot[v]}")
    # 4. Établissements annotés perdus, par exemple synthétique
    print("## Annotés non couverts par une variante mais couverts par la base (exemples)")
    for v in VARIANTES[1:]:
        vus = Counter()
        for corp in ("realiste", "adversarial"):
            c = corpus_de(w, corp)
            pb, pv = preds(w, "base", corp, c), preds(w, v, corp, c)
            for d, b, x in zip(c, pb, pv):
                ivb = sorted((e["start"], e["end"]) for e in b["entities"])
                ivv = sorted((e["start"], e["end"]) for e in x["entities"])
                for e in d["entities"]:
                    if e["type"] == "etablissement" and couvert(e, ivb) and not couvert(e, ivv):
                        vus[d["text"][e["start"]:e["end"]]] += 1
        print(f"{v:12} {sum(vus.values())} perdus ; {dict(vus.most_common(6))}")


if __name__ == "__main__":
    main()
