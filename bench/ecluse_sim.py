#!/usr/bin/env python3
"""Port Python fidèle des détecteurs Écluse (ecluse_core).

Sert de runner de secours dans les environnements sans SDK Dart, et de
double implémentation de contrôle. La référence reste le code Dart du
monorepo (packages/ecluse_core) — exécuté via :

    dart run ecluse_bench:run_ecluse corpus.jsonl predictions_ecluse.jsonl

Toute divergence entre les deux implémentations est un bug à signaler.
"""

import argparse
import json
import re

# --- NIR -------------------------------------------------------------------

NIR_RE = re.compile(
    r'(?<![0-9])'
    r'[1-8][ .\-]?'
    r'[0-9]{2}[ .\-]?'
    r'[0-9]{2}[ .\-]?'
    r'(?:[0-9]{2}|2[ABab])[ .\-]?'
    r'[0-9]{3}[ .\-]?'
    r'[0-9]{3}[ .\-]?'
    r'[0-9]{2}'
    r'(?![0-9])'
)


def nir_valid(nir: str) -> bool:
    if len(nir) != 15:
        return False
    if not nir[3:5].isdigit() or not 1 <= int(nir[3:5]) <= 12:
        return False
    dept = nir[5:7]
    if dept not in ("2A", "2B"):
        if not dept.isdigit() or int(dept) < 1:
            return False
    if not nir[10:13].isdigit() or int(nir[10:13]) < 1:
        return False
    body = nir[:13]
    if body.find("2A", 5) == 5:
        body = body[:5] + "19" + body[7:]
    if body.find("2B", 5) == 5:
        body = body[:5] + "18" + body[7:]
    if not body.isdigit():
        return False
    return int(nir[13:15]) == 97 - (int(body) % 97)


# --- RPPS ------------------------------------------------------------------

RPPS_RE = re.compile(r'(?<![0-9])[0-9](?: ?[0-9]){10}(?![0-9])')


def luhn_valid(digits: str) -> bool:
    total, dbl = 0, False
    for ch in reversed(digits):
        v = int(ch)
        if dbl:
            v *= 2
            if v > 9:
                v -= 9
        total += v
        dbl = not dbl
    return total % 10 == 0


# --- IBAN FR ---------------------------------------------------------------

IBAN_RE = re.compile(
    r'(?<![A-Za-z0-9])[Ff][Rr][0-9]{2}(?:[ \-]?[0-9A-Za-z]){23}(?![0-9A-Za-z])'
)


def iban_valid(iban: str) -> bool:
    if len(iban) != 27:
        return False
    rearranged = iban[4:] + iban[:4]
    rem = 0
    for c in rearranged:
        if c.isdigit():
            rem = (rem * 10 + int(c)) % 97
        elif "A" <= c <= "Z":
            rem = (rem * 100 + ord(c) - 55) % 97
        else:
            return False
    return rem == 1


# --- Pipeline ----------------------------------------------------------------

def detect(text: str):
    out = []
    for m in NIR_RE.finditer(text):
        if nir_valid(re.sub(r"[ .\-]", "", m.group(0)).upper()):
            out.append({"type": "nir", "start": m.start(), "end": m.end()})
    for m in RPPS_RE.finditer(text):
        if luhn_valid(m.group(0).replace(" ", "")):
            out.append({"type": "rpps", "start": m.start(), "end": m.end()})
    for m in IBAN_RE.finditer(text):
        if iban_valid(re.sub(r"[ \-]", "", m.group(0)).upper()):
            out.append({"type": "iban", "start": m.start(), "end": m.end()})
    return out



def resolve_overlaps(entities):
    """Même règle que resolveOverlaps en Dart : longueur > confiance > position."""
    conf = {"nir": 1.0, "rpps": 0.9, "iban": 1.0}
    ordered = sorted(entities, key=lambda e: (-(e["end"] - e["start"]), -conf[e["type"]], e["start"]))
    kept = []
    for c in ordered:
        if not any(c["start"] < k["end"] and k["start"] < c["end"] for k in kept):
            kept.append(c)
    return sorted(kept, key=lambda e: e["start"])

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", default="corpus.jsonl")
    parser.add_argument("--out", default="predictions_ecluse.jsonl")
    args = parser.parse_args()

    n_docs = 0
    n_ents = 0
    with open(args.corpus, encoding="utf-8") as fin, \
            open(args.out, "w", encoding="utf-8") as fout:
        for line in fin:
            doc = json.loads(line)
            entities = resolve_overlaps(detect(doc["text"]))
            fout.write(json.dumps({"id": doc["id"], "entities": entities},
                                  ensure_ascii=False) + "\n")
            n_docs += 1
            n_ents += len(entities)

    print(f"Écluse (port Python) : {n_docs} documents, {n_ents} entités -> {args.out}")


if __name__ == "__main__":
    main()
