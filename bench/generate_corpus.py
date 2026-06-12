#!/usr/bin/env python3
"""Générateur de corpus synthétique français annoté en PII.

Produit un fichier JSONL où chaque ligne est un document :
    {"id": 0, "text": "...", "entities": [{"type": "nir", "start": 12, "end": 33}]}

Entités cibles : nir, rpps, iban (français).
Le corpus contient aussi des pièges non annotés : NIR à clé invalide,
IBAN à clé invalide, RPPS à Luhn cassé, téléphones, SIRET, dates, codes
postaux. Un bon détecteur doit les ignorer.

Déterministe : même seed => même corpus. Aucune donnée réelle.
"""

import argparse
import json
import random

# ---------------------------------------------------------------------------
# Génération d'entités valides
# ---------------------------------------------------------------------------

DEPARTEMENTS = [f"{d:02d}" for d in range(1, 96)] + ["2A", "2B"]


def nir_key(body13: str) -> int:
    body = body13.replace("2A", "19", 1).replace("2B", "18", 1)
    return 97 - (int(body) % 97)


def make_nir(rng: random.Random) -> str:
    sex = rng.choice("12")
    yy = f"{rng.randrange(100):02d}"
    mm = f"{rng.randrange(1, 13):02d}"
    dept = rng.choice(DEPARTEMENTS)
    commune = f"{rng.randrange(1, 990):03d}"
    order = f"{rng.randrange(1, 1000):03d}"
    body = f"{sex}{yy}{mm}{dept}{commune}{order}"
    return f"{body}{nir_key(body):02d}"


def fmt_nir(nir: str, rng: random.Random) -> str:
    style = rng.choice(["compact", "spaced", "dotted"])
    if style == "compact":
        return nir
    parts = [nir[0], nir[1:3], nir[3:5], nir[5:7], nir[7:10], nir[10:13], nir[13:15]]
    return (" " if style == "spaced" else ".").join(parts)


def luhn_digit(base: str) -> str:
    for k in range(10):
        s, dbl = 0, False
        for ch in reversed(base + str(k)):
            v = int(ch)
            if dbl:
                v *= 2
                if v > 9:
                    v -= 9
            s += v
            dbl = not dbl
        if s % 10 == 0:
            return base + str(k)
    raise AssertionError


def make_rpps(rng: random.Random) -> str:
    return luhn_digit("1" + "".join(rng.choice("0123456789") for _ in range(9)))


def fmt_rpps(rpps: str, rng: random.Random) -> str:
    if rng.random() < 0.6:
        return rpps
    return f"{rpps[:5]} {rpps[5:10]} {rpps[10]}"


def iban_check(bban: str) -> int:
    s = bban + "FR00"
    num = "".join(str(ord(c) - 55) if c.isalpha() else c for c in s)
    return 98 - (int(num) % 97)


def make_iban(rng: random.Random) -> str:
    bank = f"{rng.randrange(100000):05d}"
    branch = f"{rng.randrange(100000):05d}"
    account = "".join(rng.choice("0123456789") for _ in range(11))
    if rng.random() < 0.2:  # parfois une lettre dans le compte
        pos = rng.randrange(11)
        account = account[:pos] + rng.choice("ABCDEFGHJKLMNPQRSTUVWXYZ") + account[pos + 1:]
    rib = f"{rng.randrange(100):02d}"
    bban = bank + branch + account + rib
    return f"FR{iban_check(bban):02d}{bban}"


def fmt_iban(iban: str, rng: random.Random) -> str:
    if rng.random() < 0.5:
        return iban
    return " ".join(iban[i:i + 4] for i in range(0, len(iban), 4))


# ---------------------------------------------------------------------------
# Pièges (jamais annotés : un détecteur correct doit les ignorer)
# ---------------------------------------------------------------------------

def trap_nir_bad_key(rng: random.Random) -> str:
    nir = make_nir(rng)
    bad = (int(nir[13:15]) % 97) + 1
    return fmt_nir(f"{nir[:13]}{bad:02d}", rng)


def trap_iban_bad_key(rng: random.Random) -> str:
    iban = make_iban(rng)
    bad = (int(iban[2:4]) % 97) + 2
    return fmt_iban(f"FR{bad:02d}{iban[4:]}", rng)


def trap_rpps_bad_luhn(rng: random.Random) -> str:
    r = make_rpps(rng)
    return r[:-1] + str((int(r[-1]) + 1) % 10)


def trap_phone(rng: random.Random) -> str:
    digits = [rng.choice("0123456789") for _ in range(8)]
    pairs = ["0" + rng.choice("1234567")] + ["".join(digits[i:i + 2]) for i in range(0, 8, 2)]
    return " ".join(pairs)


def trap_siret(rng: random.Random) -> str:
    return luhn_digit("".join(rng.choice("0123456789") for _ in range(13)))


def trap_misc(rng: random.Random) -> str:
    return rng.choice([
        f"dossier n° {rng.randrange(10**8):08d}",
        f"le {rng.randrange(1, 29):02d}/{rng.randrange(1, 13):02d}/{rng.randrange(1990, 2026)}",
        f"{rng.randrange(1, 96):02d}{rng.randrange(1000):03d} {rng.choice(['Paris', 'Lyon', 'Metz', 'Thionville', 'Nancy'])}",
        f"réf. {rng.randrange(10**10):010d}",
    ])


