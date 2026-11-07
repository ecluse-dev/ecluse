#!/usr/bin/env python3
"""Variantes de casse d'un corpus JSONL (P2-117, P2-121, P2-138).

Ecrit, a cote du corpus, `<nom>_minuscules.jsonl`, `<nom>_majuscules.jsonl`
et `<nom>_phrase.jsonl` : meme texte en minuscules, en capitales, ou en
minuscules avec une majuscule en debut de phrase et de ligne seulement
(« casse de phrase » : « Rdv avec m. julien chevrier »), annotations
inchangees. Et `<nom>_mixte.jsonl` (P2-145) : chaque document recoit l'une
des quatre casses (ordinaire, minuscules, phrase, capitales), en tournant
d'un document a l'autre d'un meme dossier ; une meme personne y est donc
citee en casses differentes, ce que les variantes uniformes ne testent pas. Refuse un document dont la longueur changerait (les offsets ne
vaudraient plus).

Usage :
    python3 variantes_casse.py flou/corpus_flou_realiste.jsonl [...]
"""

import json
import re
import sys


def casse_de_phrase(texte):
    """Minuscules, puis majuscule a la premiere lettre du texte, de chaque
    ligne et de chaque phrase (apres . ! ? suivis d'un blanc)."""
    bas = texte.lower()
    haut = re.sub(r"(^|[.!?]\s+|\n\s*)([a-zà-ÿ])",
                  lambda m: m.group(1) + m.group(2).upper(), bas)
    # Apres une abreviation (« m. », « dr. »), la majuscule serait celle d'un
    # nom propre : on la retire, sinon la variante ne serait pas en casse de
    # phrase.
    return re.sub(r"(\b(?:m|mme|mlle|dr|pr|me|[a-z])\.\s+)([A-ZÀ-Ý])",
                  lambda m: m.group(1) + m.group(2).lower(), haut,
                  flags=re.IGNORECASE)


CASSES = (lambda t: t, str.lower, casse_de_phrase, str.upper)


def variantes(chemin):
    docs = [json.loads(l) for l in open(chemin, encoding="utf-8") if l.strip()]
    base = chemin[:-len(".jsonl")] if chemin.endswith(".jsonl") else chemin
    def mixte(d):
        # Rotation deterministe : rang dans le dossier (corpus de dossiers),
        # sinon identifiant du document.
        cle = d.get("dossier", 0) + d.get("rang", d["id"])
        return CASSES[cle % len(CASSES)](d["text"])

    for nom, f in (("minuscules", lambda d: d["text"].lower()),
                   ("majuscules", lambda d: d["text"].upper()),
                   ("phrase", lambda d: casse_de_phrase(d["text"])),
                   ("mixte", mixte)):
        sortie = f"{base}_{nom}.jsonl"
        with open(sortie, "w", encoding="utf-8") as out:
            for d in docs:
                t = f(d)
                if len(t) != len(d["text"]):
                    raise SystemExit(f"refus : document {d['id']} change de "
                                     f"longueur en {nom}")
                out.write(json.dumps({**d, "text": t}, ensure_ascii=False)
                          + "\n")
        print(f"{sortie} : {len(docs)} documents")


if __name__ == "__main__":
    for c in sys.argv[1:]:
        variantes(c)
