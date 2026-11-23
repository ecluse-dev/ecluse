#!/usr/bin/env python3
"""Corpus « fuite par OCR sans libellé » (P2-264, mesure).

P2-191 couvre « O » pour 0 et « l » ou « I » pour 1 **derrière un libellé fort** ;
P2-254 l'IBAN à clé fausse avec « O ». Sans libellé, un identifiant à clé juste
écrit avec ces lettres part en clair (compte rendu du 23 novembre matin). Ce
générateur mesure l'étendue : rien n'est corrigé.

Cinq types (NIR, RPPS, IBAN FR, FINESS, SIREN), à clé **juste** avant la
confusion, trois confusions :

  zero    : au moins un 0 devient « O » ou « o »
  un      : au moins un 1 devient « l » ou « I »
  les_deux: les deux à la fois

et deux présentations, `libelle` (« NIR : », « IBAN : », « RPPS : », « FINESS : »,
« SIREN : ») et `sans_libelle` (une phrase ordinaire, aucun mot-clé). Identifiants
**synthétiques** (clés calculées par `generate_corpus`), graine fixe.

Témoin négatif (`entities` vide) : mots et références ordinaires qui contiennent
des « O », « l » et « I » (un mot en capitales, un code de lot, une référence
alphanumérique, une phrase de consigne). Toute prédiction y est un masquage en trop.

**Témoin durci (P2-268)** : 450 documents `temoin_dur` (cinq familles de 90 :
`commande`, `lot`, `produit`, `piece`, `informatique`), sans identifiant, faits de
suites denses en « O », « o », « l », « I » et en chiffres, séparées en groupes.
Les longueurs sont choisies pour ce qui compte : 9, 11 et 15 caractères
(les longueurs d'un SIREN/FINESS, d'un RPPS et d'un NIR une fois relus), et des
suites « FR » + 25 caractères (la longueur d'un IBAN français), en plus de
longueurs ordinaires de 6 à 20. Ajoutés **après** les 1 600 documents d'origine,
sans changer ceux-ci (mêmes identifiants, même ordre). Toute prédiction y est un
masquage en trop ; un accord est compté par type.

Usage :
    python3 generate_corpus_ocr.py --n 40 --seed 42 --out flou/corpus_ocr.jsonl
"""

import argparse
import json
import random

from generate_corpus import (fmt_finess, fmt_iban, fmt_nir, fmt_rpps,
                             fmt_siren, make_finess, make_iban, make_nir,
                             make_rpps, make_siren)

TYPES = ("nir", "rpps", "iban", "finess", "siren")
CONFUSIONS = ("zero", "un", "les_deux")
LIBELLES = {"nir": "NIR", "rpps": "RPPS", "iban": "IBAN", "finess": "FINESS",
            "siren": "SIREN"}

FABRIQUE = {"nir": make_nir, "rpps": make_rpps, "iban": make_iban,
            "finess": make_finess, "siren": make_siren}
FORMAT = {"nir": fmt_nir, "rpps": fmt_rpps, "iban": fmt_iban,
          "finess": fmt_finess, "siren": fmt_siren}

PHRASES_SANS_LIBELLE = [
    "Valeur relevée sur le scan : {v} à vérifier.",
    "Le champ saisi porte {v} dans la case de droite.",
    "Recopié depuis la pièce jointe : {v} puis signature.",
    "Ligne 4 du tableau : {v} (voir annexe).",
]

NEGATIFS = [
    "Le colloque OCELOT est reporté, la salle IO est réservée.",
    "Lot OL10-IO1 reçu, contrôle visuel : OK.",
    "Référence interne IL OI LO à ne pas confondre avec le dossier voisin.",
    "Consigne : lire la ligne l, puis la ligne I, puis la ligne O.",
    "Code produit OOIL-lOl0 en rayon 11, étage 0.",
    "Tableau des salles : IO1, IO2, OI3, lO4, Il5, lI6.",
    "Le protocole OLLI prévoit 10 minutes puis 1 heure de repos.",
    "Planning : L1 O0 I1 l0 o1 (lettres et chiffres alternés).",
    "Bon de commande 110 011 101 : vérifier la ligne 1 et la ligne 0.",
    "Référence de série ILIOOLI à saisir en majuscules.",
]


ALPHABET_DENSE = "0123456789OolI"
SEPARATEURS_DENSES = (" ", "-", ".", "/", "\u00a0")

FAMILLES_DURCIES = {
    "commande": ["Commande {v} expédiée, colis suivi sous la référence indiquée.",
                 "Bon de commande n° {v} à rapprocher de la facture.",
                 "Suivi du colis {v} : en cours de livraison."],
    "lot": ["Lot {v} reçu, contrôle visuel effectué.",
            "Numéro de lot {v} à reporter sur le registre des réceptions.",
            "Le lot {v} est mis en quarantaine jusqu'à vérification."],
    "produit": ["Code produit {v} en rayon, quantité en stock confirmée.",
                "Article {v} : rupture annoncée pour la semaine prochaine.",
                "Référence catalogue {v}, conditionnement par dix."],
    "piece": ["Numéro de pièce {v} gravé sur le capot, côté droit.",
              "Pièce détachée {v} commandée auprès du fournisseur.",
              "Plan {v} indice B, à imprimer en format A3."],
    "informatique": ["Poste {v} redémarré après la mise à jour.",
                     "Identifiant machine {v} à saisir dans l'inventaire.",
                     "Étiquette inventaire {v} collée sous le boîtier."],
}

