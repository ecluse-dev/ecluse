#!/usr/bin/env python3
"""Restreint un corpus aux documents où un mot-clé d'établissement est suivi d'un
mot (P2-295) : les autres ne peuvent produire aucune entité `etablissement`
(`EtablissementDetector._pattern`), donc ne changent pas quand on modifie ce
détecteur. Usage : restreint_sans_personne.py ENTREE SORTIE."""
import json
import os
import re
import sys

DART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "packages",
                    "ecluse_redact", "lib", "src", "heuristics",
                    "etablissement_keywords.dart")


def motif():
    src = open(DART, encoding="utf-8").read()
    ks = sorted({a or b for a, b in re.findall(r"'([^']+)'|\"([^\"]+)\"", src)},
                key=len, reverse=True)
    return re.compile(r"(?<![\wÀ-ÿ])(?:" + "|".join(re.escape(k) for k in ks)
                      + r")[ \t]+\S")


def main():
    r = motif()
    n = k = 0
    with open(sys.argv[2], "w", encoding="utf-8") as out:
        for ligne in open(sys.argv[1], encoding="utf-8"):
            if not ligne.strip():
                continue
            n += 1
            if r.search(json.loads(ligne)["text"]):
                out.write(ligne)
                k += 1
    print(f"{k} documents retenus sur {n}")


if __name__ == "__main__":
    main()
