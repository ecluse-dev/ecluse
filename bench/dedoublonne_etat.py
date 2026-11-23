#!/usr/bin/env python3
"""Dédoublonne `bench/ETAT.md` et prouve qu'aucune ligne n'est perdue (P2-257).

    python3 bench/dedoublonne_etat.py ecrit   AVANT.md APRES.md
    python3 bench/dedoublonne_etat.py verifie AVANT.md APRES.md

`ecrit` lit AVANT et écrit APRES (AVANT n'est jamais modifié) : un titre `## `
qui revient est supprimé à sa seconde occurrence quand les deux blocs sont
identiques. Le seul bloc divergent (« SIREN nommé ») est fusionné : préambule
de la première copie (il dit le chemin mesuré ligne par ligne), préambule de la
seconde conservé tel quel sous une ligne d'introduction, table et paragraphe
final de la seconde (la première porte cinq lignes recopiées de la section
P2-143, hors sujet ici, déjà présentes dans leur propre section).

`verifie` n'écrit rien. Il imprime les titres `## ` encore en double, les lignes
de APRES absentes de AVANT (seules `LIGNES_DE_FUSION` sont permises) et les
lignes de AVANT absentes de APRES. Code de sortie non nul si un titre reste en
double ou si une ligne nouvelle n'est pas listée.

Le fichier ne contient que des comptes et des noms de mesure : le script
n'imprime que des lignes de ce fichier.
"""

import collections
import sys

TITRE_SIREN = "## SIREN nommé : type `siren` (P2-248)"
ANCRE_ENTETE = "Fiabilité du script (P2-168)."

PARAGRAPHE_ENTETE = [
    "Dédoublonnage (P2-257, 22 novembre 2026, base `main` au commit `91d009c`) :",
    "18 titres de section figuraient deux fois (17 blocs identiques, 1 divergent,",
    "« SIREN nommé ») ; chacun ne figure plus qu'une fois, à sa première place. Aucun",
    "chiffre n'a changé ; le script `bench/dedoublonne_etat.py` le vérifie.",
    "",
]
INTRO_PREAMBULE = [
    "Formulation de la seconde copie de la section (conservée, P2-257) :",
]
LIGNES_DE_FUSION = set(PARAGRAPHE_ENTETE + INTRO_PREAMBULE) - {""}


def sections(lignes):
    """[(titre, début, fin)] : les `## ` hors blocs de code."""
    bornes, clos = [], False
    for i, l in enumerate(lignes):
        if l.startswith("```"):
            clos = not clos
        if not clos and l.startswith("## "):
            bornes.append(i)
    bornes.append(len(lignes))
    return [(lignes[bornes[k]], bornes[k], bornes[k + 1]) for k in range(len(bornes) - 1)]


def doublons(lignes):
    vus = collections.defaultdict(list)
    for t, a, b in sections(lignes):
        vus[t].append((a, b))
    return {t: v for t, v in vus.items() if len(v) > 1}


def debut_table(bloc):
    return next(i for i, l in enumerate(bloc) if l.startswith("| Mesure"))


def ecrit(avant, apres):
    lignes = open(avant, encoding="utf-8").read().split("\n")
    retirer = set()
    fusion = None
    for titre, occ in doublons(lignes).items():
        if titre == TITRE_SIREN:
            (a1, b1), (a2, b2) = occ
            c1, c2 = lignes[a1:b1], lignes[a2:b2]
            t1, t2 = debut_table(c1), debut_table(c2)
            pre2 = c2[2:t2]  # sans le titre et la ligne vide qui le suit
            while pre2 and not pre2[-1].strip():
                pre2.pop()
            fusion = (a1, b1, c1[:t1] + INTRO_PREAMBULE + [""] + pre2 + [""] + c2[t2:])
            retirer.update(range(a2, b2))
            continue
        if len({"\n".join(lignes[a:b]) for a, b in occ}) != 1:
            sys.exit("ÉCHEC : bloc divergent inattendu : " + titre)
        for a, b in occ[1:]:
            retirer.update(range(a, b))
    if fusion is None:
        sys.exit("ÉCHEC : bloc « SIREN nommé » introuvable")
    a1, b1, bloc = fusion
    sortie = []
    for i, l in enumerate(lignes):
        if i == a1:
            sortie.extend(bloc)
        if a1 <= i < b1 or i in retirer:
            continue
        if l == ANCRE_ENTETE or l.startswith(ANCRE_ENTETE):
            sortie.extend(PARAGRAPHE_ENTETE)
        sortie.append(l)
    open(apres, "w", encoding="utf-8").write("\n".join(sortie))


def verifie(avant, apres):
    a = open(avant, encoding="utf-8").read().split("\n")
    p = open(apres, encoding="utf-8").read().split("\n")
    sa, sp = set(a), set(p)
    d = doublons(p)
    nouvelles = [l for l in p if l not in sa]
    perdues = [l for l in a if l not in sp]
    hors_liste = [l for l in nouvelles if l not in LIGNES_DE_FUSION]
    print(f"titres `## ` en double avant : {len(doublons(a))}, après : {len(d)}")
    print(f"lignes de APRES absentes de AVANT : {len(nouvelles)} "
          f"(dont hors liste de fusion : {len(hors_liste)})")
    for l in nouvelles:
        print("  +", l)
    print(f"lignes de AVANT absentes de APRES : {len(perdues)}")
    for l in perdues:
        print("  -", l)
    return 1 if (d or hors_liste) else 0


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in ("ecrit", "verifie"):
        sys.exit(__doc__)
    if sys.argv[1] == "ecrit":
        ecrit(sys.argv[2], sys.argv[3])
    else:
        sys.exit(verifie(sys.argv[2], sys.argv[3]))
