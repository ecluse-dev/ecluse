#!/usr/bin/env python3
"""P2-322 (mesure) : civilité capitalisée devant un mot en minuscules
(« Madame fait un malaise »). Rien n'est corrigé.

`LIMITES.md` (P2-315) : ce chemin n'est pas celui du texte sans majuscule, et
l'avertissement des homonymes écartés ne l'attend pas ; la limite n'a jamais été
chiffrée. Trois commandes, chemin mesuré `Ecluse.redact`
(`packages/ecluse_redact/bin/run_gardes_avertissements.dart`), graine fixe :

  sonde --out F.jsonl [--par-liste N] : pour chacune des treize listes d'exclusion
      signalées (P2-316/P2-318), ses homonymes patronymes (≥ 30 naissances INSEE,
      comme `homonymes_patronymes.dart`) placés derrière « Monsieur », « Madame »,
      « M. » et « Mme » capitalisés, **écrits en minuscules** ; un nom annoté par
      document ; plus un témoin de patronymes hors liste, même forme.
  analyse F.jsonl:PRED.jsonl : par liste, combien de ces patronymes sont masqués,
      signalés (en clair avec l'avertissement « mot pris pour un nom commun »),
      silencieux (en clair, sans cet avertissement).
  temoins --out T.jsonl CORPUS… / analyse_temoins T.jsonl:PRED.jsonl : coût d'un
      signalement sur les corpus propres : documents où une civilité capitalisée
      précède un homonyme en minuscules, puis, après `Ecluse.redact`, ceux où le
      mot reste en clair (ce qu'un signalement ajouterait d'avertissements).

N'imprime que des comptes, des mots de listes (des mots de la langue, écrits dans
le code) et des noms de corpus : aucun texte de document, aucune valeur.
"""
import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import listes_exclusion as L  # noqa: E402

CIVILITES = ["Monsieur", "Madame", "M.", "Mme"]
# Une tournure par civilité : le mot en minuscules suit la civilité.
MODELES = {
    "Monsieur": "Monsieur {w} est venu ce matin.",
    "Madame": "Madame {w} est venue ce matin.",
    "M.": "M. {w} est venu ce matin.",
    "Mme": "Mme {w} est venue ce matin.",
}
AVERTISSEMENT = "mot pris pour un nom commun"


def position_mot(texte, mot):
    m = re.search(r"(?<!\w)" + re.escape(mot) + r"(?!\w)", texte)
    if not m:
        raise ValueError("mot absent du modèle")
    return m.start()


