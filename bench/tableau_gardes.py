#!/usr/bin/env python3
"""Tableau de P2-272 à partir du TSV de `mesure_gardes_faux_accords.sh`.
Usage : python3 tableau_gardes.py gardes.tsv
Imprime, par garde : masquages à tort évités sur le témoin durci (type visé et
tous types), identifiants perdus (couverts avec la base, plus avec la garde)
sur chaque corpus, pour la clé fausse visée puis pour tous les autres positifs.
"""
import json
import sys

CIBLE = {"iban": ("iban", None), "nir": ("nir", None),
         "finess": ("finess", None), "adr": ("adresse", None)}
CORPUS = [("v3", "v3 (1 000)"), ("lf", "libellé fort"), ("ocr_tous", "OCR"),
          ("c200k", "200 000"), ("sonde", "sonde")]

lignes = {}
for l in open(sys.argv[1], encoding="utf-8"):
    g, c, j = l.rstrip("\n").split("\t", 2)
    lignes[(g, c)] = json.loads(j)
gardes = []
for (g, c) in lignes:
    if g not in gardes:
        gardes.append(g)


def pos(g, c):
    return lignes.get((g, c), {}).get("positifs", {})


def perdus(g, c, cles):
    base, cur = pos("base", c), pos(g, c)
    return sum(base[k][0] - cur[k][0] for k in base if k in cles)


print("| Garde | Témoin durci : à tort du type visé (base → garde) | "
      "Témoin durci : documents à tort, tous types | " +
      " | ".join(f"Perdus {n}, cible / autres" if c != "sonde" else
                                          "Perdus sonde / documents cibles" for c, n in CORPUS) + " |")
print("|---|---|---|" + "---|" * len(CORPUS))
for g in gardes:
    if g == "base":
        continue
    famille = g.split("_")[0]
    typ, cle = CIBLE[famille]
    b = lignes[("base", "ocr")]["negatifs"]
    n = lignes[(g, "ocr")]["negatifs"]
    cel = [f"{b['types'].get(typ, 0)} → {n['types'].get(typ, 0)}",
           f"{b['avec_prediction']} → {n['avec_prediction']}"
           + ("" if n["types"] == {**b["types"], typ: n["types"].get(typ, 0)}
              else " (" + ", ".join(f"{t} {b['types'].get(t,0)}→{n['types'].get(t,0)}"
                                    for t in sorted(set(b['types']) | set(n['types']))
                                    if b['types'].get(t, 0) != n['types'].get(t, 0)) + ")")]
    for c, _ in CORPUS:
        if (g, c) not in lignes:
            cel.append("n/m")
            continue
        base = pos("base", c)
        if c == "sonde":
            ks = [k for k in base if k.startswith(typ + "|")]
            cel.append(f"{perdus(g, c, set(ks))} / {sum(base[k][1] for k in ks)}"
                       if ks else "0 / 0")
            continue
        cibles = {k for k in base if k.startswith(typ + "|fausse|")
                  or (typ == "finess" and k.startswith("finess|"))}
        if famille == "adr":
            cibles = set()
        tout = set(base)
        a = perdus(g, c, cibles) if cibles else 0
        o = perdus(g, c, tout - cibles)
        cel.append(f"{a} / {o}")
    print(f"| `{g}` | " + " | ".join(cel) + " |")
b = lignes[("base", "ocr")]["negatifs"]
print(f"\nBase, témoin durci : {b['avec_prediction']} / {b['documents']}, types {b['types']}")
for c, n in CORPUS:
    print(f"Base, {n} : positifs {pos('base', c)}")
