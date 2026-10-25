#!/usr/bin/env python3
"""Générateur de corpus synthétique français annoté en PII.

Produit un fichier JSONL où chaque ligne est un document :
    {"id": 0, "text": "...", "entities": [{"type": "nir", "start": 12, "end": 33}]}

Entités cibles : nir, rpps, iban, finess (français).
Le corpus contient aussi des pièges non annotés : NIR à clé invalide,
IBAN à clé invalide, RPPS à Luhn cassé, téléphones, SIRET, SIREN (même
Luhn que le FINESS -- collision assumée, voir trap_siren), dates, codes
postaux. Un bon détecteur doit les ignorer (sauf FINESS/SIREN, capté à
confiance basse par construction -- voir docs/Ecluse-FINESS-detecteur-spec.md).

Profils :
  - v3 (défaut) : corpus de référence du benchmark, inchangé.
  - extended : v3 + gabarits supplémentaires (SIREN sans le mot « SIREN »,
    phrases mêlant FINESS et SIREN, ADELI avec/sans mot-clé, ADELI à clé
    invalide). Sert à mesurer la collision FINESS/SIREN sans la circularité
    du gabarit unique de v3 (voir agent/specs/P1-03-finess.md). Les ADELI
    sont annotés avec le type `adeli`, que le moteur actuel ne produit pas.

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



# Séparateurs à espacement irrégulier (RIB en tableau, NIR recopié à la
# main, export PDF) : espaces multiples, tabulation, espace insécable.
# Couvre ce que `DigitCompaction` (packages/ecluse_core) neutralise avant
# détection — un séparateur simple (" ", ".", "-") était déjà couvert par
# les styles "spaced"/"dotted" ci-dessous, sans avoir besoin de ce style.
IRREGULAR_SEPARATORS = ["  ", "   ", '\t', '\xa0', '\xa0\xa0', ' \xa0']


def fmt_nir(nir: str, rng: random.Random) -> str:
    style = rng.choice(["compact", "spaced", "dotted", "irregular"])
    if style == "compact":
        return nir
    parts = [nir[0], nir[1:3], nir[3:5], nir[5:7], nir[7:10], nir[10:13], nir[13:15]]
    if style == "irregular":
        return rng.choice(IRREGULAR_SEPARATORS).join(parts)
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
    style = rng.choice(["compact", "spaced", "irregular"])
    if style == "compact":
        return iban
    groups = [iban[i:i + 4] for i in range(0, len(iban), 4)]
    if style == "irregular":
        return rng.choice(IRREGULAR_SEPARATORS).join(groups)
    return " ".join(groups)


# FINESS : 9 chiffres, 2 premiers = département de rattachement (signal
# doux côté détecteur, non vérifié structurellement), 9e = clé Luhn — même
# algorithme que le RPPS, réutilisé ici via `luhn_digit`. Partage sa clé
# avec le SIREN (voir `trap_siren` ci-dessous) : collision assumée et
# documentée, pas résolue par la structure.
FINESS_DEPTS = [f"{d:02d}" for d in range(1, 96)] + ["97", "98"]


def make_finess(rng: random.Random) -> str:
    dept = rng.choice(FINESS_DEPTS)
    rest = "".join(rng.choice("0123456789") for _ in range(6))
    return luhn_digit(dept + rest)


def fmt_finess(finess: str, rng: random.Random) -> str:
    if rng.random() < 0.6:
        return finess
    return f"{finess[:2]} {finess[2:5]} {finess[5:8]} {finess[8]}"


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


def trap_siren(rng: random.Random) -> str:
    # SIREN : 9 chiffres, même Luhn mod 10 que le FINESS -- collision
    # structurelle assumée (voir docs/Ecluse-FINESS-detecteur-spec.md, §2).
    # Jamais annoté : un FinessDetector honnête le capte à confiance basse,
    # ce qui apparaît comme un faux positif "finess" dans score.py -- la
    # mesure de la collision, pas un bug à corriger.
    return luhn_digit("".join(rng.choice("0123456789") for _ in range(8)))


def make_siren(rng: random.Random) -> str:
    return trap_siren(rng)


def fmt_siren(siren: str, rng: random.Random) -> str:
    if rng.random() < 0.5:
        return siren
    return f"{siren[:3]} {siren[3:6]} {siren[6:]}"


def tva_from_siren(siren: str) -> str:
    # Clé TVA intracommunautaire FR : (12 + 3 * (SIREN mod 97)) mod 97.
    key = (12 + 3 * (int(siren) % 97)) % 97
    return f"FR{key:02d}{siren}"


def make_adeli(rng: random.Random) -> str:
    # 9 chiffres : département (2) + code profession (2, tiré au hasard : la
    # liste officielle n'est pas connue, voir agent/specs/P1-06-adeli.md) +
    # numéro (4) + clé Luhn (1). Pas de forme corse : règle de la lettre
    # non établie.
    dept = rng.choice(FINESS_DEPTS)
    prof = f"{rng.randrange(10, 100):02d}"
    num = "".join(rng.choice("0123456789") for _ in range(4))
    return luhn_digit(dept + prof + num)


def make_adeli_bad_key(rng: random.Random) -> str:
    valid = make_adeli(rng)
    wrong = (int(valid[-1]) + rng.randrange(1, 10)) % 10
    return valid[:-1] + str(wrong)


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
# slots : nir, rpps, iban, finess, name, trap
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
    # FINESS annoté avec indice de contexte (mot "FINESS" à proximité) :
    # le détecteur doit le capter à confiance haute.
    ["Établissement CH de Metz, FINESS ", ("finess_ctx",), "."],
    ["FINESS ET : ", ("finess_ctx",), "."],
    # FINESS annoté sans indice de contexte : capté à confiance basse
    # (indistinguable d'un SIREN par la structure seule) -- toujours annoté
    # en or, puisque c'est bien un FINESS, mais démontre le cas sans indice.
    ["La structure porte le code ", ("finess_nctx",), " dans le tableur RH."],
    # Phrases pièges (aucune entité annotée)
    ["Contactez le secrétariat au ", ("trap_phone",), " pour toute question."],
    ["Le SIRET de l'établissement est ", ("trap_siret",), "."],
    # Piège SIREN : même Luhn que le FINESS, jamais annoté -- un
    # FinessDetector honnête le capte à confiance basse (voir trap_siren).
    ["Le SIREN de la société est ", ("trap_siren",), "."],
    ["Attention, saisie erronée hier : ", ("trap_nir",), " a été rejeté par le contrôle."],
    ["L'IBAN ", ("trap_iban",), " a été refusé par la banque (clé invalide)."],
    ["Le numéro ", ("trap_rpps",), " ne correspond à aucun praticien connu."],
    ["Réunion de service le mardi, ", ("trap_misc",), ", salle 203."],
    ["Voir ", ("trap_misc",), " et ", ("trap_misc",), " pour le détail."],
    ["Rappel : ", ("name",), " est attendu en consultation jeudi matin sans son dossier."],
]

# Gabarits du profil « extended » (jamais utilisés dans le profil v3).
EXTENDED_TEMPLATES = [
    # SIREN sans le mot « SIREN » : pièges non annotés.
    ["Société immatriculée au RCS de Metz sous le numéro ", ("siren_plain",), "."],
    ["N° de TVA intracommunautaire : ", ("tva",), "."],
    ["Extrait Kbis : immatriculation ", ("siren_plain",), ", gérant ", ("name",), "."],
    # FINESS et SIREN dans la même phrase.
    ["Établissement FINESS ", ("finess_ctx",), ", rattaché à la société SIREN ", ("siren_plain",), "."],
    ["La société ", ("siren_plain",), " exploite la structure FINESS ", ("finess_ctx",), "."],
    ["Structure ", ("finess_nctx",), ", gérée par la société SIREN ", ("siren_plain",), "."],
    # ADELI avec mot-clé (valide, puis à clé invalide) et sans mot-clé.
    ["L'infirmière ", ("name",), " exerce sous le numéro ADELI ", ("adeli",), "."],
    ["N° ADELI : ", ("adeli",), " (", ("name",), ")."],
    ["Numéro ADELI saisi par erreur : ", ("adeli_bad",), "."],
    ["Le kinésithérapeute est enregistré sous le numéro ", ("adeli_nctx",), " depuis 2015."],
]

TARGETS = {"nir", "rpps", "iban", "finess"}


def build_doc(doc_id: int, rng: random.Random, templates=None) -> dict:
    template = rng.choice(templates or TEMPLATES)
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
        elif slot == "finess_ctx" or slot == "finess_nctx":
            v = fmt_finess(make_finess(rng), rng)
            entities.append({"type": "finess", "start": len(text), "end": len(text) + len(v)})
            text += v
        elif slot == "siren_plain":
            text += fmt_siren(make_siren(rng), rng)
        elif slot == "tva":
            text += tva_from_siren(make_siren(rng))
        elif slot in ("adeli", "adeli_nctx", "adeli_bad"):
            v = make_adeli_bad_key(rng) if slot == "adeli_bad" else make_adeli(rng)
            entities.append({"type": "adeli", "start": len(text), "end": len(text) + len(v)})
            text += v
        elif slot == "trap_phone":
            text += trap_phone(rng)
        elif slot == "trap_siret":
            text += trap_siret(rng)
        elif slot == "trap_siren":
            text += trap_siren(rng)
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
    parser.add_argument("--profile", choices=["v3", "extended"], default="v3",
                        help="v3 : corpus de référence ; extended : v3 + gabarits FINESS/SIREN/ADELI")
    args = parser.parse_args()
    templates = TEMPLATES + EXTENDED_TEMPLATES if args.profile == "extended" else TEMPLATES

    rng = random.Random(args.seed)
    counts = {"nir": 0, "rpps": 0, "iban": 0, "finess": 0, "adeli": 0}
    with open(args.out, "w", encoding="utf-8") as f:
        for i in range(args.n):
            doc = build_doc(i, rng, templates)
            for e in doc["entities"]:
                counts[e["type"]] += 1
            f.write(json.dumps(doc, ensure_ascii=False) + "\n")

    total = sum(counts.values())
    print(f"{args.n} documents écrits dans {args.out}")
    print(f"Entités annotées : {total} ({counts})")


if __name__ == "__main__":
    main()
