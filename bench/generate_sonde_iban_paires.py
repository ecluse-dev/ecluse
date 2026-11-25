#!/usr/bin/env python3
"""Sonde élargie de l'IBAN écrit en paires (P2-293, mesure, rien corrigé).

P2-288 a chiffré cinq gardes contre les faux accords « FR + séparateur + clé +
onze paires + un caractère » sur une sonde à **espaces seuls**. Cette sonde couvre
les quatre séparateurs que la forme de `_candidatePaires` accepte (espace, point,
tiret, barre) et deux corps (chiffres seuls ; chiffres avec confusions d'OCR
0→O/o, 1→l/I), pour des IBAN à clé juste et à clé fausse, et pour des références
**qui ne sont pas des IBAN** (négatifs, gabarits de commande ou de pièce comme
les 13 faux accords de P2-279).

Chaque document annote une seule séquence (`type` « iban » pour les positifs,
« rien » pour les négatifs, non annotés). Champs : `famille` (iban_cle_juste,
iban_cle_fausse, reference), `sep`, `corps` (chiffres, ocr), `phrase` (neutre :
sans mot bancaire ; motcle : « Virement vers … », « Coordonnées bancaires : … »).
Synthétique, identifiants fabriqués par `generate_corpus`, graine fixe.

Usage : python3 generate_sonde_iban_paires.py --n 40 --seed 42 --out sonde.jsonl
"""
import argparse
import json
import random

from generate_corpus import make_iban

SEPARATEURS = {"espace": " ", "point": ".", "tiret": "-", "barre": "/"}
NEUTRE = ["Valeur reportée sur la fiche : {v} à vérifier.",
          "Merci de recopier {v} dans la case prévue.",
          "Pièce jointe 3 : {v} puis signature."]
MOTCLE = ["Virement vers {v} prévu lundi.",
          "Coordonnées bancaires : {v} (compte joint)."]
REFERENCE = ["Étiquette inventaire {v} collée sous le boîtier.",
             "Le lot {v} est mis en quarantaine jusqu'à vérification.",
             "Commande {v} expédiée, colis suivi."]
CONFUSIONS = {"0": ["O", "o"], "1": ["l", "I"]}


def fausse_cle(iban, rng):
    cle = int(iban[2:4])
    return f"FR{(cle + rng.randrange(1, 90)) % 97 or 5:02d}" + iban[4:]


def confond(corps, rng):
    """Remplace jusqu'à cinq 0 ou 1 du corps par une lettre d'OCR (au moins un)."""
    pos = [i for i, c in enumerate(corps) if c in "01"]
    rng.shuffle(pos)
    chars = list(corps)
    if not pos:  # aucune confusion possible : au moins une lettre quand même
        chars[rng.randrange(len(chars))] = "O"
    for i in pos[:5]:
        chars[i] = rng.choice(CONFUSIONS[chars[i]])
    return "".join(chars)


def en_paires(identifiant, sep, corps, rng):
    """`FR` + sép + clé + onze paires + un caractère, un seul séparateur."""
    cle, reste = identifiant[2:4], identifiant[4:]
    if corps == "ocr":
        reste = confond(reste, rng)
    paires = [reste[i:i + 2] for i in range(0, 22, 2)]
    return sep.join(["FR", cle] + paires + [reste[22]])


def reference(rng):
    """Référence qui n'est pas un IBAN : même forme, chiffres tirés au hasard."""
    return "FR" + "".join(rng.choice("0123456789") for _ in range(25))


def construit(n, seed):
    rng = random.Random(seed)
    docs = []

    def ajoute(modele, v, type_, famille, sep, corps, phrase):
        texte = modele.format(v=v)
        d = texte.index(v)
        docs.append({"id": len(docs), "text": texte,
                     "entities": [{"type": type_, "start": d, "end": d + len(v)}]
                     if type_ else [],
                     "famille": famille, "sep": sep, "corps": corps, "phrase": phrase,
                     "presentation": "sonde_paires"})

    for famille in ("iban_cle_juste", "iban_cle_fausse"):
        for sep in SEPARATEURS:
            for corps in ("chiffres", "ocr"):
                for k in range(n):
                    iban = make_iban(rng)
                    if famille == "iban_cle_fausse":
                        iban = fausse_cle(iban, rng)
                    v = en_paires(iban, SEPARATEURS[sep], corps, rng)
                    phrase, modeles = ("motcle", MOTCLE) if k % 2 else ("neutre", NEUTRE)
                    ajoute(rng.choice(modeles), v, "iban", famille, sep, corps, phrase)
    for sep in SEPARATEURS:
        for corps in ("chiffres", "ocr"):
            for k in range(n):
                v = en_paires(reference(rng), SEPARATEURS[sep], corps, rng)
                ajoute(rng.choice(REFERENCE), v, None, "reference", sep, corps, "neutre")
    return docs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=40)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    docs = construit(a.n, a.seed)
    with open(a.out, "w", encoding="utf-8") as f:
        for d in docs:
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
    print(f"{len(docs)} documents écrits dans {a.out}")


if __name__ == "__main__":
    main()
