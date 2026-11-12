#!/usr/bin/env python3
"""Corpus « mise en page » (P2-153) : recoupe chaque texte d'un corpus JSONL
aux espaces, a une largeur de page donnee.

Pourquoi : un document copie d'un PDF ou d'un traitement de texte arrive avec
des retours a la ligne au milieu des phrases, donc au milieu des noms et des
adresses. La regle « un span ne traverse jamais un saut de ligne »
(LIMITES.md § 5.2) est assumee ; ce corpus chiffre ce qu'elle coute.

Methode : remplissage glouton. Un espace ASCII (U+0020) devient « \\n » quand
le mot suivant depasserait la largeur ; rien d'autre ne change (ni les
espaces insecables, ni les tabulations, ni les sauts de ligne deja presents,
qui remettent la colonne a zero). Le remplacement est de un caractere pour un
caractere : la longueur est conservee et les offsets des entites restent
exacts sans recalcul ; le script le verifie et refuse sinon. Deterministe,
sans hasard : la graine 42 est acceptee pour l'uniformite des generateurs.

Usage :
    python3 generate_corpus_mise_en_page.py corpus.jsonl --largeur 60 \\
        --out corpus_largeur60.jsonl [--seed 42]
"""

import argparse
import json


def recoupe(texte, largeur):
    """Recoupe `texte` aux espaces ASCII a `largeur` colonnes au plus (sauf
    mot plus long que la largeur, laisse entier)."""
    if largeur < 2:
        raise ValueError("largeur trop petite")
    sortie = list(texte)
    n = len(texte)
    col = 0
    i = 0
    while i < n:
        c = texte[i]
        if c == "\n":
            col = 0
        elif c == " ":
            j = i + 1
            while j < n and not texte[j].isspace():
                j += 1
            mot = j - (i + 1)
            if col > 0 and mot > 0 and col + 1 + mot > largeur:
                sortie[i] = "\n"
                col = 0
            else:
                col += 1
        else:
            col += 1
        i += 1
    return "".join(sortie)


def transforme(doc, largeur):
    texte = recoupe(doc["text"], largeur)
    if len(texte) != len(doc["text"]):
        raise SystemExit(f"refus : document {doc['id']} change de longueur")
    for e in doc.get("entities", []):
        if not (0 <= e["start"] < e["end"] <= len(texte)):
            raise SystemExit(f"refus : offsets invalides, document {doc['id']}")
    return {**doc, "text": texte}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("corpus")
    p.add_argument("--largeur", type=int, required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--seed", type=int, default=42)  # sans effet : deterministe
    a = p.parse_args()
    n = coupes = 0
    with open(a.corpus, encoding="utf-8") as f, \
            open(a.out, "w", encoding="utf-8") as out:
        for ligne in f:
            if not ligne.strip():
                continue
            d = json.loads(ligne)
            t = transforme(d, a.largeur)
            coupes += t["text"].count("\n") - d["text"].count("\n")
            out.write(json.dumps(t, ensure_ascii=False) + "\n")
            n += 1
    print(f"{a.out} : {n} documents, {coupes} retours a la ligne ajoutes")


if __name__ == "__main__":
    main()
