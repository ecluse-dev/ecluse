#!/usr/bin/env python3
"""Corpus « identifiant annoncé par un libellé fort » (P2-194).

P2-188 (clé fausse) et P2-191 (lecture par OCR : O pour 0, l ou I pour 1,
ligne vide au milieu) ne sont mesurées que par des tests unitaires du
détecteur `IdentifiantCleInvalideDetector`. « Tableau de bord inchangé » ne
prouve rien sur cette voie : aucun corpus du tableau de bord ne contient un
identifiant à clé fausse derrière son libellé. Ce générateur comble le trou.
Il mesure le chemin du produit (`Ecluse.redact`, ce que reçoit le LLM), pas
le moteur seul.

Deux populations, toutes deux synthétiques (clés calculées, graine fixe) :

- **positifs** (`entities` non vide) : un identifiant derrière un libellé
  fort. Axes : `libelle` (NIR, « N° de sécurité sociale », « numéro SS »,
  IBAN, RPPS, ADELI) et `variante` :
  - `cle_juste` : l'identifiant valide, forme ordinaire (référence) ;
  - `cle_fausse` : un chiffre de contrôle faux (P2-188) ;
  - `ocr_zero` : clé juste, la lettre O ou o à la place d'un 0 (P2-191) ;
  - `ocr_un` : clé juste, la lettre l ou I à la place d'un 1 (P2-191) ;
  - `ligne_vide` : clé juste, une ligne vide entre deux groupes (P2-191) ;
  - `ocr_et_ligne_vide` : les deux à la fois.
  Un identifiant dont une partie reste en clair est une fuite.
- **négatifs** (`entities` vide, `temoin_negatif` renseigné) : rien ne doit
  être masqué. `libelle_seul` (« IBAN : voir pièce jointe »),
  `non_communique` (« NIR : non communiqué »), `mot_ordinaire` (un mot du
  texte après le libellé), `nombre_sans_libelle` (le même genre de nombre,
  clé fausse ou lettres d'OCR, sans libellé : « clé validée ou rien » doit
  s'y appliquer). Chaque prédiction sur ces documents est un masquage de
  trop.

Aucun nom, aucune valeur réelle : les identifiants sont tirés par
`generate_corpus` (clés calculées).

Usage :
    python3 generate_corpus_libelle_fort.py --n 50 --seed 42 \\
        --out flou/corpus_libelle_fort.jsonl
"""

import argparse
import json
import random

from generate_corpus import make_adeli, make_iban, make_nir, make_rpps

# (libellé affiché, type d'entité annoté). Les trois libellés de NIR sont
# ceux de `IdentifiantCleInvalideDetector` ; ADELI a son détecteur contextuel.
LIBELLES = [
    ("NIR", "nir"),
    ("N° de sécurité sociale", "nir"),
    ("numéro SS", "nir"),
    ("IBAN", "iban"),
    ("RPPS", "rpps"),
    ("ADELI", "adeli"),
]

VARIANTES = ("cle_juste", "cle_fausse", "ocr_zero", "ocr_un", "ligne_vide",
             "ocr_et_ligne_vide")

NEGATIFS = ("libelle_seul", "non_communique", "mot_ordinaire",
            "nombre_sans_libelle")

SEP_LIBELLE = [": ", " "]

MOTS_ORDINAIRES = {
    "nir": ["de la personne concernée", "du patient", "à compléter"],
    "iban": ["du bénéficiaire", "de la structure", "à fournir"],
    "rpps": ["du praticien", "du médecin traitant", "à vérifier"],
    "adeli": ["de l'infirmière", "du professionnel", "à renseigner"],
}


def fabrique(type_id, rng):
    return {"nir": make_nir, "iban": make_iban, "rpps": make_rpps,
            "adeli": make_adeli}[type_id](rng)


def cle_fausse(type_id, valeur, rng):
    """Même identifiant, dernier(s) chiffre(s) de contrôle faux."""
    if type_id == "nir":
        fausse = (int(valeur[13:15]) + rng.randrange(1, 97)) % 97
        if fausse == int(valeur[13:15]):
            fausse = (fausse + 1) % 97
        return f"{valeur[:13]}{fausse:02d}"
    if type_id == "iban":
        # Deux chiffres de clé différents de la clé juste, restant sur deux
        # chiffres (00 et 01 ne sont jamais produits par la clé juste).
        bonne = int(valeur[2:4])
        mauvaise = rng.choice([k for k in range(2, 98) if k != bonne])
        return f"FR{mauvaise:02d}{valeur[4:]}"
    # RPPS et ADELI : clé de Luhn.
    faux = (int(valeur[-1]) + rng.randrange(1, 10)) % 10
    return valeur[:-1] + str(faux)


def groupes(type_id, valeur):
    """Découpe lisible, comme les gabarits de `generate_corpus`."""
    if type_id == "nir":
        v = valeur
        return [v[0], v[1:3], v[3:5], v[5:7], v[7:10], v[10:13], v[13:15]]
    if type_id == "iban":
        return [valeur[i:i + 4] for i in range(0, len(valeur), 4)]
    if type_id == "rpps":
        return [valeur[:5], valeur[5:10], valeur[10]]
    return [valeur[:3], valeur[3:6], valeur[6:9]]


