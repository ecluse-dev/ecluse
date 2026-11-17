#!/usr/bin/env python3
"""SIREN masqués comme FINESS, et options chiffrées hors `lib/` (P2-223).

Prédictions au format de `run_redact_bench.dart --confiance` : **`Ecluse.redact`**
(ce que reçoit le LLM), avec la confiance de chaque détection. Mesure seule,
rien n'est corrigé : les options sont des **filtres appliqués ici aux
prédictions**, pour compter ce qu'une règle gagnerait (SIREN en moins) et ce
qu'elle coûterait (vrais FINESS qui repartiraient en clair).

Trois jeux :
- corpus v3 entier (`generate_corpus.py`) : les SIREN pièges sont les nombres
  de neuf chiffres à clé de Luhn valide non annotés (écriture collée ou 3-3-3) ;
  les vrais FINESS sont les entités annotées `finess` ;
- témoin SIREN (`generate_corpus_siren.py`, champ `siren`) ;
- pendant FINESS (même générateur, entité annotée `finess`).

Un SIREN est « masqué comme FINESS » si une détection de type `finess` le
recouvre. Un FINESS est « en clair » si au moins un de ses chiffres n'est sous
aucune détection restante. Options (une règle de filtre sur les détections
`finess`) :

- `libelle_immediat` : « SIREN » ou « SIRET » (avec « n° », « numéro », « : »
  éventuels) juste avant le nombre ;
- `libelle_40` : « SIREN » ou « SIRET » dans les 40 caractères avant le nombre
  (même fenêtre que le mot-clé du détecteur) ;
- `libelle_40_sans_mot_finess` : comme `libelle_40`, mais seulement pour les
  détections à confiance basse (sans le mot « FINESS » à proximité) : un FINESS
  annoncé par son mot n'est jamais retiré ;
- `contexte_exige` : seules les détections à confiance haute (mot « FINESS »
  à proximité) sont gardées ;
- `prefixe` : les deux premiers chiffres doivent être un département (01 à 95,
  97, 98) ;
- `luhn` : clé de Luhn du SIREN : même algorithme que le FINESS, sans effet
  (comptage de contrôle, pas un filtre).

N'imprime que des comptes, jamais un texte.

Usage :
    python3 score_siren_finess.py --v3 c.jsonl p.jsonl --siren c.jsonl p.jsonl \\
        --finess c.jsonl p.jsonl
"""

import argparse
import collections
import json
import re

NEUF = re.compile(r"(?<![0-9])(?:[0-9]{9}|[0-9]{3} [0-9]{3} [0-9]{3})(?![0-9])")
LIBELLE_IMMEDIAT = re.compile(
    r"(siren|siret)\s*(?:n°|no\.?|numéro)?\s*:?\s*$", re.I)
DEPARTEMENTS = {f"{d:02d}" for d in range(1, 96)} | {"97", "98"}
HAUTE = 0.9


