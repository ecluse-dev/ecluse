#!/usr/bin/env python3
"""Sonde « QI par `Ecluse.redact` » (P2-175, premier volet).

La ligne QI du tableau de bord mesurait jusqu'ici `ecluse_reid` seul : ce
que l'extraction de quasi-identifiants sait lire dans un texte déjà en
clair, jamais ce que le produit (`Ecluse.redact`) laisse réellement partir
vers le LLM. Ce script mesure le second point : sur les corpus QI
(`generate_corpus_qi.py`), le patronyme de la personne reste-t-il lisible
dans le texte une fois les entités prédites par `Ecluse.redact` retirées ?

Un patronyme qui suit un métier **sans civilité** (ex. « Le kinésithérapeute
Marchand ») n'est pas masqué : `NameDetector` ne déclenche que sur une
civilité (M., Mme, Dr...) ou un titre professionnel d'un ensemble fermé, pas
sur un nom de métier quelconque. Ce n'est pas corrigé ici (hors périmètre de
ce volet, voir `agent/QUEUE.md` P2-175) : la sonde documente le chiffre.

Les patronymes cherchés sont ceux de `generate_corpus_flou.NOMS`, la seule
liste utilisée par le générateur QI (`bench/generate_corpus_qi.py`) — aucun
nom réel.

Usage :
    python3 score_qi_redact.py --corpus corpus_qi_realiste.jsonl \\
        --pred pred_redact_realiste.jsonl
"""

import argparse
import json
import re
import sys

sys.path.insert(0, __file__.rsplit('/', 1)[0] or '.')
from generate_corpus_flou import NOMS  # noqa: E402

_NOM_PATTERN = re.compile(
    r'\b(?:' + '|'.join(re.escape(n) for n in NOMS) + r')\b')


def charge(path):
    with open(path, encoding='utf-8') as f:
        return [json.loads(l) for l in f if l.strip()]


def masque(entities):
    """Intervalles [start, end) couverts par une entité prédite."""
    return [(e['start'], e['end']) for e in entities]


def couvert(pos_debut, pos_fin, intervalles):
    return any(d <= pos_debut and pos_fin <= f for d, f in intervalles)


def fuites(corpus, pred):
    """Pour chaque document, patronymes de NOMS présents dans le texte et
    non couverts par une entité prédite de type « nom »."""
    pred_par_id = {d['id']: d for d in pred}
    resultat = []
    for doc in corpus:
        texte = doc['text']
        p = pred_par_id.get(doc['id'])
        if p is None or p.get('refuse'):
            continue
        intervalles = masque(p['entities'])
        en_clair = []
        for m in _NOM_PATTERN.finditer(texte):
            if not couvert(m.start(), m.end(), intervalles):
                en_clair.append(m.group(0))
        if en_clair:
            resultat.append((doc['id'], en_clair))
    return resultat


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--corpus', required=True)
    ap.add_argument('--pred', required=True)
    a = ap.parse_args()

    corpus = charge(a.corpus)
    pred = charge(a.pred)
    docs_fuite = fuites(corpus, pred)

    print(f'QI par Ecluse.redact : {a.corpus}')
    print(f'  documents            : {len(corpus)}')
    print(f'  patronyme en clair   : {len(docs_fuite)} document(s)')
    for doc_id, noms in docs_fuite[:10]:
        print(f'    document {doc_id} : {", ".join(sorted(set(noms)))}')
    if len(docs_fuite) > 10:
        print(f'    ... et {len(docs_fuite) - 10} de plus')


if __name__ == '__main__':
    main()
