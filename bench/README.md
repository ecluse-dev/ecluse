# Benchmark Écluse vs Microsoft Presidio

Harnais de comparaison sur corpus synthétique français annoté.
Entités cibles : **NIR**, **RPPS**, **IBAN FR**.

## Résultats (corpus v1, seed 42, 1000 documents, 733 entités)

Appariement strict (span exact + type), seuil Presidio 0.35 :

| Moteur | Entité | Précision | Rappel | F1 |
|---|---|---:|---:|---:|
| **Écluse** | NIR | 100 % | 100 % | 100 % |
| **Écluse** | RPPS | 99,5 % | 100 % | 99,8 % |
| **Écluse** | IBAN FR | 100 % | 100 % | 100 % |
| **Écluse** | **TOTAL** | **99,9 %** | **100 %** | **99,9 %** |
| Presidio | NIR | — | 0 % | 0 % |
| Presidio | RPPS | — | 0 % | 0 % |
| Presidio | IBAN FR | 100 % | 100 % | 100 % |
| Presidio | **TOTAL** | 100 % | **32,5 %** | **49,0 %** |

Lecture : en configuration par défaut, Presidio ne couvre **aucun
identifiant spécifiquement français** (NIR, RPPS). Son recognizer IBAN,
à validation de clé, est excellent — à égalité avec Écluse. Le corpus
contient des pièges (NIR/IBAN à clé invalide, RPPS à Luhn cassé,
téléphones, SIRET) : aucun moteur n'y est tombé, sauf le cas limite
ci-dessous.

## Honnêteté méthodologique

- **Presidio est extensible.** Un développeur peut écrire des
  recognizers NIR/RPPS personnalisés. Ce benchmark mesure ce qui est
  livré clé en main, parce que c'est ce que 95 % des équipes déploient.
- **Le corpus est synthétique et généré par nous.** Générateur et seed
  publics : quiconque peut le reproduire, le critiquer ou l'étendre
  (`generate_corpus.py --seed 42 --n 1000`).
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
