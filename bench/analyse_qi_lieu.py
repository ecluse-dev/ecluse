#!/usr/bin/env python3
"""P2-287 (mesure) : quasi-identifiants `lieu` lus sur des mots courants dans le
rapport de risque de `Ecluse.redact`. Rien n'est corrigé.

Entrées : les sorties de `run_qi_lieu.dart` (une par corpus) dans un dossier,
fichiers `q_<corpus>.jsonl`, dont `q_sonde_isole.jsonl` et `q_sonde_combine.jsonl`
(sondes de `generate_sonde_mots_courants.py`).

Un lieu est « légitime » s'il figure dans les corpus de QI annotés (communes
posées par le générateur) ou dans la liste des villes du témoin sans personne ;
tout autre mot lu comme lieu est « mot courant ou sigle ». Aucun texte de
document n'est imprimé, seulement le mot lu comme lieu (corpus synthétiques).

Usage : python3 analyse_qi_lieu.py DOSSIER
"""
import glob
import json
import os
import re
import sys
from collections import Counter, defaultdict

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)

PREPOSITIONS = re.compile(r"(?:^|\s)(?:à|a|de|du|des|d'|d’|en|au|aux|près de|vers)\s*$", re.I)


def lit(chemin):
    return [json.loads(l) for l in open(chemin, encoding="utf-8") if l.strip()]


def villes_temoin():
    src = open(os.path.join(ICI, "generate_corpus_temoin_sans_pii.py"), encoding="utf-8").read()
    bloc = src.split("VILLES = [")[1].split("]")[0]
    return set(re.findall(r'"([^"]+)"', bloc))


def bande(d):
    return d["bande"] or d["statut"]


def main():
    dossier = sys.argv[1]
    q = {os.path.basename(f)[2:-6]: lit(f) for f in glob.glob(os.path.join(dossier, "q_*.jsonl"))}
    legit = set(villes_temoin())
    for nom in ("qi_realiste", "qi_adversarial"):
        for d in q.get(nom, []):
            legit.update(l["mot"] for l in d["lieux"])
    print("## lieux lus par corpus (Ecluse.redact avec référence)")
    suspects = defaultdict(Counter)  # mot -> {corpus: documents}
    effet = defaultdict(Counter)  # mot -> {(avant -> après): n}
    for nom in sorted(q):
        if nom.startswith("sonde"):
            continue
        docs = q[nom]
        avec = sum(1 for d in docs if d["lieux"])
        sus = [d for d in docs if any(l["mot"] not in legit for l in d["lieux"])]
        print(f"{nom} : {len(docs)} documents, {avec} avec un lieu, "
              f"{len(sus)} avec un lieu qui est un mot courant ou un sigle")
        for d in docs:
            vus = set()
            for l in d["lieux"]:
                if l["mot"] in legit or l["mot"] in vus:
                    continue
                vus.add(l["mot"])
                suspects[l["mot"]][nom] += 1
                effet[l["mot"]][(bande(d), l["bande2"])] += 1
    print("## mot × documents × effet sur la bande (avec le lieu → sans lui)")
    for mot, c in sorted(suspects.items(), key=lambda x: -sum(x[1].values())):
        corp = ", ".join(f"{k} {v}" for k, v in sorted(c.items()))
        eff = "; ".join(f"{a} → {b} : {n}" for (a, b), n in sorted(effet[mot].items(), key=lambda x: -x[1]))
        print(f"{mot} : {sum(c.values())} documents ({corp}) ; {eff}")
    # Coût d'une exigence de préposition : lieux légitimes des corpus de QI annotés.
    print("## règle « préposition devant le lieu » (simulation sur les sorties)")
    for nom in ("qi_realiste", "qi_adversarial"):
        tot = sans = 0
        for d in q.get(nom, []):
            for l in d["lieux"]:
                tot += 1
                if not PREPOSITIONS.search(l["avant"]):
                    sans += 1
        print(f"{nom} : {tot} lieux légitimes, {sans} sans préposition devant (perdus par la règle)")
    par_mot = defaultdict(lambda: [0, 0])  # mot -> [lieux, écartés par la règle]
    for nom in ("sanspii", "dossiers_realiste", "courriers", "flou_adversarial"):
        for d in q.get(nom, []):
            for l in d["lieux"]:
                if l["mot"] in legit:
                    continue
                par_mot[l["mot"]][0] += 1
                if not PREPOSITIONS.search(l["avant"]):
                    par_mot[l["mot"]][1] += 1
    tot = sum(v[0] for v in par_mot.values())
    ecart = sum(v[1] for v in par_mot.values())
    print(f"mots courants des corpus de documents : {tot} lieux, {ecart} écartés par la règle ({tot - ecart} restent)")
    for mot, (n, e) in sorted(par_mot.items(), key=lambda x: -x[1][0]):
        print(f"  {mot} : {n} lieux, {e} écartés par la règle")
    # Coût d'une liste d'exclusion : liste = tous les mots observés ci-dessus et
    # les 15 mots de la sonde (liste construite sur les corpus mesurés : circulaire).
    sonde_lus = set()
    if q.get("sonde_isole"):
        for m, r in zip(lit(os.path.join(dossier, "sonde_isole.jsonl")), q["sonde_isole"]):
            if r["lieux"]:
                sonde_lus.add(m["mot"])
    exclus = set(par_mot) | sonde_lus
    perdus = sum(1 for nom in ("qi_realiste", "qi_adversarial") for d in q.get(nom, [])
                 for l in d["lieux"] if l["mot"] in exclus)
    print(f"## liste d'exclusion ({len(exclus)} mots : observés + sonde) : lieux légitimes des corpus de QI perdus : {perdus} ; "
          f"lieux de mots courants écartés : {tot} sur {tot}")
    # Sondes.
    iso = q.get("sonde_isole")
    if iso:
        mots = lit(os.path.join(dossier, "sonde_isole.jsonl"))
        par_mot = defaultdict(list)
        for m, r in zip(mots, iso):
            par_mot[m["mot"]].append((m["forme"], r))
        lus = {k: v for k, v in par_mot.items() if any(r["lieux"] for _, r in v)}
        print(f"## sonde isolée : {len(par_mot)} mots testés, {len(lus)} lus comme lieu en tête de phrase")
        for mot, v in sorted(lus.items()):
            _, r = v[0]
            print(f"{mot} : F = {r['f']:.0f}, bande {bande(r)}")
    comb = q.get("sonde_combine")
    if comb:
        mots = lit(os.path.join(dossier, "sonde_combine.jsonl"))
        print("## sonde combinée : patient fictif (âge, profession, une vraie commune) + phrase")
        for m, r in zip(mots, comb):
            f = "—" if r["f"] is None else f"{r['f']:.1f}"
            print(f"{m['mot']} : statut {r['statut']}, bande {r['bande']}, F {f}, lieux lus : "
                  + ", ".join(l["mot"] for l in r["lieux"]))


main()