def cmd_sonde(out, par_liste):
    eff = L.charge_insee()
    docs = []
    toutes = set()
    for _, fichier, nom, _ in L.LISTES:
        toutes.update(L.plie(e) for e in L.entrees(fichier, nom))
    for ident, fichier, nom, _ in L.LISTES:
        if ident not in L.LISTES_SIGNALEES:
            continue
        for mot, n in L.homonymes(L.entrees(fichier, nom), eff)[:par_liste]:
            w = mot.lower()
            for civ in CIVILITES:
                texte = MODELES[civ].format(w=w)
                i = position_mot(texte, w)
                docs.append({
                    "id": len(docs), "text": texte,
                    "entities": [{"type": "nom", "start": i, "end": i + len(w)}],
                    "liste": ident, "mot": mot, "civilite": civ, "effectif": n,
                    "patro_debut": i, "patro_fin": i + len(w)})
    # Témoin : les 40 patronymes les plus répandus hors de toute liste.
    temoin = [(n, e) for n, e in eff.items() if n not in toutes and n.isalpha() and len(n) > 3]
    for n, e in sorted(temoin, key=lambda x: -x[1])[:40]:
        w = n.lower()
        for civ in CIVILITES:
            texte = MODELES[civ].format(w=w)
            i = position_mot(texte, w)
            docs.append({
                "id": len(docs), "text": texte,
                "entities": [{"type": "nom", "start": i, "end": i + len(w)}],
                "liste": "temoin_patronymes", "mot": n, "civilite": civ, "effectif": e,
                "patro_debut": i, "patro_fin": i + len(w)})
    with open(out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {out}")


def en_clair(debut, fin, ents):
    return L.en_clair(debut, fin, ents)


def signale(warnings):
    return any(AVERTISSEMENT in w for w in warnings)


def classe(d, r):
    """'masque', 'signale' ou 'silencieux' pour le patronyme annoté de `d`."""
    if en_clair(d["patro_debut"], d["patro_fin"], r["entities"]) == 0:
        return "masque"
    return "signale" if signale(r["warnings"]) else "silencieux"


def tableau(corpus, pred):
    t = defaultdict(Counter)
    for d in corpus:
        r = pred[d["id"]]
        t[d["liste"]][classe(d, r)] += 1
        t[d["liste"]]["n"] += 1
    return t


def charge(chemin_corpus, chemin_pred):
    corpus = [json.loads(l) for l in open(chemin_corpus, encoding="utf-8") if l.strip()]
    pred = {d["id"]: d for d in map(json.loads, open(chemin_pred, encoding="utf-8")) if d}
    return corpus, pred


def cmd_analyse(paire):
    c, p = paire.split(":")
    corpus, pred = charge(c, p)
    t = tableau(corpus, pred)
    print("liste | documents | masqués | signalés | silencieux")
    tot = Counter()
    for liste in sorted(t):
        c_ = t[liste]
        print(f"{liste} | {c_['n']} | {c_['masque']} | {c_['signale']} | {c_['silencieux']}")
        if liste != "temoin_patronymes":
            tot.update(c_)
    print(f"TOTAL treize listes | {tot['n']} | {tot['masque']} | {tot['signale']} | {tot['silencieux']}")
    print("\npar civilité (treize listes) | documents | masqués | signalés | silencieux")
    par = defaultdict(Counter)
    for d in corpus:
        if d["liste"] != "temoin_patronymes":
            par[d["civilite"]][classe(d, pred[d["id"]])] += 1
            par[d["civilite"]]["n"] += 1
    for civ in CIVILITES:
        c_ = par[civ]
        print(f"{civ} | {c_['n']} | {c_['masque']} | {c_['signale']} | {c_['silencieux']}")


def motif_temoins():
    """Civilité capitalisée + mot en minuscules d'une des treize listes."""
    mots = L.mots_homonymes()  # minuscules sans accent
    return re.compile(
        r"(?<!\w)(?:Monsieur|Madame|Mme|M\.)[ \t]+([a-zàâçéèêëîïôûùüÿœæ'’-]+)(?!\w)"), set(mots)


def cmd_temoins(out, corpus_paths):
    motif, mots = motif_temoins()
    docs, total = [], Counter()
    for chemin in corpus_paths:
        nom = os.path.basename(chemin)
        for ligne in open(chemin, encoding="utf-8"):
            if not ligne.strip():
                continue
            total[nom] += 1
            d = json.loads(ligne)
            texte = d["text"]
            for m in motif.finditer(texte):
                if L.plie(m.group(1)).lower() in mots:
                    docs.append({"id": len(docs), "text": texte, "corpus": nom,
                                 "mot": m.group(1),
                                 "patro_debut": m.start(1), "patro_fin": m.end(1)})
                    break
    with open(out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    with open(out + ".totaux", "w", encoding="utf-8") as f:
        json.dump(total, f)
    print(f"{len(docs)} documents candidats sur {sum(total.values())} ({len(total)} corpus) dans {out}")


def cmd_analyse_temoins(paire):
    c, p = paire.split(":")
    corpus, pred = charge(c, p)
    total = json.load(open(c + ".totaux", encoding="utf-8"))
    cand, clair, mots = Counter(), Counter(), Counter()
    for d in corpus:
        cand[d["corpus"]] += 1
        r = pred[d["id"]]
        if en_clair(d["patro_debut"], d["patro_fin"], r["entities"]) > 0:
            clair[d["corpus"]] += 1
            mots[d["mot"]] += 1
    print("corpus | documents | civilité + homonyme en minuscules | mot en clair (avertissements ajoutés) | part")
    for nom in sorted(total):
        if cand[nom]:
            print(f"{nom} | {total[nom]} | {cand[nom]} | {clair[nom]} | {100 * clair[nom] / total[nom]:.2f} %")
    n, k, a = sum(total.values()), sum(cand.values()), sum(clair.values())
    pire = max(((clair[x] / total[x], x) for x in total), default=(0, ""))
    print("mots en clair derrière la civilité (mots de listes, jamais un texte) : "
          + ", ".join(f"{m} {n}" for m, n in mots.most_common(15)))
    print(f"TOTAL | {n} | {k} | {a} | {100 * a / max(n, 1):.3f} % ; pire corpus {100 * pire[0]:.2f} % ({pire[1]})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    s = sp.add_parser("sonde")
    s.add_argument("--out", required=True)
    s.add_argument("--par-liste", type=int, default=200)
    sp.add_parser("analyse").add_argument("paire")
    t = sp.add_parser("temoins")
    t.add_argument("--out", required=True)
    t.add_argument("corpus", nargs="+")
    sp.add_parser("analyse_temoins").add_argument("paire")
    a = ap.parse_args()
    if a.cmd == "sonde":
        cmd_sonde(a.out, a.par_liste)
    elif a.cmd == "analyse":
        cmd_analyse(a.paire)
    elif a.cmd == "temoins":
        cmd_temoins(a.out, a.corpus)
    else:
        cmd_analyse_temoins(a.paire)
