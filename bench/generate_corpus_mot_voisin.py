#!/usr/bin/env python3
"""Corpus « mot voisin devant un identifiant dicté abîmé » (P2-292, mesure).

P2-282 coupe le signalement « nombre dicté non reconnu » quand « code »,
« digicode », « mot de passe », « mdp » ou « pin » précède la suite dans les 100
caractères, sauf libellé d'identifiant dans la même fenêtre. P2-280 n'a pas pu
mesurer son coût : aucun document n'a de mot voisin devant un identifiant.

Ce générateur part des identifiants dictés abîmés de P2-274
(`corpus_dicte_non_valide_{mot_perdu,cle_fausse}.jsonl`, un NIR ou IBAN abîmé par
document) et insère, juste avant l'identifiant, une amorce où le mot voisin
commence à `d` caractères du début de l'identifiant. Trois bras par distance :

  temoin   : mêmes `d` caractères, avec des mots neutres, sans mot voisin ;
  sans_lib : <mot> + mots neutres ;
  avec_lib : <mot> <libellé> + mots neutres (« code iban … »).

Les mots neutres ne sont ni des mots-nombres ni des libellés ni des mots voisins.
Un seul document source donne donc 1 + 5 × 2 = 11 documents par distance. Aucune
valeur n'est imprimée. Synthétique, graine fixe.

Usage :
    python3 generate_corpus_mot_voisin.py --in-dir transcrit --out-dir transcrit \
        --n 600 --seed 42
"""
import argparse
import json
import random
import re

MOTS_VOISINS = ["code", "digicode", "mot de passe", "mdp", "pin"]
LIBELLES = ["nir", "iban", "rib", "sécu", "compte"]
DISTANCES = [25, 40, 60, 80, 100, 101, 120]
# Miroir de `_motVoisin` et `_libelleIdentifiant` (lib/src/nombres_dictes.dart),
# pour classer les documents : le libellé d'origine du document compte aussi.
RE_VOISIN = re.compile(r"(?<![^\W\d_])(?:code|digicode|mot de passe|mdp|pin)(?![^\W\d_])",
                       re.I)
RE_LIBELLE = re.compile(
    r"(?<![^\W\d_])(?:nir|s[ée]cu|s[ée]curit[ée] sociale|ss|assur[ée]e?|iban|rib|"
    r"compte|bancaire|banque|virement|rpps|finess|siren|adeli|identifiant)(?![^\W\d_])",
    re.I)
# Mots neutres par longueur (ni nombre, ni libellé, ni mot voisin).
NEUTRES = {
    1: ["a", "à", "y"],
    2: ["de", "du", "la", "le", "en", "au", "ce", "se", "ma"],
    3: ["les", "des", "une", "sur", "par", "est", "ici", "bon", "pas"],
    4: ["pour", "dans", "avec", "mais", "sont", "elle", "vers", "dont", "cela"],
    5: ["entre", "porte", "grand", "reste", "avait", "faire", "sous"],
    6: ["devant", "depuis", "aucune", "enfin", "salle", "garage"],
    7: ["pendant", "service", "ancien", "chambre", "demande"],
}


def mots_neutres(longueur, rng):
    """Suite de mots neutres de `longueur` caractères exactement (espaces compris)."""
    if longueur <= 0:
        return ""
    while True:
        mots, reste = [], longueur
        while reste > 0:
            if reste <= 7:
                w = rng.choice(NEUTRES[reste])
                mots.append(w)
                reste = 0
            else:
                k = rng.randint(2, min(7, reste - 2))
                mots.append(rng.choice(NEUTRES[k]))
                reste -= k + 1
        s = " ".join(mots)
        if len(s) == longueur:
            return s


def amorce(texte, debut, mot, lib, d, rng):
    """Amorce à insérer avant `debut` : le mot (ou des mots neutres de même
    longueur) commence exactement à `d` caractères de `debut`."""
    espace = "" if debut == 0 or texte[debut - 1] == " " else " "
    if mot is None:
        return espace + mots_neutres(d - 1, rng) + " "
    tete = mot + (" " + lib if lib else "")
    ecart = d - len(tete) - 2  # un espace de chaque côté des mots neutres
    return espace + tete + " " + (mots_neutres(ecart, rng) + " " if ecart > 0 else "")


def doc(src, texte, debut, fin, ident, mot, lib, d, bras):
    return {"id": ident, "text": texte,
            "entities": [{"type": src["entities"][0]["type"], "start": debut, "end": fin}],
            "variante": src.get("variante"), "mode": src["mode"],
            "bras": bras, "mot": mot, "libelle": lib, "d": d, "source": src["id"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in-dir", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--n", type=int, default=500,
                    help="documents sources sans libellé d'origine, par mode")
    ap.add_argument("--n-avec", type=int, default=100, dest="n_avec",
                    help="documents sources avec libellé d'origine, par mode")
    ap.add_argument("--seed", type=int, default=42)
    a = ap.parse_args()
    for mode in ("mot_perdu", "cle_fausse"):
        src = [json.loads(l) for l in
               open(f"{a.in_dir}/corpus_dicte_non_valide_{mode}.jsonl", encoding="utf-8")]
        rng = random.Random(f"{a.seed}-voisin-{mode}")
        # Deux strates : A, sans libellé d'identifiant dans les 100 caractères
        # d'origine avant l'identifiant (le seul cas où la garde est en jeu) ;
        # B, avec libellé d'origine (le libellé suffit déjà à garder le signalement).
        rng.shuffle(src)
        def sans_libelle(x):
            deb = x["entities"][0]["start"]
            return not RE_LIBELLE.search(x["text"][max(0, deb - 100): deb])
        strate_a = [x for x in src if sans_libelle(x)][: a.n]
        strate_b = [x for x in src if not sans_libelle(x)][: a.n_avec]
        src = sorted(strate_a + strate_b, key=lambda x: x["id"])
        sortie = []
        for s in src:
            e = s["entities"][0]
            t, deb = s["text"], e["start"]
            for d in DISTANCES:
                variantes = [(None, None, "temoin")]
                for mot in MOTS_VOISINS:
                    variantes.append((mot, None, "sans_lib"))
                    variantes.append((mot, rng.choice(LIBELLES), "avec_lib"))
                for mot, lib, bras in variantes:
                    r = random.Random(f"{a.seed}-{mode}-{s['id']}-{d}-{mot}-{bras}")
                    ins = amorce(t, deb, mot, lib, d, r)
                    texte = t[:deb] + ins + t[deb:]
                    nd, nf = deb + len(ins), e["end"] + len(ins)
                    fenetre = texte[max(0, nd - 100): nd]
                    if mot is not None:
                        assert nd - texte.rfind(mot, 0, nd) == d, "distance du mot voisin"
                    x = doc(s, texte, nd, nf, len(sortie), mot, lib, d, bras)
                    x["lib_fenetre"] = bool(RE_LIBELLE.search(fenetre))
                    x["voisin_fenetre"] = bool(RE_VOISIN.search(fenetre))
                    sortie.append(x)
        chemin = f"{a.out_dir}/corpus_mot_voisin_{mode}.jsonl"
        with open(chemin, "w", encoding="utf-8") as f:
            for x in sortie:
                f.write(json.dumps(x, ensure_ascii=False) + "\n")
        print(f"{mode} : {len(strate_a)} + {len(strate_b)} sources, {len(sortie)} documents -> {chemin}")


if __name__ == "__main__":
    main()