def charge(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def luhn(chiffres):
    s, double = 0, False
    for c in reversed(chiffres):
        v = int(c)
        if double:
            v = v * 2 - 9 if v * 2 > 9 else v * 2
        s += v
        double = not double
    return s % 10 == 0


def chiffres(texte, debut, fin):
    return re.sub(r"\D", "", texte[debut:fin])


def sirens_v3(doc):
    """Nombres de neuf chiffres à clé valide, hors entités annotées."""
    gold = set()
    for g in doc["entities"]:
        gold.update(range(g["start"], g["end"]))
    sortie = []
    for m in NEUF.finditer(doc["text"]):
        if any(i in gold for i in range(m.start(), m.end())):
            continue
        if luhn(chiffres(doc["text"], m.start(), m.end())):
            sortie.append((m.start(), m.end()))
    return sortie


def garde(option, doc, p):
    """Vrai si la détection finess `p` reste sous l'option."""
    if option == "base":
        return True
    texte = doc["text"]
    if option == "libelle_immediat":
        return not LIBELLE_IMMEDIAT.search(texte[max(0, p["start"] - 30):p["start"]])
    if option == "libelle_40":
        avant = texte[max(0, p["start"] - 40):p["start"]].lower()
        return "siren" not in avant and "siret" not in avant
    if option == "libelle_40_sans_mot_finess":
        return (p.get("confidence", 1.0) >= HAUTE
                or garde("libelle_40", doc, p))
    if option == "contexte_exige":
        return p.get("confidence", 1.0) >= HAUTE
    if option == "prefixe":
        return chiffres(texte, p["start"], p["end"])[:2] in DEPARTEMENTS
    raise ValueError(option)


OPTIONS = ["base", "libelle_immediat", "libelle_40",
           "libelle_40_sans_mot_finess", "contexte_exige", "prefixe"]


def detections_restantes(option, doc, pred):
    return [p for p in pred.get("entities", [])
            if p["type"] != "finess" or garde(option, doc, p)]


def couverts(preds):
    s = set()
    for p in preds:
        s.update(range(p["start"], p["end"]))
    return s


def compte(option, corpus, preds, pieges, vrais):
    """(SIREN masqués comme FINESS, SIREN au total, FINESS en clair, FINESS)."""
    masques = total = en_clair = nb_finess = 0
    for doc in corpus:
        rest = detections_restantes(option, doc, preds[doc["id"]])
        fin = [p for p in rest if p["type"] == "finess"]
        cov = couverts(rest)
        for a, b in pieges(doc):
            total += 1
            masques += any(p["start"] < b and a < p["end"] for p in fin)
        for a, b in vrais(doc):
            nb_finess += 1
            en_clair += any(i not in cov for i in range(a, b)
                            if not doc["text"][i].isspace())
    return masques, total, en_clair, nb_finess


def vrais_annotes(doc):
    return [(g["start"], g["end"]) for g in doc["entities"]
            if g["type"] == "finess"]


def pieges_champ(cle):
    def f(doc):
        return [(doc[cle]["start"], doc[cle]["end"])] if cle in doc else []
    return f


def par_axe(corpus, preds, axe, cle_piege):
    res = collections.defaultdict(lambda: [0, 0])
    for doc in corpus:
        cov = [p for p in preds[doc["id"]].get("entities", [])
               if p["type"] == "finess"]
        a, b = doc[cle_piege]["start"], doc[cle_piege]["end"]
        res[doc[axe]][1] += 1
        res[doc[axe]][0] += any(p["start"] < b and a < p["end"] for p in cov)
    return res


def mesure(v3, siren, finess):
    sorties = {}
    jeux = {
        "v3": (v3, sirens_v3, vrais_annotes),
        "siren": (siren, pieges_champ("siren"), vrais_annotes),
        "finess": (finess, pieges_champ("siren_voisin"), vrais_annotes),
    }
    for nom, (jd, pieges, vrais) in jeux.items():
        corpus, preds = jd
        sorties[nom] = {o: compte(o, corpus, preds, pieges, vrais)
                        for o in OPTIONS}
    return sorties


def affiche(res, siren, preds_siren, v3):
    b = res["v3"]["base"]
    s = res["siren"]["base"]
    f = res["finess"]["base"]
    print(f"SIREN masqués comme FINESS : corpus v3 entier {b[0]} / {b[1]} "
          f"nombres à clé valide non annotés, témoin SIREN {s[0]} / {s[1]}, "
          f"SIREN voisins du pendant FINESS {f[0]} / {f[1]}")
    print(f"vrais FINESS en clair sans option : corpus v3 {b[2]} / {b[3]}, "
          f"pendant FINESS {f[2]} / {f[3]}")
    for axe in ("libelle", "ecriture"):
        for v, (m, t) in sorted(par_axe(siren, preds_siren, axe,
                                        "siren").items()):
            print(f"  témoin {axe}={v} : {m} / {t} masqués comme FINESS")
    for o in OPTIONS[1:]:
        v, si, fi = res["v3"][o], res["siren"][o], res["finess"][o]
        print(f"  option={o} : SIREN masqués v3 {v[0]} / {v[1]}, témoin "
              f"{si[0]} / {si[1]}, voisins {fi[0]} / {fi[1]} ; vrais FINESS "
              f"perdus en plus (en clair) v3 {v[2] - b[2]} / {b[3]}, "
              f"pendant {fi[2] - f[2]} / {f[3]}")
    couvert = 0
    for d in siren:
        cov = couverts(preds_siren[d["id"]].get("entities", []))
        couvert += all(i in cov for i in range(d["siren"]["start"],
                                               d["siren"]["end"])
                       if not d["text"][i].isspace())
    print(f"  témoin : SIREN sous une détection de n'importe quel type "
          f"{couvert} / {len(siren)} (le reste est lu comme FINESS ou "
          f"comme un autre type, p. ex. une plaque après « immatriculation »)")
    valides = sum(luhn(chiffres(d["text"], d["siren"]["start"],
                                d["siren"]["end"])) for d in siren)
    print(f"  option=luhn : SIREN du témoin valides à la clé du FINESS "
          f"{valides} / {len(siren)} : aucune distinction possible")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for nom in ("v3", "siren", "finess"):
        ap.add_argument(f"--{nom}", nargs=2, required=True,
                        metavar=("CORPUS", "PRED"))
    a = ap.parse_args()
    jeux = {}
    for nom in ("v3", "siren", "finess"):
        corpus = charge(getattr(a, nom)[0])
        preds = {p["id"]: p for p in charge(getattr(a, nom)[1])}
        jeux[nom] = (corpus, preds)
    res = mesure(jeux["v3"], jeux["siren"], jeux["finess"])
    affiche(res, jeux["siren"][0], jeux["siren"][1], jeux["v3"][0])


if __name__ == "__main__":
    main()