# ---------------------------------------------------------------------------
# Gabarits de phrases (le placement des entités est suivi au caractère près)
# ---------------------------------------------------------------------------

PRENOMS = ["Camille", "Jean", "Fatou", "Lucas", "Inès", "Mohamed", "Léa", "Hugo",
           "Nadia", "Paul", "Sofia", "Karim", "Margaux", "Yanis", "Chloé"]
NOMS = ["Durand", "Nguyen", "Martin", "Benali", "Lefèvre", "Garcia", "Moreau",
        "Diallo", "Roux", "Schmitt", "Fontaine", "Petit", "Weber", "Marchal"]

# Chaque gabarit : liste de segments. str = texte fixe ; tuple = (slot,)
# slots : nir, rpps, iban, name, trap
TEMPLATES = [
    ["Le patient ", ("name",), " (NIR ", ("nir",), ") a été admis en cardiologie."],
    ["Admission de ", ("name",), ", numéro de sécurité sociale ", ("nir",), ", ce jour à 14h30."],
    ["Le NIR ", ("nir",), " figure au dossier transmis à la CPAM."],
    ["Compte-rendu validé par le Dr ", ("name",), ", RPPS ", ("rpps",), "."],
    ["Ordonnance émise par le praticien ", ("rpps",), " pour ", ("name",), "."],
    ["Le Dr ", ("name",), " (RPPS ", ("rpps",), ") prend ses fonctions au CH de Thionville."],
    ["Virement du salaire de ", ("name",), " sur le compte ", ("iban",), "."],
    ["Merci de régler la facture sur l'IBAN ", ("iban",), " avant le 30."],
    ["RIB du fournisseur : ", ("iban",), " (BIC AGRIFRPP)."],
    ["Le remboursement de ", ("name",), " (NIR ", ("nir",), ") sera versé sur ", ("iban",), "."],
    ["Transfert du dossier ", ("nir",), " au Dr ", ("name",), ", RPPS ", ("rpps",), "."],
    ["Paie de ", ("name",), " : NIR ", ("nir",), ", IBAN ", ("iban",), ", service RH informé."],
    # Phrases pièges (aucune entité annotée)
    ["Contactez le secrétariat au ", ("trap_phone",), " pour toute question."],
    ["Le SIRET de l'établissement est ", ("trap_siret",), "."],
    ["Attention, saisie erronée hier : ", ("trap_nir",), " a été rejeté par le contrôle."],
    ["L'IBAN ", ("trap_iban",), " a été refusé par la banque (clé invalide)."],
    ["Le numéro ", ("trap_rpps",), " ne correspond à aucun praticien connu."],
    ["Réunion de service le mardi, ", ("trap_misc",), ", salle 203."],
    ["Voir ", ("trap_misc",), " et ", ("trap_misc",), " pour le détail."],
    ["Rappel : ", ("name",), " est attendu en consultation jeudi matin sans son dossier."],
]

TARGETS = {"nir", "rpps", "iban"}


def build_doc(doc_id: int, rng: random.Random) -> dict:
    template = rng.choice(TEMPLATES)
    text = ""
    entities = []
    for seg in template:
        if isinstance(seg, str):
            text += seg
            continue
        slot = seg[0]
        if slot == "name":
            text += f"{rng.choice(PRENOMS)} {rng.choice(NOMS)}"
        elif slot == "nir":
            v = fmt_nir(make_nir(rng), rng)
            entities.append({"type": "nir", "start": len(text), "end": len(text) + len(v)})
            text += v
        elif slot == "rpps":
            v = fmt_rpps(make_rpps(rng), rng)
            entities.append({"type": "rpps", "start": len(text), "end": len(text) + len(v)})
            text += v
        elif slot == "iban":
            v = fmt_iban(make_iban(rng), rng)
            entities.append({"type": "iban", "start": len(text), "end": len(text) + len(v)})
            text += v
        elif slot == "trap_phone":
            text += trap_phone(rng)
        elif slot == "trap_siret":
            text += trap_siret(rng)
        elif slot == "trap_nir":
            text += trap_nir_bad_key(rng)
        elif slot == "trap_iban":
            text += trap_iban_bad_key(rng)
        elif slot == "trap_rpps":
            text += trap_rpps_bad_luhn(rng)
        elif slot == "trap_misc":
            text += trap_misc(rng)
    return {"id": doc_id, "text": text, "entities": entities}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n", type=int, default=1000, help="nombre de documents")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", default="corpus.jsonl")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    counts = {"nir": 0, "rpps": 0, "iban": 0}
    with open(args.out, "w", encoding="utf-8") as f:
        for i in range(args.n):
            doc = build_doc(i, rng)
            for e in doc["entities"]:
                counts[e["type"]] += 1
            f.write(json.dumps(doc, ensure_ascii=False) + "\n")

    total = sum(counts.values())
    print(f"{args.n} documents écrits dans {args.out}")
    print(f"Entités annotées : {total} ({counts})")


if __name__ == "__main__":
    main()
