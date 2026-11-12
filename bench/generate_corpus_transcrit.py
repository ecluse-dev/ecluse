#!/usr/bin/env python3
"""Corpus « style transcrit » derive du corpus v3 (P2-98).

Simule la sortie d'un transcripteur vocal SANS audio : ce qu'on mesure ici
est l'effet de la forme du texte sur les detecteurs, pas la qualite d'un
transcripteur (voir `agent/specs/P2-10.md` § 5 et § 6). Deux variantes,
jamais fusionnees :

  sans_ponctuation : minuscules, ponctuation retiree, espaces reduites a une
                     seule ; les chiffres restent des chiffres
                     (§ 6, point 3 de P2-10 : casse et ponctuation seules)
  en_lettres       : idem, et chaque nombre ecrit en toutes lettres

Pour `en_lettres`, chaque document tire (graine fixe) une facon de dicter :
  chiffres : chiffre par chiffre (« un neuf trois zero huit »)
  groupes  : chaque groupe ecrit dans le texte se dit comme un nombre
             (« 93 08 128 » -> « quatre-vingt-treize zero huit cent
             vingt-huit ») ; un groupe de plus de trois chiffres se dit par
             paires, comme un numero de telephone

Quatre variantes de dictee s'y ajoutent (P2-160, `agent/specs/P2-155.md`
§ 2), chacune derivee de `en_lettres` et jamais fusionnee aux autres ; les
deux variantes d'origine restent identiques octet pour octet :
  double_triple     : chiffre par chiffre, une suite de chiffres identiques
                      se dit « double zero », « triple neuf »
  regional          : par groupes, « septante », « huitante », « nonante »
  zero_o            : le zero se dit « o » (« o six »)
  sans_traits_union : par groupes, traits d'union perdus par le
                      transcripteur (« quatre vingt treize »)
La ponctuation (virgules comprises) est deja retiree dans toutes les variantes.

Les annotations suivent la transformation : le span d'une entite couvre
exactement les mots produits a partir de son texte d'origine. Les numeros
pieges non annotes du corpus v3 sont transformes de la meme facon.

Usage :
    python generate_corpus_transcrit.py --corpus corpus.jsonl --seed 42 \\
        --out-dir .
"""

import argparse
import json
import random
import re

UNITES = ["zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept",
          "huit", "neuf", "dix", "onze", "douze", "treize", "quatorze",
          "quinze", "seize"]
DIZAINES = {2: "vingt", 3: "trente", 4: "quarante", 5: "cinquante",
            6: "soixante"}

VARIANTES_BASE = ("sans_ponctuation", "en_lettres")
VARIANTES_DICTEE = ("double_triple", "regional", "zero_o", "sans_traits_union")
VARIANTES = VARIANTES_BASE + VARIANTES_DICTEE
MODES = ("chiffres", "groupes")
# Mode de dictee impose par une variante (sinon tire au hasard, comme
# `en_lettres`) : « double/triple » n'a de sens que chiffre par chiffre, et
# « septante » ou les traits d'union que dans un nombre compose.
MODE_IMPOSE = {"double_triple": "chiffres", "regional": "groupes",
               "sans_traits_union": "groupes"}

# Ponctuation remplacee par une espace. Le trait d'union et l'apostrophe en
# font partie : un transcripteur ne les rend pas de facon fiable, et les
# garder favoriserait les detecteurs de noms composes.
PONCTUATION = re.compile(r"[.,;:!?()\[\]{}\"'’«»/\-–—]")
JETON = re.compile(r"[^\W\d_]+|\d+", re.UNICODE)


def moins_de_cent(n, regional=False):
    assert 0 <= n < 100
    if n <= 16:
        return UNITES[n]
    if n < 20:
        return "dix-" + UNITES[n - 10]
    d, u = divmod(n, 10)
    if d in DIZAINES:
        if u == 0:
            return DIZAINES[d]
        if u == 1:
            return DIZAINES[d] + " et un"
        return DIZAINES[d] + "-" + UNITES[u]
    if regional and d in (7, 8, 9):
        # septante, huitante, nonante : comme vingt, trente… (P2-160)
        tete = {7: "septante", 8: "huitante", 9: "nonante"}[d]
        if u == 0:
            return tete
        return tete + (" et un" if u == 1 else "-" + UNITES[u])
    if d == 7:
        return "soixante et onze" if u == 1 else "soixante-" + moins_de_cent(10 + u)
    if d == 8:
        return "quatre-vingts" if u == 0 else "quatre-vingt-" + UNITES[u]
    return "quatre-vingt-" + moins_de_cent(10 + u)  # 90-99


