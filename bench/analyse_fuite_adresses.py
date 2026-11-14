#!/usr/bin/env python3
"""Fuite des adresses par variante de corpus flou (P2-157, mesure).

Lit `bench/flou/corpus_flou_<v>.jsonl` et `bench/flou/etat_<v>.jsonl` (produits
par `bash bench/etat.sh`, chemin `Ecluse.redact`) et, pour chaque annotation
de type adresse, liste les caractères restés en clair, regroupés par forme.
Depuis la racine du dépôt : python3 bench/analyse_fuite_adresses.py
Mesure seulement : aucun détecteur n'est touché. Le compte brut inclut les
sauts de ligne ; le scoreur de référence reste `score_flou.py`.
"""
import collections
import json
import os
import re

b = 'bench/flou/'
for name in ['adversarial','adversarial_minuscules','adversarial_majuscules','adversarial_phrase','realiste','adversarial_l60','realiste_l60']:
    cp=b+f'corpus_flou_{name}.jsonl'; pp=b+f'etat_{name}.jsonl'
    if not (os.path.exists(cp) and os.path.exists(pp)): print(name,'absent'); continue
    c=[json.loads(l) for l in open(cp)]
    p={}
    for l in open(pp):
        j=json.loads(l); p[j['id']]=j['entities']
    n=tot=leak=0; cedex=0; autres=collections.Counter()
    for d in c:
        cov=set()
        for e in p.get(d['id'],[]): cov.update(range(e['start'],e['end']))
        for e in d['entities']:
            if e['type']!='adresse': continue
            n+=1; tot+=e['end']-e['start']
            s=d['text'][e['start']:e['end']]
            if re.search(r'cedex',s,re.I): cedex+=1
            miss=[i for i in range(e['start'],e['end']) if i not in cov]
            leak+=len(miss)
            if miss:
                t=''.join(d['text'][i] if i in miss else '·' for i in range(e['start'],e['end']))
                t=re.sub(r'·+','·',t).strip('·')
                autres[t]+=1
    print(name,n,'adresses',cedex,'avec cedex',tot,'car',leak,'fuite',round(100*leak/tot,2),'%',dict(autres.most_common(6)))
