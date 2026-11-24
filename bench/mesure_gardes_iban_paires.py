#!/usr/bin/env python3
"""Gardes possibles sur l'IBAN écrit en paires (P2-288, mesure, rien corrigé).

Évalue hors ligne, par la forme du texte, ce que coûterait chaque garde : faux
accords retirés sur le témoin élargi de P2-279, IBAN perdus à la sonde de P2-272.
Corpus synthétiques uniquement ; ne sort que des comptes.
"""
import json,re,glob,collections,sys
P=re.compile(r'(?<![A-Za-z0-9])[Ff][Rr][ \-./][0-9]{2}(?:[ \-./][0-9A-Za-z]{2}){11}[ \-./][0-9A-Za-z](?![0-9A-Za-z])')
LIB=re.compile(r'(?<![a-zà-ÿ])(?:iban|rib|compte|bancaire|banque|virement|coordonn[ée]es bancaires)(?![a-zà-ÿ])',re.I)
def feats(t,m):
    s=m.group(0)
    sep=s[2]
    corps=re.sub(r'[ \-./]','',s)[4:]
    lettres=bool(re.search(r'[A-Za-z]',corps))
    # 'FR' + cle chiffres ; separateur uniforme ?
    seps=set(re.findall(r'[ \-./]',s))
    avant=t[max(0,m.start()-60):m.start()]
    return dict(sep=sep, uniforme=len(seps)==1, lettres=lettres, libelle=bool(LIB.search(avant)))
GARDES={
 'A libellé bancaire (60 car. avant)': lambda f: f['libelle'],
 'B séparateur espace seul': lambda f: f['sep']==' ' and f['uniforme'],
 'C corps sans lettre': lambda f: not f['lettres'],
 'D libellé OU corps sans lettre': lambda f: f['libelle'] or not f['lettres'],
 'E libellé OU espace seul': lambda f: f['libelle'] or (f['sep']==' ' and f['uniforme']),
}
def scan(path,label_fn):
    res=[]
    for l in open(path,encoding='utf-8'):
        d=json.loads(l)
        for m in P.finditer(d['text']):
            res.append((d,feats(d['text'],m)))
    return res


if __name__ == "__main__":
    # Depuis la racine du dépôt (P2-288). Gardes évaluées par la forme du texte.
    ids = [264, 383, 593, 736, 852, 1195, 2465, 3240, 3592, 4156, 4301, 4469, 4902]
    fp = scan('bench/flou/corpus_faux_accords_ocr_dur.jsonl', None)
    so = [(d, f) for d, f in scan('bench/flou/corpus_sonde_gardes.jsonl', None)
          if d['famille'] == 'iban_cle_fausse' and d['ecriture'] == 'paires']
    print('témoin élargi : documents avec la forme paires =', len(fp))
    print('sonde, paires à clé fausse :', len(so))
    for nom, g in GARDES.items():
        retires = sum(1 for d, f in fp if d['id'] in ids and not g(f))
        perdus = sum(1 for d, f in so if not g(f))
        print(f'{nom} : faux accords retirés {retires}/13 ; sonde perdus {perdus}/{len(so)}')
