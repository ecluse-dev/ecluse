#!/usr/bin/env python3
"""Sonde de rappel de P2-272 (mesure) : identifiants **à clé fausse** et adresses
écrits de façons plausibles mais irrégulières, que les corpus du dépôt n'ont pas
(tous écrivent l'IBAN en groupes de quatre, le NIR en groupes standard). Sert à
chiffrer ce que perdrait chaque garde de forme proposée. Synthétique, graine
fixe, identifiants fabriqués par `generate_corpus` puis clé volontairement
fausse. Chaque document annote un seul identifiant (`famille`, `ecriture`,
`phrase` : « neutre » sans mot-clé voisin, « motcle » avec un mot-clé voisin).

Usage : python3 generate_sonde_gardes.py --n 40 --seed 42 --out sonde.jsonl
"""
import argparse
import json
import random

from generate_corpus import make_finess, make_iban, make_nir

NEUTRE = ["Valeur reportée sur la fiche : {v} à vérifier.",
          "Merci de recopier {v} dans la case prévue.",
          "Pièce jointe 3 : {v} puis signature."]
MOTCLE_IBAN = ["Virement vers {v} prévu lundi.",
               "Coordonnées bancaires : {v} (compte joint)."]
MOTCLE_NIR = ["Patient assuré sous {v} à la sécu.",
              "Carte vitale du résident : {v}."]


def fausse_cle_iban(iban, rng):
    cle = int(iban[2:4])
    return f"FR{(cle + rng.randrange(1, 90)) % 97 or 5:02d}" + iban[4:]


def ecrit_iban(iban, style, rng):
    s = iban
    if style == "compact":
        return s
    if style == "quatre":
        return " ".join(s[i:i + 4] for i in range(0, 27, 4))
    if style == "quatre_points":
        return ".".join(s[i:i + 4] for i in range(0, 27, 4))
    if style == "rib":
        return f"{s[:4]} {s[4:9]} {s[9:14]} {s[14:25]} {s[25:]}"
    if style == "cinq":
        return " ".join([s[:4]] + [s[i:i + 5] for i in range(4, 24, 5)] + [s[24:]])
    if style == "trois":
        return " ".join([s[:4]] + [s[i:i + 3] for i in range(4, 27, 3)])
    if style == "paires":
        return " ".join(s[i:i + 2] for i in range(0, 27, 2))
    if style == "cle_o":
        return "FR" + s[2:4].replace("0", "o") + " " + " ".join(s[i:i + 4] for i in range(4, 27, 4)) if "0" in s[2:4] else "FRo" + s[3] + " " + " ".join(s[i:i + 4] for i in range(4, 27, 4))
    if style == "corps_ocr5":
        chars = list(s)
        pos = [i for i in range(4, 27) if chars[i] in "01"]
        rng.shuffle(pos)
        for i in pos[:5]:
            chars[i] = {"0": "O", "1": "l"}[chars[i]]
        s2 = "".join(chars)
        return " ".join(s2[i:i + 4] for i in range(0, 27, 4))
    raise ValueError(style)


def fausse_cle_nir(nir, rng):
    cle = int(nir[13:])
    return nir[:13] + f"{(cle + rng.randrange(1, 90)) % 97 or 5:02d}"


def ecrit_nir(nir, style):
    p = [nir[0], nir[1:3], nir[3:5], nir[5:7], nir[7:10], nir[10:13], nir[13:15]]
    if style == "compact":
        return nir
    if style == "standard":
        return " ".join(p)
    if style == "points":
        return ".".join(p)
    if style == "une_lettre":
        return " ".join(p).replace("0", "o", 1) if "0" in nir else " ".join(p)
    if style == "deux_lettres":
        return " ".join(p).replace("0", "o", 2) if nir.count("0") >= 2 else " ".join(p).replace("0", "o", 1)
    raise ValueError(style)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=40)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    docs = []

    def ajoute(texte_modele, v, typ, famille, ecriture, phrase):
        texte = texte_modele.format(v=v)
        d = texte.index(v)
        docs.append({"id": len(docs), "text": texte,
                     "entities": [{"type": typ, "start": d, "end": d + len(v)}],
                     "famille": famille, "ecriture": ecriture, "phrase": phrase,
                     "presentation": "sonde"})

    for style in ["compact", "quatre", "quatre_points", "rib", "cinq", "trois",
                  "paires", "cle_o", "corps_ocr5"]:
        for k in range(a.n):
            iban = fausse_cle_iban(make_iban(rng), rng)
            v = ecrit_iban(iban, style, rng)
            phrase = ("motcle", MOTCLE_IBAN) if k % 2 else ("neutre", NEUTRE)
            ajoute(rng.choice(phrase[1]), v, "iban", "iban_cle_fausse", style, phrase[0])
    for style in ["compact", "standard", "points", "une_lettre", "deux_lettres"]:
        for k in range(a.n):
            nir = fausse_cle_nir(make_nir(rng), rng)
            v = ecrit_nir(nir, style)
            phrase = ("motcle", MOTCLE_NIR) if k % 2 else ("neutre", NEUTRE)
            ajoute(rng.choice(phrase[1]), v, "nir", "nir_cle_fausse", style, phrase[0])
    # NIR à clé fausse suivi d'un nombre court (garde « suite »)
    for k in range(a.n):
        nir = fausse_cle_nir(make_nir(rng), rng)
        v = ecrit_nir(nir, "standard")
        ajoute("Dossier {v} 12 pièces jointes reçues.", v, "nir", "nir_cle_fausse",
               "suivi_nombre", "neutre")
    # FINESS Luhn juste sans mot-clé, suivi d'un nombre court (garde « suite »)
    for k in range(a.n):
        f = make_finess(rng)
        ajoute("Rattaché au {v} 12 lits ouverts.", f, "finess", "finess_sans_contexte",
               "suivi_nombre", "neutre")
        ajoute("Rattaché au {v} depuis janvier.", f, "finess", "finess_sans_contexte",
               "seul", "neutre")
    # Adresse « code postal + commune » avec un numéro d'arrondissement
    arr = [("75008", "Paris 8e"), ("69003", "Lyon 3e"), ("13001", "Marseille 1er"),
           ("75015", "Paris 15"), ("69002", "Lyon 2"), ("75008", "Paris"),
           ("69003", "Lyon")]
    for cp, commune in arr:
        for k in range(a.n // 2):
            v = f"{cp} {commune}"
            ajoute("Courrier à renvoyer à {v}.", v, "adresse", "adresse_cp_commune",
                   commune, "neutre")
    # P2-283 : IBAN de clé JUSTE écrit en paires après « FR » (`FR 24 30 00 …`).
    # Ajouté en dernier : les documents précédents (et leur graine) ne changent pas.
    for k in range(a.n):
        v = ecrit_iban(make_iban(rng), "paires", rng)
        phrase = ("motcle", MOTCLE_IBAN) if k % 2 else ("neutre", NEUTRE)
        ajoute(rng.choice(phrase[1]), v, "iban", "iban_cle_juste", "paires", phrase[0])
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out}")


main()
