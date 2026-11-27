#!/usr/bin/env python3
"""P2-314 (mesure) : réduire le bruit de l'avertissement des homonymes en texte
tout en minuscules, **sans rendre silencieux un seul homonyme en casse ordinaire**.
Rien n'est corrigé : `lib/` n'est pas modifié ; les options sont des filtres
appliqués ici aux avertissements que `Ecluse.redact` produit déjà (chemin du
produit, par `packages/ecluse_redact/bin/run_gardes_avertissements.dart`).

Contexte (P2-310) : `NameDetector.homonymesEcartes` signale un mot que les listes
d'exclusion laissent en clair là où un nom était attendu. Trois chemins :
civilité + statut, « le dossier de » + mot, et **prénom connu en minuscules +
mot** (« sophie rappelle »). Seul le troisième peut se déclencher dans un texte
sans majuscule ; il est la source du bruit (240 documents sur 1 280 de la sonde
prénom + verbe de P2-240, en minuscules ; 0 en casse ordinaire).

Deux commandes :

  prepare DOSSIER : écrit les corpus de la mesure (graine fixe) :
      pv            sonde prénom + verbe de P2-240, casse ordinaire (1 280 documents)
      pv_min        la même, entièrement en minuscules
      sonde         sonde d'homonymes de P2-308, toutes tournures
      sonde_min     la même, entièrement en minuscules
      v3_min        corpus v3 du banc (`bench/corpus.jsonl`), en minuscules
  analyse DOSSIER : lit corpus + prédictions (`pred_<nom>.jsonl`) et imprime, par
      option, les documents avertis et les homonymes signalés. Que des comptes.

Options évaluées (une position d'avertissement du chemin « prénom en minuscules
+ mot » est gardée ou retirée ; les deux autres chemins ne sont jamais touchés) :

  base        état actuel
  O1(T)       garder si le patronyme a au moins T naissances (INSEE 1891-2000)
  O2          un seul avertissement groupé par document : déjà le cas
              (`Ecluse.redact` rend un avertissement par document, avec compte et
              positions) ; aucun effet, vérifié ci-dessous
  O3          retirer l'avertissement par mot en texte sans aucune majuscule et
              le remplacer par un avertissement général « texte sans majuscule :
              noms moins bien repérés », émis pour tout document sans majuscule
  O4(S)       garder si le prénom qui précède a au moins S naissances (INSEE, prénom
              « confirmé »)
  O5          retirer si le mot est une forme verbale attestée (lexique
              `formes_verbales.txt.gz`) : rend ces homonymes silencieux en minuscules
"""
import gzip
import json
import os
import re
import sys
from collections import Counter

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "bench"))
import listes_exclusion as L  # noqa: E402

PRENOMS_TSV = os.path.join(RACINE, "packages/ecluse_reference/assets/first_names_effectifs.tsv.gz")
FORMES = os.path.join(RACINE, "packages/ecluse_lexique/assets/formes_verbales.txt.gz")
HOMONYME = re.compile(r"mot pris pour un nom commun")
POSITIONS = re.compile(r"position[s]? ([0-9, …]+)\)")
MOT = re.compile(r"[\wÀ-ÿ'’-]+")
CORPUS = ["pv", "pv_min", "sonde", "sonde_min", "v3_min"]


def minuscules(doc):
    bas = dict(doc)
    bas["text"] = doc["text"].lower()
    if len(bas["text"]) != len(doc["text"]):
        raise SystemExit("longueur changée : les positions ne vaudraient plus")
    return bas


