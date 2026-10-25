# Brouillon — Ce que Presidio ne voit pas : un benchmark d'identifiants français

> **Brouillon à relire (tâche P1-12, mainteneur).** Tous les chiffres
> viennent de `bench/README.md` et sont rejoués avec les commandes de la
> section « Reproduire ». Rien n'a été mesuré sur des données réelles.

## En une phrase

Sur un corpus synthétique de 1000 documents français, Écluse retrouve les
778 identifiants annotés (NIR, RPPS, IBAN FR, FINESS), au prix de 42 faux
positifs sur le FINESS ; Microsoft Presidio, en configuration par défaut,
n'en retrouve que 18,9 %.

## Ce qui est comparé

Quatre types d'identifiants français : NIR, RPPS, IBAN FR et FINESS. Le
corpus est **synthétique**, généré par un script public avec une graine fixe :
1000 documents, 778 entités annotées (269 NIR, 166 RPPS, 214 IBAN, 129
FINESS) [C1]. Les identifiants sont fabriqués avec des clés valides
calculées ; aucun n'est réel.

Presidio est mesuré **tel que livré** : `presidio-analyzer` 2.2.364, modèle
spaCy `en_core_web_lg`, seuil 0,35 [C3]. Un développeur peut écrire des
recognizers supplémentaires ; ce benchmark ne mesure pas ce qu'une équipe
motivée obtiendrait en les ajoutant.

L'appariement est strict : la position exacte et le type doivent
correspondre [C4].

## Résultats

| Moteur | Entité | Précision | Rappel | F1 |
|---|---|---:|---:|---:|
| Écluse | NIR | 100 % | 100 % | 100 % |
| Écluse | RPPS | 100 % | 100 % | 100 % |
| Écluse | IBAN FR | 100 % | 100 % | 100 % |
| Écluse | FINESS | 75,4 % | 100 % | 86,0 % |
| Écluse | **Total** | **94,9 %** | **100 %** | **97,4 %** |
| Presidio | NIR | — | 0 % | 0 % |
| Presidio | RPPS | — | 0 % | 0 % |
| Presidio | IBAN FR | 100 % | 68,7 % | 81,4 % |
| Presidio | FINESS | — | 0 % | 0 % |
| Presidio | **Total** | 100 % | **18,9 %** | **31,8 %** |

Sources : [C2] pour Écluse, [C3] pour Presidio, [C4] pour le tableau.

## Ce que disent ces chiffres

**Presidio ne couvre aucun identifiant spécifiquement français par
défaut.** Le rappel de 0 % sur NIR, RPPS et FINESS est structurel : aucun
recognizer correspondant n'est livré. Ce n'est pas un défaut de
Presidio, c'est son périmètre.

**Son recognizer IBAN est précis, mais fragile au formatage.** Aucun faux
positif, mais 67 IBAN sur 214 manquent : ce sont ceux écrits avec des
espaces multiples, des tabulations ou des espaces insécables, un cas
courant dans les documents copiés depuis un traitement de texte. Écluse
retrouve les 67 NIR et les 67 IBAN écrits de cette façon [C5].

**La validation structurelle fait l'essentiel du travail pour NIR, RPPS et
IBAN.** Ces trois identifiants ont une structure et une clé de contrôle
qui leur sont propres ; les pièges du corpus (clés invalides, numéros
voisins comme SIRET ou téléphones) n'ont produit aucun faux positif pour
Écluse sur ces trois types.

**Presidio étendu à la main égale Écluse sur le NIR et le RPPS.** Avec
deux reconnaisseurs écrits à la main, clé de contrôle vérifiée, Presidio
atteint 100 % de précision et de rappel sur ces deux identifiants (corpus
v3) ; sans vérification de clé, la précision tombe à 85,7 % (NIR) et 81,0 %
(RPPS). L'écart restant sur ce corpus vient de l'IBAN à espacement
irrégulier (rappel 68,7 %) et du FINESS. Voir `bench/README.md`, « Presidio
avec reconnaisseurs NIR et RPPS écrits à la main ».

## Une limite assumée : FINESS et SIREN