def peut_lire_zero(type_id, valeur):
    """Positions où un 0 devient O/o : le premier chiffre d'un NIR (1 à 8)
    ne peut pas être 0 ; pour un IBAN, après « FR »."""
    debut = 2 if type_id == "iban" else 0
    return [i for i in range(debut, len(valeur)) if valeur[i] == "0"]


def peut_lire_un(type_id, valeur):
    debut = 2 if type_id == "iban" else 0
    return [i for i in range(debut, len(valeur)) if valeur[i] == "1"]


def confond(valeur, positions, lettres, rng):
    """Remplace au moins une des `positions` (chacune une fois sur deux)."""
    choisies = [p for p in positions if rng.random() < 0.5] or [positions[0]]
    chars = list(valeur)
    for p in choisies:
        chars[p] = rng.choice(lettres)
    return "".join(chars)


def identifiant_avec(type_id, variante, rng):
    """Rend (valeur_brute, groupes_ou_None) pour un positif.
    Tire jusqu'à obtenir un identifiant qui porte un 0 (ou un 1) à lire
    autrement, pour que la variante OCR en soit bien une."""
    for _ in range(1000):
        valeur = fabrique(type_id, rng)
        if variante == "cle_fausse":
            return cle_fausse(type_id, valeur, rng)
        if variante in ("ocr_zero", "ocr_et_ligne_vide"):
            pos = peut_lire_zero(type_id, valeur)
            if not pos:
                continue
            valeur = confond(valeur, pos, "Oo", rng)
            pos_un = peut_lire_un(type_id, valeur)
            if variante == "ocr_et_ligne_vide" and pos_un and rng.random() < 0.5:
                valeur = confond(valeur, pos_un, "lI", rng)
            return valeur
        if variante == "ocr_un":
            pos = peut_lire_un(type_id, valeur)
            if pos:
                return confond(valeur, pos, "lI", rng)
            continue
        return valeur
    raise RuntimeError("aucun identifiant adapté trouvé")  # pragma: no cover


def met_en_forme(type_id, valeur, variante, rng):
    """Texte de l'identifiant : compact, groupes séparés, ou ligne vide."""
    if variante in ("ligne_vide", "ocr_et_ligne_vide"):
        g = groupes(type_id, valeur)
        coupe = rng.randrange(1, len(g))
        sortie = g[0]
        for i in range(1, len(g)):
            sortie += ("\n\n" if i == coupe else " ") + g[i]
        return sortie
    if rng.random() < 0.5:
        return valeur
    return " ".join(groupes(type_id, valeur))


def positif(libelle, type_id, variante, rng):
    valeur = identifiant_avec(type_id, variante, rng)
    texte_id = met_en_forme(type_id, valeur, variante, rng)
    debut = f"{libelle}{rng.choice(SEP_LIBELLE)}"
    texte = f"{debut}{texte_id} noté au dossier."
    return {
        "text": texte,
        "entities": [{"type": type_id, "start": len(debut),
                      "end": len(debut) + len(texte_id)}],
        "libelle": libelle,
        "type_id": type_id,
        "variante": variante,
    }


def nombre_sans_libelle(type_id, rng):
    """Un nombre de la forme d'un identifiant, mais à **clé fausse** (sinon
    le détecteur strict a raison de le masquer), avec une fois sur deux des
    lettres d'OCR, précédé d'un mot qui n'est pas un libellé fort."""
    valeur = cle_fausse(type_id, fabrique(type_id, rng), rng)
    pos = peut_lire_zero(type_id, valeur)
    if pos and rng.random() < 0.5:
        valeur = confond(valeur, pos, "Oo", rng)
    return " ".join(groupes(type_id, valeur)) if rng.random() < 0.5 else valeur


INTRODUCTIONS_NEUTRES = ["Référence interne", "Numéro de lot", "Code article",
                         "Pièce n°", "Bordereau"]


def negatif(libelle, type_id, kind, rng):
    if kind == "libelle_seul":
        texte = f"{libelle} : voir pièce jointe."
    elif kind == "non_communique":
        texte = f"{libelle} : non communiqué, à demander à la famille."
    elif kind == "mot_ordinaire":
        texte = f"{libelle} {rng.choice(MOTS_ORDINAIRES[type_id])} au dossier."
    else:
        texte = (f"{rng.choice(INTRODUCTIONS_NEUTRES)} "
                 f"{nombre_sans_libelle(type_id, rng)} noté au dossier.")
    return {
        "text": texte,
        "entities": [],
        "libelle": libelle,
        "type_id": type_id,
        "temoin_negatif": kind,
    }


def construit(n, seed):
    """`n` positifs par (libellé, variante) ; `n` négatifs par (libellé,
    forme de négatif), dans un ordre stable."""
    rng = random.Random(seed)
    docs = []
    for libelle, type_id in LIBELLES:
        for variante in VARIANTES:
            for _ in range(n):
                docs.append(positif(libelle, type_id, variante, rng))
    for libelle, type_id in LIBELLES:
        for kind in NEGATIFS:
            for _ in range(n):
                docs.append(negatif(libelle, type_id, kind, rng))
    for i, d in enumerate(docs):
        d["id"] = i
    return docs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=50,
                    help="documents par (libellé, variante) et par "
                         "(libellé, témoin négatif)")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    docs = construit(args.n, args.seed)
    with open(args.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    pos = sum(1 for d in docs if d["entities"])
    print(f"{len(docs)} documents écrits dans {args.out} "
          f"({pos} positifs, {len(docs) - pos} négatifs)")


if __name__ == "__main__":
    main()
