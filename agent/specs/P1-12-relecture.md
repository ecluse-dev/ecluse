# P1-12 — Relecture préparatoire de l'article de benchmark

Préparation de la relecture de `bench/ARTICLE.md` par le mainteneur (tâche
P1-12, `humain`). Chaque affirmation chiffrée est rejouée quand c'est
possible. Rien n'est modifié dans l'article : c'est au mainteneur de le
corriger et de décider de sa publication. Vérifications faites le
5 novembre 2026 sur `main` (`291f476`).

## 1. Ce qui est rejoué et confirmé

| Affirmation | Rejouée avec | Résultat |
|---|---|---|
| [C1] 1 000 documents, 778 entités (269 NIR, 166 RPPS, 214 IBAN, 129 FINESS) | `generate_corpus.py --n 1000 --seed 42` | **identique** |
| [C6] 42 SIREN-pièges | commande [C6] de l'article | **identique** |
| [C5] 67 NIR et 67 IBAN à espacement irrégulier (effectif du sous-ensemble) | motif de la commande [C5] | **identique** (le fait qu'Écluse les détecte tous n'est pas rejoué, voir § 2) |
| [C3] Presidio : NIR, RPPS et FINESS à 0 % ; IBAN 100 % / 68,7 % / 81,4 % ; total 100 % / 18,9 % / 31,8 % ; 147 entités retenues, 0 faux positif | `run_presidio.py` puis `score.py`, `en_core_web_lg`, seuil 0,35 | **identique**, avec `presidio-analyzer` **2.2.366** (l'article cite 2.2.364) |

## 2. Ce qui n'a pas pu être rejoué : les chiffres d'Écluse

Les lignes Écluse du tableau ([C2] : 100 % sur NIR, RPPS et IBAN ; FINESS
75,4 % / 100 % ; total 94,9 % / 100 % / 97,4 %) et la détection des 67 NIR et
67 IBAN irréguliers demandent le SDK Dart, indisponible dans cette session.

Ils datent d'avant de nombreux changements de détecteurs : ADELI
contextuel, INS, IBAN SEPA (P2-62), normalisation durcie (P2-29 et
suivantes). Un faux positif ADELI ou INS sur le corpus, ou un FINESS de plus
ou de moins, changerait le tableau. **À rejouer avant toute publication** :
tâche de mesure P1-36 ajoutée à la file.

## 3. Corrections à envisager dans l'article

1. **Version de Presidio** : citer celle de la dernière exécution (2.2.366
   le 5 novembre 2026), ou les deux, puisque les résultats sont identiques.
2. **Paragraphe sur `bench/requirements.txt`** : il affirme que les
   épinglages de `cymem`, `preshed` et `murmurhash` sont nécessaires pour
   que spaCy charge un pipeline. **Constat inverse** dans un environnement
   Python 3.13.18 avec spaCy 3.8.18 : avec les versions épinglées, le
   chargement échoue (`OverflowError` dans `Tokenizer._flush_specials`) ;
   avec les dernières versions (`cymem` 2.0.16, `preshed` 3.0.15,
   `murmurhash` 1.0.16), il réussit. L'épinglage dépend donc de
   l'environnement. Ne pas publier la phrase telle quelle ; corriger
   `bench/requirements.txt` par une tâche séparée, après avoir noté la
   version de Python de l'environnement d'origine.
3. **Chiffres Écluse** : les remplacer par ceux de P1-36 s'ils ont changé,
   et dater la mesure dans l'article.
4. Le mot « Brouillon » du titre et l'encart de tête sont à retirer à la
   publication.

## 4. Ce qui tient bien, à garder

- Le cadrage honnête : Presidio « tel que livré », et le paragraphe sur
  Presidio étendu à la main (P1-35), qui désamorce l'objection attendue.
- La collision FINESS/SIREN exposée plutôt que cachée.
- Les limites de l'étude : corpus synthétique, une graine, un gabarit SIREN.

## 5. Environnement de la vérification

Python 3.13.18 dans un environnement virtuel isolé ; `presidio-analyzer`
2.2.366, spaCy 3.8.18, `en_core_web_lg` 3.8.0 ; corpus généré par le
`generate_corpus.py` de `main`. Fichiers générés non versionnés.
