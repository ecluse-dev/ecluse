#!/usr/bin/env python3
"""P2-303 (mesure) : pour chaque garde, combien de vrais identifiants d'une sonde
`Ecluse.redact` laisse partir **sans avertissement**.

Entrée : paires `corpus.jsonl:pred.jsonl`, la prédiction venant de
`packages/ecluse_redact/bin/run_gardes_avertissements.dart` (entités et
avertissements). Un identifiant est **couvert** quand tous ses caractères sont
sous une entité, quel que soit le type ; sinon il part en clair (en partie ou en
entier). Il est **signalé** quand le document porte un avertissement propre à
une détection manquée ou douteuse (voir `PERTINENT`) : les avertissements
génériques (texte sans majuscule, casse de phrase, secret, jeton littéral) ne
comptent pas. Chaque document de la sonde annote un seul identifiant, donc
l'avertissement lui est attribuable. N'imprime que des comptes et les débuts des
avertissements (comptes et positions, jamais une valeur).
"""
import json
import re
import sys
from collections import Counter, defaultdict

PERTINENT = re.compile(r"à vérifier|relire avant envoi|non masqué")


def couvert(debut, fin, entites):
    pos = debut
    for e in sorted(entites, key=lambda e: (e["start"], -e["end"])):
        if e["end"] <= pos:
            continue
        if e["start"] > pos:
            return False
        pos = e["end"]
        if pos >= fin:
            return True
    return pos >= fin


def caracteres_en_clair(debut, fin, entites):
    """Nombre de caractères de [debut, fin) hors de toute entité."""
    return sum(1 for i in range(debut, fin)
               if not any(e["start"] <= i < e["end"] for e in entites))


def main(paires):
    t = defaultdict(lambda: Counter())
    motifs = defaultdict(Counter)
    for p in paires:
        c, pr = p.split(":")
        corpus = [json.loads(l) for l in open(c, encoding="utf-8")]
        pred = {d["id"]: d for d in map(json.loads, open(pr, encoding="utf-8"))}
        for d in corpus:
            cle = (d.get("famille") or d.get("garde"), d.get("ecriture") or d.get("variante"))
            r = pred[d["id"]]
            pert = [w for w in r["warnings"] if PERTINENT.search(w)]
            for e in d["entities"]:
                t[cle]["n"] += 1
                if couvert(e["start"], e["end"], r["entities"]):
                    t[cle]["couverts"] += 1
                    if pert:
                        t[cle]["couverts_signales"] += 1
                else:
                    t[cle]["non_couverts"] += 1
                    t[cle]["clair"] += caracteres_en_clair(e["start"], e["end"], r["entities"])
                    t[cle]["longueur"] += e["end"] - e["start"]
                    if pert:
                        t[cle]["non_couverts_signales"] += 1
                        for w in pert:
                            motifs[cle][re.sub(r"[0-9]+", "N", w)[:70]] += 1
                    else:
                        t[cle]["silencieux"] += 1
    print("famille | écriture | n | couverts | non couverts | dont signalés | SILENCIEUX | caractères en clair (non couverts)")
    tot = Counter()
    par_famille = defaultdict(Counter)
    for (f, w), c in sorted(t.items(), key=lambda x: (str(x[0][0]), str(x[0][1]))):
        print(f"{f} | {w} | {c['n']} | {c['couverts']} | {c['non_couverts']} | "
              f"{c['non_couverts_signales']} | {c['silencieux']}"
              + (f" | {c['clair']}/{c['longueur']} caractères en clair" if c['non_couverts'] else ""))
        par_famille[f].update(c)
    print("\n== par famille")
    for f, c in sorted(par_famille.items(), key=lambda x: str(x[0])):
        print(f"{f} : {c['n']} identifiants, {c['couverts']} couverts, "
              f"{c['non_couverts']} non couverts, {c['non_couverts_signales']} signalés, "
              f"{c['silencieux']} silencieux"
              + (f" ; {c['clair']}/{c['longueur']} caractères en clair" if c['non_couverts'] else ""))
    print("\n== avertissements vus sur les non couverts")
    for cle, m in sorted(motifs.items(), key=lambda x: str(x[0])):
        print(cle, dict(m))


if __name__ == "__main__":
    main(sys.argv[1:])