def ecrit(chemin, docs):
    with open(chemin, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")


def lit(chemin):
    with open(chemin, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def prepare(dossier):
    os.makedirs(dossier, exist_ok=True)
    pv = lit(os.path.join(dossier, "pv.jsonl"))  # produit par le script shell
    ecrit(os.path.join(dossier, "pv_min.jsonl"), [minuscules(d) for d in pv])
    sonde = lit(os.path.join(dossier, "sonde.jsonl"))
    ecrit(os.path.join(dossier, "sonde_min.jsonl"), [minuscules(d) for d in sonde])
    v3 = lit(os.path.join(RACINE, "bench", "corpus.jsonl"))
    ecrit(os.path.join(dossier, "v3_min.jsonl"), [minuscules(d) for d in v3])


def charge_prenoms():
    eff = {}
    with gzip.open(PRENOMS_TSV, "rt", encoding="utf-8") as f:
        for l in f:
            if l.startswith("#") or "\t" not in l:
                continue
            nom, n = l.rstrip("\n").split("\t")
            eff[L.plie(nom)] = eff.get(L.plie(nom), 0) + int(n)
    return eff


def charge_formes():
    with gzip.open(FORMES, "rt", encoding="utf-8") as f:
        return {l.strip() for l in f if l.strip() and not l.startswith("#")}


def positions(avertissement):
    m = POSITIONS.search(avertissement)
    if not m:
        return []
    return [int(x) for x in re.findall(r"[0-9]+", m.group(1))]


class Ctx:
    def __init__(self):
        self.patro = L.charge_insee()
        self.prenoms = charge_prenoms()
        self.formes = charge_formes()


def mot_a(texte, p):
    m = MOT.match(texte, p)
    return m.group(0) if m else ""


def mot_avant(texte, p):
    m = re.search(r"([\wÀ-ÿ'’-]+)[ \t  ]+$", texte[:p])
    return m.group(1) if m else ""


def chemin_minuscules(texte, p):
    """Le chemin « prénom connu en minuscules + mot » : le mot et le mot qui le
    précède commencent par une minuscule."""
    avant = mot_avant(texte, p)
    mot = mot_a(texte, p)
    return bool(avant) and bool(mot) and avant[:1].islower() and mot[:1].islower()


def garde(option, ctx, texte, p):
    """Vrai si la position d'un avertissement du chemin minuscule est conservée."""
    mot = mot_a(texte, p)
    if option == "base" or option == "O2":
        return True
    if option.startswith("O1"):
        t = int(option[3:-1])
        return ctx.patro.get(L.plie(mot), 0) >= t
    if option == "O3":
        return False
    if option.startswith("O4"):
        s = int(option[3:-1])
        return ctx.prenoms.get(L.plie(mot_avant(texte, p)), 0) >= s
    if option == "O5":
        return mot.lower() not in ctx.formes
    raise ValueError(option)


def evalue(option, ctx, corpus, pred):
    """Documents avertis (par mot, ou par l'avertissement général de O3) et
    positions conservées, sur un corpus."""
    docs = Counter()
    for d in corpus:
        r = pred[d["id"]]
        texte = d["text"]
        gardees = 0
        for w in r["warnings"]:
            if not HOMONYME.search(w):
                continue
            for p in positions(w):
                if not chemin_minuscules(texte, p) or garde(option, ctx, texte, p):
                    gardees += 1
        if gardees:
            docs["par_mot"] += 1
        if option == "O3" and not any(c.isupper() for c in texte):
            docs["general"] += 1
        if option == "O2" and sum(1 for w in r["warnings"] if HOMONYME.search(w)) > 1:
            docs["plusieurs_avertissements"] += 1
    return docs


def homonymes_signales(option, ctx, corpus, pred, filtre=None):
    """Sur la sonde de P2-308 : homonymes en clair, et parmi eux ceux qu'un
    avertissement accompagne encore sous l'option. O3 compte l'avertissement
    général comme un signal pour un document sans majuscule."""
    clair = signale = 0
    eff_clair = eff_signale = 0
    par_liste = {}
    for d in corpus:
        # Les quatre listes que P2-310 signale ; les neuf autres restent
        # silencieuses (hors fiche) et fausseraient le rapport.
        if d["liste"] not in L.LISTES_SIGNALEES or (filtre and not filtre(d)):
            continue
        r = pred[d["id"]]
        if not L.en_clair(d["patro_debut"], d["patro_fin"], r["entities"]):
            continue
        clair += 1
        eff_clair += d["effectif"]
        texte = d["text"]
        ok = False
        for w in r["warnings"]:
            if not HOMONYME.search(w):
                continue
            for p in positions(w):
                if not (d["patro_debut"] <= p < d["patro_fin"]):
                    continue
                if not chemin_minuscules(texte, p) or garde(option, ctx, texte, p):
                    ok = True
        if option == "O3" and not any(c.isupper() for c in texte):
            ok = ok or bool(any(HOMONYME.search(w) for w in r["warnings"]))
        signale += ok
        eff_signale += d["effectif"] * ok
        c = par_liste.setdefault(d["liste"], [0, 0])
        c[0] += 1
        c[1] += ok
    return clair, signale, eff_signale / eff_clair if eff_clair else 1.0, par_liste


OPTIONS = ["base", "O1(1000)", "O1(10000)", "O1(50000)", "O2", "O3", "O4(1000)",
           "O4(50000)", "O5"]


def analyse(dossier):
    ctx = Ctx()
    donnees = {}
    for nom in CORPUS:
        donnees[nom] = (lit(os.path.join(dossier, nom + ".jsonl")),
                        {d["id"]: d for d in lit(os.path.join(dossier, "pred_" + nom + ".jsonl"))})
    print("corpus | documents")
    for nom in CORPUS:
        print(f"{nom} | {len(donnees[nom][0])}")
    print()
    print("option | pv_min : docs avertis (par mot / général) | v3_min : docs avertis "
          "| sonde casse ordinaire : en clair / signalés | sonde minuscules : en clair / signalés "
          "(part des naissances des homonymes en clair qui restent signalés)")
    for o in OPTIONS:
        a = evalue(o, ctx, *donnees["pv_min"])
        b = evalue(o, ctx, *donnees["v3_min"])
        c_ord = homonymes_signales(o, ctx, *donnees["sonde"],
                                   filtre=lambda d: d["tournure"] != "minuscules")
        c_min = homonymes_signales(o, ctx, *donnees["sonde_min"])
        print(f"{o} | {a['par_mot']} / {a['general']} | {b['par_mot']} / {b['general']} | "
              f"{c_ord[0]} / {c_ord[1]} | {c_min[0]} / {c_min[1]} ({100 * c_min[2]:.1f} %)")
    print("\nétat actuel, sonde de P2-308 en minuscules, par liste : en clair / signalés")
    for liste, (clair, sig) in sorted(
            homonymes_signales("base", ctx, *donnees["sonde_min"])[3].items()):
        if liste in L.LISTES_SIGNALEES:
            print(f"{liste} | {clair} / {sig}")
    pv = evalue("base", ctx, *donnees["pv"])
    print(f"\ncasse ordinaire, sonde prénom + verbe : documents avertis {pv['par_mot']}")
    o2 = evalue("O2", ctx, *donnees["pv_min"])
    o2b = evalue("O2", ctx, *donnees["sonde_min"])
    print(f"documents portant plus d'un avertissement d'homonymes : "
          f"pv_min {o2['plusieurs_avertissements']}, sonde_min {o2b['plusieurs_avertissements']}")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("prepare", "analyse"):
        raise SystemExit(__doc__)
    {"prepare": prepare, "analyse": analyse}[sys.argv[1]](sys.argv[2])