Le FINESS (établissement de santé) et le SIREN (entreprise) ont chacun 9
chiffres et la même clé de contrôle : la structure ne permet pas de les
distinguer. Écluse capte donc les deux, avec une confiance plus faible
quand le mot « FINESS » est absent à proximité.

Sur le corpus, 42 SIREN-pièges (non annotés) sont détectés comme FINESS
[C6] : ce sont **tous** les faux positifs FINESS, d'où une précision de
75,4 %. Le rappel reste de 100 %. Le détecteur ne prétend pas résoudre
l'ambiguïté ; le benchmark l'expose au lieu de la cacher. Le coût d'un tel
faux positif est un sur-masquage d'un identifiant d'organisation, pas une
fuite de donnée personnelle.

## Limites de l'étude

- **Corpus synthétique et généré par nous.** Les gabarits de phrases sont
  peu nombreux et les pièges y sont aussi de notre fabrication. Un score de
  100 % sur ce corpus ne dit rien de la précision sur des documents réels.
- **Un seul gabarit SIREN**, toujours accompagné du mot « SIREN ». Le
  résultat sur la collision FINESS/SIREN dépend de cette construction.
- **Une seule graine** (42), un seul tirage.
- **Presidio en configuration par défaut seulement.**
- **Comparaisons entre versions du générateur impossibles** : changer le
  générateur change le corpus à graine égale.
- Le README du benchmark mentionne un cas limite RPPS/IBAN (un faux positif
  RPPS) qui **n'a pas été retrouvé** dans la dernière exécution ; il n'est
  donc pas utilisé ici.
- Entités hors périmètre du benchmark (noms, adresses, téléphones, emails) :
  non mesurées.

## Reproduire

Depuis la racine du dépôt (Python 3 pour le corpus et Presidio, SDK Dart
pour Écluse) :

```bash
# [C1] Corpus déterministe : 1000 documents, 778 entités
python3 bench/generate_corpus.py --n 1000 --seed 42 --out bench/corpus.jsonl

# [C2] Prédictions Écluse
(cd packages/ecluse_bench && dart run bin/run_ecluse.dart \
  ../../bench/corpus.jsonl ../../bench/predictions_ecluse.jsonl)

# [C3] Prédictions Presidio (configuration par défaut)
pip install -r bench/requirements.txt
python3 -m spacy download en_core_web_lg
(cd bench && python3 run_presidio.py --corpus corpus.jsonl)

# [C4] Scores (appariement strict, puis souple)
(cd bench && python3 score.py --corpus corpus.jsonl \
  --pred "Ecluse=predictions_ecluse.jsonl" \
  --pred "Presidio=predictions_presidio.jsonl")

# [C5] Sous-ensemble à espacement irrégulier : 67 NIR et 67 IBAN, tous détectés
python3 - <<'PY'
import json, re
C = [json.loads(l) for l in open('bench/corpus.jsonl', encoding='utf-8')]
P = {d['id']: d for d in map(json.loads, open('bench/predictions_ecluse.jsonl', encoding='utf-8'))}
tot, ok = {'nir': 0, 'iban': 0}, {'nir': 0, 'iban': 0}
for d in C:
    pred = {(e['type'], e['start'], e['end']) for e in P[d['id']]['entities']}
    for g in d['entities']:
        if g['type'] in tot and re.search(r'  |\t| ', d['text'][g['start']:g['end']]):
            tot[g['type']] += 1
            ok[g['type']] += (g['type'], g['start'], g['end']) in pred
print(tot, ok)
PY

# [C6] SIREN-pièges du corpus : 42 documents
python3 -c "import json; print(sum(json.loads(l)['text'].startswith('Le SIREN de la société est') for l in open('bench/corpus.jsonl', encoding='utf-8')))"
```

Version de `bench/requirements.txt` : les dépendances transitives de spaCy
(`cymem`, `preshed`, `murmurhash`) y sont épinglées, faute de quoi spaCy ne
charge aucun pipeline dans l'environnement de test.

Les fichiers générés (`corpus.jsonl`, `predictions_*.jsonl`) ne sont pas
versionnés.