# (longueur de la suite, poids) : ce qui compte pour les types validés.
LONGUEURS_CRITIQUES = (9, 11, 15)


def suite_dense(rng):
    """Suite synthétique de l'alphabet [0-9OolI], au moins une lettre d'OCR,
    groupée par des séparateurs. Retourne (texte, nombre de caractères utiles)."""
    tirage = rng.random()
    if tirage < 0.06:
        prefixe, n = "FR", 25
    elif tirage < 0.30:
        prefixe, n = "", rng.choice(LONGUEURS_CRITIQUES)
    else:
        prefixe, n = "", rng.randint(6, 20)
    while True:
        chars = [rng.choice(ALPHABET_DENSE) for _ in range(n)]
        if any(c in "OolI" for c in chars):
            break
    sep = rng.choice(SEPARATEURS_DENSES)
    groupe = rng.choice((2, 3, 4, 5))
    morceaux = ["".join(chars[i:i + groupe]) for i in range(0, n, groupe)]
    return prefixe + (sep if prefixe and rng.random() < 0.5 else "") \
        + sep.join(morceaux)


def temoin_dur(famille, rng):
    phrase = rng.choice(FAMILLES_DURCIES[famille])
    return {"text": phrase.format(v=suite_dense(rng)), "entities": [],
            "type_id": "", "confusion": "", "presentation": "temoin_dur",
            "famille": famille}


def positions(valeur, car, debut):
    return [i for i in range(debut, len(valeur)) if valeur[i] == car]


def confond(valeur, type_id, confusion, rng):
    """Remplace au moins un chiffre par sa lettre d'OCR ; None si impossible."""
    debut = 2 if type_id == "iban" else 0
    chars = list(valeur)
    fait = False
    if confusion in ("zero", "les_deux"):
        pos = positions(valeur, "0", debut)
        for p in [p for p in pos if rng.random() < 0.5] or pos[:1]:
            chars[p] = rng.choice("Oo")
            fait = True
        if not pos:
            return None
    if confusion in ("un", "les_deux"):
        pos = positions(valeur, "1", debut)
        if not pos:
            return None
        for p in [p for p in pos if rng.random() < 0.5] or pos[:1]:
            chars[p] = rng.choice("lI")
            fait = True
    return "".join(chars) if fait else None


def positif(type_id, confusion, avec_libelle, rng):
    for _ in range(1000):
        brut = FABRIQUE[type_id](rng)
        lettre = confond(brut, type_id, confusion, rng)
        if lettre is None:
            continue
        # Mise en forme : on reproduit celle du générateur principal sur la
        # valeur d'origine, puis on reporte les lettres aux mêmes positions
        # (le formatage n'ajoute que des blancs et des séparateurs).
        forme = FORMAT[type_id](brut, rng)
        sortie, k = [], 0
        for c in forme:
            if k < len(brut) and c == brut[k]:
                sortie.append(lettre[k])
                k += 1
            else:
                sortie.append(c)
        valeur = "".join(sortie)
        if k != len(brut):
            continue
        if avec_libelle:
            debut = f"{LIBELLES[type_id]} : "
            texte = f"{debut}{valeur} noté au dossier."
        else:
            phrase = rng.choice(PHRASES_SANS_LIBELLE)
            debut = phrase[:phrase.index("{v}")]
            texte = phrase.format(v=valeur)
        return {"text": texte,
                "entities": [{"type": type_id, "start": len(debut),
                              "end": len(debut) + len(valeur)}],
                "type_id": type_id, "confusion": confusion,
                "presentation": "libelle" if avec_libelle else "sans_libelle"}
    raise RuntimeError("aucun identifiant adapté")  # pragma: no cover


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--n", type=int, default=40,
                   help="documents par (type, confusion, présentation)")
    p.add_argument("--n-dur", type=int, default=90,
                   help="documents du témoin durci par famille (5 familles)")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", required=True)
    a = p.parse_args()
    rng = random.Random(a.seed)
    docs = []
    for t in TYPES:
        for c in CONFUSIONS:
            for avec in (True, False):
                for _ in range(a.n):
                    docs.append(positif(t, c, avec, rng))
    for _ in range(a.n * 10):
        docs.append({"text": rng.choice(NEGATIFS), "entities": [],
                     "type_id": "", "confusion": "", "presentation": "temoin"})
    # Témoin durci (P2-268) : après les documents d'origine, pour ne rien
    # changer à leur contenu ni à leurs identifiants.
    for famille in FAMILLES_DURCIES:
        for _ in range(a.n_dur):
            docs.append(temoin_dur(famille, rng))
    for i, d in enumerate(docs):
        d["id"] = i
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents -> {a.out}")


if __name__ == "__main__":
    main()
