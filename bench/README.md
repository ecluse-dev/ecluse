# Benchmark Écluse vs Microsoft Presidio

Harnais de comparaison sur corpus synthétique français annoté.
Entités cibles : **NIR**, **RPPS**, **IBAN FR**.

## Résultats (corpus v2, seed 42, 1000 documents, 743 entités)

Appariement strict (span exact + type), seuil Presidio 0.35 :

| Moteur | Entité | Précision | Rappel | F1 |
|---|---|---:|---:|---:|
| **Écluse** | NIR | 100 % | 100 % | 100 % |
| **Écluse** | RPPS | 99,5 % | 100 % | 99,8 % |
| **Écluse** | IBAN FR | 100 % | 100 % | 100 % |
| **Écluse** | **TOTAL** | **99,9 %** | **100 %** | **99,9 %** |
| Presidio¹ | NIR | — | 0 % | 0 % |
| Presidio¹ | RPPS | — | 0 % | 0 % |
| Presidio¹ | IBAN FR | 100 % | 100 % | 100 % |
| Presidio¹ | **TOTAL** | 100 % | **32,5 %** | **49,0 %** |

¹ Chiffres Presidio mesurés sur le **corpus v1** (733 entités, sans
espacement irrégulier) et non rejoués depuis l'extension du corpus
(`presidio-analyzer`/`spacy` non installés dans l'environnement qui a
produit cette mise à jour). Le rappel NIR/RPPS à 0 % est structurel
(aucun recognizer français livré par défaut) et resterait vrai sur
n'importe quel corpus ; la ligne IBAN/TOTAL est donc à reproduire avant
de la citer sur le corpus v2 — voir *Reproduire* ci-dessous.

Lecture : en configuration par défaut, Presidio ne couvre **aucun
identifiant spécifiquement français** (NIR, RPPS). Son recognizer IBAN,
à validation de clé, est excellent — à égalité avec Écluse. Le corpus
contient des pièges (NIR/IBAN à clé invalide, RPPS à Luhn cassé,
téléphones, SIRET) : aucun moteur n'y est tombé, sauf le cas limite
ci-dessous.

### Espacement irrégulier (nouveau en v2)

Le corpus v2 ajoute un 4ᵉ style de formatage pour NIR et IBAN —
`irregular` : espaces multiples, tabulation, espace insécable (NBSP),
en plus des styles déjà couverts (`compact`, `spaced`, `dotted`). Motif
réel de documents copiés-collés depuis Word/PDF, où un séparateur
simple ne suffit pas à retrouver l'identifiant.

Ce style représente 47 NIR et 50 IBAN sur ce tirage (seed 42). Rappel
sur ce sous-ensemble isolé :

| Entité | Cas à espacement irrégulier | Détectés | Rappel |
|---|---:|---:|---:|
| NIR | 47 | 47 | **100 %** |
| IBAN FR | 50 | 50 | **100 %** |

Traité par `DigitCompaction` (`packages/ecluse_core/lib/src/digit_compaction.dart`) :
neutralise les espaces internes à une séquence de chiffres avant
détection, y compris quand une lettre majuscule s'y intercale (`2A`/`2B`
corse, lettre de compte IBAN), sans neutraliser un espace de mot
ordinaire précédant un identifiant (ex. « IBAN 1234 » ne doit jamais
devenir « IBAN1234 », sous peine de casser le motif du détecteur).

## Honnêteté méthodologique

- **Presidio est extensible.** Un développeur peut écrire des
  recognizers NIR/RPPS personnalisés. Ce benchmark mesure ce qui est
  livré clé en main, parce que c'est ce que 95 % des équipes déploient.
- **Le corpus est synthétique et généré par nous.** Générateur et seed
  publics : quiconque peut le reproduire, le critiquer ou l'étendre
  (`generate_corpus.py --seed 42 --n 1000`). Changer le générateur
  (comme l'ajout du style `irregular` en v2) change le corpus produit à
  seed égal : les résultats ci-dessus ne sont comparables qu'entre
  exécutions du même générateur.
- **Limite connue d'Écluse** : 1 faux positif RPPS subsiste — une
  fenêtre de 11 chiffres passant Luhn par hasard, enchâssée dans un
  IBAN *à clé invalide* (que l'IbanFrDetector rejette donc à raison).
  Les 7 cas équivalents enchâssés dans des IBAN valides sont éliminés
  par `resolveOverlaps` — règle ajoutée précisément grâce à ce harnais.
- Cette exécution utilise un pipeline spaCy vierge (recognizers à
  motifs uniquement, seuls pertinents ici). Pour reproduire avec la
  configuration standard complète : installer `en_core_web_lg` et
  omettre `--blank`.

## Reproduire

```bash
# 1. Dépendances Python
pip install -r requirements.txt
python -m spacy download en_core_web_lg   # config Presidio standard

# 2. Générer le corpus (déterministe)
python3 generate_corpus.py --n 1000 --seed 42 --out corpus.jsonl

# 3. Prédictions Écluse (runner Dart officiel, depuis la racine du repo)
dart run ecluse_bench:run_ecluse bench/corpus.jsonl bench/predictions_ecluse.jsonl
#    (ou, sans SDK Dart : python3 ecluse_sim.py — port de contrôle)

# 4. Prédictions Presidio
python3 run_presidio.py --corpus corpus.jsonl   # ajouter --blank si modèle indisponible

# 5. Scores
python3 score.py --corpus corpus.jsonl \
    --pred "Ecluse=predictions_ecluse.jsonl" \
    --pred "Presidio=predictions_presidio.jsonl"
```

Les fichiers générés (`corpus.jsonl`, `predictions_*.jsonl`) ne sont
pas versionnés : ils se régénèrent à l'identique.
