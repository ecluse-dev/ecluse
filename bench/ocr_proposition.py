#!/usr/bin/env python3
"""Prototype hors `lib/` de la correction proposée pour P2-264 : combien un
identifiant lu avec des lettres d'OCR (O, o pour 0 ; l, I pour 1) coûterait en
masquages à tort ? Rien n'est branché dans `Ecluse.redact`.

Règle simulée : une suite de 9 à 34 caractères de l'alphabet [0-9OolI], séparés
au plus par un blanc ou un séparateur de groupe, contenant **au moins une
lettre d'OCR**, qui devient un identifiant valide **une fois les lettres relues**
comme des chiffres (NIR : forme + clé mod 97 ; RPPS : 11 chiffres + Luhn ;
IBAN FR : « FR » + 25, mod 97 ; FINESS / SIREN : 9 chiffres + Luhn).

Sorties : comptes seulement (jamais de texte). Par corpus fourni : documents
avec au moins une détection simulée.

Usage :
    python3 ocr_proposition.py flou/corpus_ocr.jsonl [autre.jsonl ...]
"""

import json
import re
import sys

ALPHA = "0-9OolI"
SEUIL = re.compile(rf"(?<![0-9A-Za-z])((?:[{ALPHA}][ .\-]?){{8,33}}[{ALPHA}])(?![0-9A-Za-z])")
IBAN = re.compile(r"(?<![0-9A-Za-z])FR(?:[ ]?[0-9OolIA-Za-z]){23,25}(?![0-9A-Za-z])")


def normalise(s):
    return "".join("0" if c in "Oo" else "1" if c in "lI" else c
                   for c in s if c not in " .-")


def luhn(d):
    s, dbl = 0, False
    for c in reversed(d):
        x = int(c)
        if dbl:
            x = x * 2 - 9 if x * 2 > 9 else x * 2
        s += x
        dbl = not dbl
    return s % 10 == 0


def nir_ok(d):
    if len(d) != 15 or d[0] not in "12":
        return False
    mois = int(d[3:5])
    if not (mois <= 12 or 20 <= mois <= 42 or 50 <= mois <= 99):
        return False
    if int(d[5:7]) < 1 or int(d[10:13]) < 1:
        return False
    return 97 - (int(d[:13]) % 97) == int(d[13:])


def iban_ok(s):
    s = s.replace(" ", "")
    if len(s) != 27:
        return False
    b = s[4:] + "FR00"
    n = "".join(str(ord(c) - 55) if c.isalpha() else c for c in b)
    return 98 - (int(n) % 97) == int(s[2:4])


def detecte(texte):
    n = 0
    for m in SEUIL.finditer(texte):
        brut = m.group(1)
        if not re.search(r"[OolI]", brut):
            continue  # sans lettre d'OCR : détecteurs actuels
        d = normalise(brut)
        if not d.isdigit():
            continue
        if (len(d) == 15 and nir_ok(d)) or (len(d) == 11 and luhn(d)) \
                or (len(d) == 9 and luhn(d)):
            n += 1
    for m in IBAN.finditer(texte):
        brut = m.group(0)
        if re.search(r"[OolI]", brut[2:]):
            n += iban_ok("FR" + normalise(brut[2:]) if False else
                         "FR" + "".join("0" if c in "Oo" else "1" if c in "lI" else c
                                         for c in brut[2:] if c != " "))
    return n


def main():
    for chemin in sys.argv[1:]:
        with open(chemin, encoding="utf-8") as f:
            docs = [json.loads(l) for l in f if l.strip()]
        avec = sum(1 for d in docs if detecte(d["text"]) > 0)
        print(f"{chemin} : {avec} / {len(docs)} documents avec une détection simulée")
        if docs and "presentation" in docs[0]:
            for pr in ("libelle", "sans_libelle", "temoin"):
                ds = [d for d in docs if d["presentation"] == pr]
                a = sum(1 for d in ds if detecte(d["text"]) > 0)
                print(f"   {pr:13} {a} / {len(ds)}")


if __name__ == "__main__":
    main()
