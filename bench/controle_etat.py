#!/usr/bin/env python3
"""Contrôle de `bench/ETAT.md` contre la sortie de `bench/etat.sh` (P2-265).

`ETAT.md` raconte l'historique section par section ; un chiffre y vieillit sans
que rien ne le signale (la session du 23 novembre après-midi a trouvé 3 lignes
en retard sur 8 vérifiées). Ce script contrôle la partie **courante** : le
bloc délimité par `<!-- controle:debut -->` et `<!-- controle:fin -->` dans la
section « Valeurs courantes contrôlées », extrait verbatim de la sortie
d'`etat.sh`. Tout le reste du fichier est de l'historique daté, ignoré.

Un bloc a la forme de la sortie d'`etat.sh` : des titres `## …` suivis de leurs
lignes. Chaque ligne du bloc doit se retrouver, dans l'ordre, sous le même
titre de la sortie (espaces écrasés) ; la ligne `## commit …` est ignorée. Le
script sort en erreur au **premier** écart et affiche la ligne fautive du bloc
(avec son numéro dans `ETAT.md`) et la ligne de la sortie qui lui ressemble le
plus. Il ne lit que des comptes : aucun texte de document n'est en jeu.

Usage :
    python3 controle_etat.py etat.log [ETAT.md]       # contrôle (code 0 / 1)
    python3 controle_etat.py --propose etat.log       # imprime le bloc à coller
"""

import difflib
import os
import re
import sys

DEBUT = "<!-- controle:debut -->"
FIN = "<!-- controle:fin -->"
ICI = os.path.dirname(os.path.abspath(__file__))


def normalise(ligne):
    return re.sub(r"\s+", " ", ligne).strip()


def sections(lignes):
    """{titre: [lignes normalisées non vides]} ; `## commit` est ignoré."""
    res, courant = {}, None
    for l in lignes:
        if l.startswith("## "):
            courant = None if l.startswith("## commit") else normalise(l)
            if courant is not None:
                res.setdefault(courant, [])
        elif courant is not None and l.strip():
            res[courant].append(normalise(l))
    return res


def bloc(etat_texte):
    """(lignes du bloc, numéro de la première ligne) ; erreur s'il manque."""
    lignes = etat_texte.splitlines()
    try:
        i = next(k for k, l in enumerate(lignes) if l.strip() == DEBUT)
        j = next(k for k, l in enumerate(lignes) if l.strip() == FIN)
    except StopIteration:
        raise ValueError(f"bloc {DEBUT} … {FIN} introuvable dans ETAT.md")
    if j < i:
        raise ValueError("bloc de contrôle mal délimité (fin avant début)")
    # Le bloc est dans une clôture ``` : on saute les lignes de clôture.
    contenu = [(k + 1, lignes[k]) for k in range(i + 1, j)
               if not lignes[k].startswith("```")]
    return contenu


def controle(etat_texte, log_texte):
    """Rend la liste des écarts (vide si ETAT.md est à jour)."""
    attendu = bloc(etat_texte)
    observe = sections(log_texte.splitlines())
    ecarts, courant, pos = [], None, 0
    vus = set()
    for numero, ligne in attendu:
        if ligne.startswith("## "):
            courant, pos = normalise(ligne), 0
            vus.add(courant)
            if courant not in observe:
                ecarts.append(f"ETAT.md:{numero} : section absente de la "
                              f"sortie : {courant}")
                courant = None
            continue
        if not ligne.strip() or courant is None:
            continue
        cible = normalise(ligne)
        lignes_log = observe[courant]
        try:
            pos = lignes_log.index(cible, pos) + 1
        except ValueError:
            proche = difflib.get_close_matches(cible, lignes_log, 1, 0.0)
            ecarts.append(
                f"ETAT.md:{numero} : ligne périmée sous « {courant} »\n"
                f"  ETAT.md : {cible}\n"
                f"  sortie  : {proche[0] if proche else '(section vide)'}")
    # Une section de la sortie absente du bloc est aussi un écart : un tableau
    # de bord qui grossit sans que ETAT.md suive ne passe plus inaperçu.
    for titre in observe:
        if titre not in vus:
            ecarts.append(f"section de la sortie absente d'ETAT.md : {titre}")
    return ecarts


def propose(log_texte):
    """Le bloc à coller dans ETAT.md, extrait de la sortie."""
    sortie = ["```", ]
    for titre, lignes in sections(log_texte.splitlines()).items():
        sortie.append(titre)
        sortie.extend(lignes)
    sortie.append("```")
    return "\n".join(sortie)


def main(argv):
    if len(argv) >= 3 and argv[1] == "--propose":
        print(DEBUT)
        print(propose(open(argv[2], encoding="utf-8").read()))
        print(FIN)
        return 0
    if len(argv) not in (2, 3):
        print(__doc__)
        return 2
    chemin_etat = argv[2] if len(argv) == 3 else os.path.join(ICI, "ETAT.md")
    try:
        ecarts = controle(open(chemin_etat, encoding="utf-8").read(),
                          open(argv[1], encoding="utf-8").read())
    except ValueError as e:
        print(f"ÉCHEC : {e}")
        return 1
    if ecarts:
        print(ecarts[0])
        if len(ecarts) > 1:
            print(f"… et {len(ecarts) - 1} autre(s) écart(s)")
        return 1
    print("ETAT.md : valeurs courantes conformes à la sortie d'etat.sh")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
