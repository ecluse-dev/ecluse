#!/usr/bin/env python3
"""Terminaisons verbales candidates contre les noms annotés (P2-242).

Pour chaque terminaison candidate de la liste fermée de verbes, compte, parmi
**tous les mots de toutes les entités `nom` annotées** des corpus présents dans
`bench/` (hors prédictions), ceux qu'elle ferait passer pour un verbe : un tel
mot, derrière un prénom, serait rendu en clair (fuite d'un patronyme). Une
terminaison n'entre dans `verbes_conjugues.dart` que si ce compte est **0**.
Mesure d'une terminaison à la fois. N'imprime que des comptes et des
terminaisons, jamais un texte de document.

Limite : les corpus synthétiques ont un vocabulaire de noms étroit ; un compte
nul n'est pas une preuve sur de vrais patronymes. Les écarts connus (prénoms
féminins en « -ise », « -dra ») sont écartés à la main, voir `LIMITES.md`.

Usage (depuis `bench/`) :
    python3 mesure_terminaisons_verbes.py [--reserve2]
"""

import argparse
import glob
import json
import os
import re

ICI = os.path.dirname(os.path.abspath(__file__))

ASSET = os.path.join(ICI, "..", "packages", "ecluse_reference", "assets",
                     "first_names_effectifs.tsv.gz")
SEUIL_PRENOM = 1000  # effectif cumulé 1900-2025 : un prénom d'usage courant

CANDIDATES = ["ifie", "ionne", "ifient", "ionnent", "isent", "ise", "ent",
              "era", "dra", "iera", "ère", "isse", "ume", "ite", "ate",
              "icite", "ige", "are", "ule", "ure", "ouille", "ente", "ivent"]


def mots_annotes():
    mots = set()
    for chemin in glob.glob(os.path.join(ICI, "**", "*.jsonl"),
                            recursive=True):
        if os.path.basename(chemin).startswith("pred"):
            continue
        with open(chemin, encoding="utf-8") as f:
            for ligne in f:
                if not ligne.strip():
                    continue
                d = json.loads(ligne)
                t = d.get("text")
                if not isinstance(t, str):
                    continue
                for e in d.get("entities", []):
                    if e.get("type") == "nom":
                        for w in re.split(r"[\s\-]+", t[e["start"]:e["end"]]):
                            w = w.strip(".,;:()'’").lower()
                            if len(w) > 4:
                                mots.add(w)
    return mots


def prenoms_courants():
    """Prénoms INSEE d'effectif au moins SEUIL_PRENOM (minuscules, sans
    accent ni tiret) : proxy d'un second prénom derrière un prénom."""
    import gzip
    import unicodedata
    out = set()
    with gzip.open(ASSET, "rt", encoding="utf-8") as f:
        for ligne in f:
            if ligne.startswith("#") or "\t" not in ligne:
                continue
            nom, n = ligne.rstrip("\n").split("\t")[:2]
            if int(n) >= SEUIL_PRENOM and len(nom) > 4:
                nfd = unicodedata.normalize("NFD", nom.lower())
                out.add("".join(c for c in nfd
                                if unicodedata.category(c) != "Mn"))
    return out


def sans_accent(mot):
    import unicodedata
    return "".join(c for c in unicodedata.normalize("NFD", mot)
                   if unicodedata.category(c) != "Mn")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--reserve2", action="store_true")
    a = ap.parse_args()
    mots = mots_annotes()
    prenoms = prenoms_courants()
    print(f"{len(mots)} mots de nom annotés distincts (plus de 4 lettres) ; "
          f"{len(prenoms)} prénoms INSEE d'effectif >= {SEUIL_PRENOM}")
    from generate_corpus_prenom_verbe import RESERVE, RESERVE2
    for fin in CANDIDATES:
        n = sum(1 for m in mots if m.endswith(fin))
        r = sum(1 for v in RESERVE if v.endswith(fin))
        r2 = sum(1 for v in RESERVE2 if v.endswith(fin))
        p = sum(1 for m in prenoms if sans_accent(m).endswith(sans_accent(fin)))
        print(f"terminaison -{fin} : {n} nom(s) annoté(s), {p} prénom(s) "
              f"courant(s) concerné(s) ; "
              f"réserve {r}/{len(RESERVE)}, réserve2 {r2}/{len(RESERVE2)}")


if __name__ == "__main__":
    main()