def nombre(n, regional=False):
    """0 a 999, orthographe traditionnelle (traits d'union sous cent)."""
    assert 0 <= n < 1000
    c, r = divmod(n, 100)
    if c == 0:
        return moins_de_cent(r, regional)
    tete = "cent" if c == 1 else UNITES[c] + " cent"
    if r == 0:
        return tete + ("s" if c > 1 else "")
    return tete + " " + moins_de_cent(r, regional)


def double_triple(chiffres):
    """Chiffre par chiffre, une suite de chiffres identiques se dit « double »
    (deux) ou « triple » (trois), coupee par blocs de trois."""
    mots, i = [], 0
    while i < len(chiffres):
        j = i
        while j < len(chiffres) and chiffres[j] == chiffres[i]:
            j += 1
        reste = j - i
        while reste:
            if reste >= 3:
                mots += ["triple", UNITES[int(chiffres[i])]]
                reste -= 3
            elif reste == 2:
                mots += ["double", UNITES[int(chiffres[i])]]
                reste -= 2
            else:
                mots.append(UNITES[int(chiffres[i])])
                reste -= 1
        i = j
    return mots


def groupe_en_lettres(chiffres, mode, variante="en_lettres"):
    """Une suite de chiffres -> liste de mots dictes."""
    mots = _mots_du_groupe(chiffres, mode, variante)
    if variante == "zero_o":
        mots = ["o" if m == "zéro" else m for m in mots]
    elif variante == "sans_traits_union":
        mots = " ".join(mots).replace("-", " ").split()
    return mots


def _mots_du_groupe(chiffres, mode, variante):
    if mode == "chiffres":
        if variante == "double_triple":
            return double_triple(chiffres)
        return [UNITES[int(c)] for c in chiffres]
    regional = variante == "regional"
    if len(chiffres) > 3:
        morceaux = [chiffres[i:i + 2] for i in range(0, len(chiffres), 2)]
    else:
        morceaux = [chiffres]
    mots = []
    for m in morceaux:
        # Les zeros de tete se disent (« zero six ») : sans eux, le nombre
        # de chiffres change et aucune clef ne peut plus etre verifiee.
        while len(m) > 1 and m[0] == "0":
            mots.append("zéro")
            m = m[1:]
        mots.extend(nombre(int(m), regional).split())
    return mots


def mots(segment, variante, mode):
    """Transforme un morceau de texte en liste de mots transcrits."""
    texte = PONCTUATION.sub(" ", segment.lower())
    if variante == "sans_ponctuation":
        return texte.split()
    sortie = []
    for j in JETON.findall(texte):
        if j.isdigit() and variante != "sans_ponctuation":
            sortie.extend(groupe_en_lettres(j, mode, variante))
        else:
            sortie.append(j)
    return sortie


def transcrit(doc, variante, mode):
    """Rend (texte, entites) avec des offsets exacts dans le nouveau texte."""
    entites = sorted(doc["entities"], key=lambda e: e["start"])
    morceaux, pos = [], 0
    for e in entites:
        morceaux.append((doc["text"][pos:e["start"]], None))
        morceaux.append((doc["text"][e["start"]:e["end"]], e["type"]))
        pos = e["end"]
    morceaux.append((doc["text"][pos:], None))

    parts, nouvelles, longueur = [], [], 0
    for segment, etype in morceaux:
        m = mots(segment, variante, mode)
        if not m:
            if etype is not None:
                raise ValueError(f"entite vide apres transformation, doc "
                                 f"{doc['id']}")
            continue
        if parts:
            parts.append(" ")
            longueur += 1
        debut = longueur
        bloc = " ".join(m)
        parts.append(bloc)
        longueur += len(bloc)
        if etype is not None:
            nouvelles.append({"type": etype, "start": debut, "end": longueur})
    return "".join(parts), nouvelles


def construit(docs, variante, seed):
    rng = random.Random(f"{seed}-{variante}")
    sortie = []
    for d in docs:
        if variante == "sans_ponctuation":
            mode = None
        else:
            mode = MODE_IMPOSE.get(variante) or rng.choice(MODES)
        texte, entites = transcrit(d, variante, mode)
        ligne = {"id": d["id"], "text": texte, "entities": entites}
        if mode:
            ligne["mode"] = mode
        sortie.append(ligne)
    return sortie


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--corpus", default="corpus.jsonl")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out-dir", default=".")
    a = p.parse_args()
    docs = [json.loads(l) for l in open(a.corpus, encoding="utf-8")]
    for variante in VARIANTES:
        chemin = f"{a.out_dir}/corpus_transcrit_{variante}.jsonl"
        sortie = construit(docs, variante, a.seed)
        with open(chemin, "w", encoding="utf-8") as f:
            for d in sortie:
                f.write(json.dumps(d, ensure_ascii=False) + "\n")
        nb = sum(len(d["entities"]) for d in sortie)
        print(f"{chemin} : {len(sortie)} documents, {nb} entités")


if __name__ == "__main__":
    main()
