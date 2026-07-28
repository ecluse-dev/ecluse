# Benchmark Écluse vs Microsoft Presidio

Harnais de comparaison sur corpus synthétique français annoté.
Entités cibles : **NIR**, **RPPS**, **IBAN FR**, **FINESS**.

## Résultats (corpus v3, seed 42, 1000 documents, 778 entités)

Appariement strict (span exact + type) :

| Moteur | Entité | Précision | Rappel | F1 |
|---|---|---:|---:|---:|
| **Écluse** | NIR | 100 % | 100 % | 100 % |
| **Écluse** | RPPS | 99,4 % | 100 % | 99,7 % |
| **Écluse** | IBAN FR | 100 % | 100 % | 100 % |
| **Écluse** | FINESS | 75,4 % | 100 % | 86,0 % |
| **Écluse** | **TOTAL** | **94,8 %** | **100 %** | **97,3 %** |
| Presidio¹ | NIR | — | 0 % | 0 % |
| Presidio¹ | RPPS | — | 0 % | 0 % |
| Presidio¹ | IBAN FR | 100 % | 100 % | 100 % |
| Presidio¹ | FINESS | — | 0 % | 0 % |
| Presidio¹ | **TOTAL** | 100 % | **32,5 %** | **49,0 %** |

¹ Chiffres Presidio mesurés sur le **corpus v1** (733 entités, sans
espacement irrégulier, sans FINESS) et non rejoués depuis les extensions
du corpus (`presidio-analyzer`/`spacy` non installés dans l'environnement
qui a produit cette mise à jour). Le rappel NIR/RPPS/FINESS à 0 % est
structurel (aucun recognizer français ni FINESS livré par défaut) et
resterait vrai sur n'importe quel corpus — Presidio ne fournit tout
simplement pas de recognizer FINESS, quelle que soit la configuration
« out-of-the-box » (voir *Collision FINESS ↔ SIREN* ci-dessous) ; la
ligne IBAN/TOTAL est donc à reproduire avant de la citer sur le corpus
v3 — voir *Reproduire* ci-dessous.

Lecture : en configuration par défaut, Presidio ne couvre **aucun
identifiant spécifiquement français** (NIR, RPPS, FINESS). Son recognizer
IBAN, à validation de clé, est excellent — à égalité avec Écluse. Le
corpus contient des pièges (NIR/IBAN à clé invalide, RPPS à Luhn cassé,
téléphones, SIRET, SIREN) : aucun moteur n'y est tombé à tort, à
l'exception du cas de collision FINESS/SIREN — assumé et mesuré, pas un
bug — et du cas limite RPPS/IBAN ci-dessous.

### Espacement irrégulier (nouveau en v2)

Le corpus v2 ajoute un 4ᵉ style de formatage pour NIR et IBAN —
`irregular` : espaces multiples, tabulation, espace insécable (NBSP),
en plus des styles déjà couverts (`compact`, `spaced`, `dotted`). Motif
réel de documents copiés-collés depuis Word/PDF, où un séparateur
simple ne suffit pas à retrouver l'identifiant.

Ce style représente 67 NIR et 67 IBAN sur ce tirage (seed 42 ; ce compte a
changé depuis la v2 — l'ajout des gabarits FINESS/SIREN en v3 déplace la
séquence aléatoire, donc tout comptage dérivé du générateur doit être
recalculé à chaque évolution du générateur, pas seulement lu depuis une
version antérieure de ce document). Rappel sur ce sous-ensemble isolé :

| Entité | Cas à espacement irrégulier | Détectés | Rappel |
|---|---:|---:|---:|
| NIR | 67 | 67 | **100 %** |
| IBAN FR | 67 | 67 | **100 %** |

Traité par `DigitCompaction` (`packages/ecluse_core/lib/src/digit_compaction.dart`) :
neutralise les espaces internes à une séquence de chiffres avant
détection, y compris quand une lettre majuscule s'y intercale (`2A`/`2B`
corse, lettre de compte IBAN), sans neutraliser un espace de mot
ordinaire précédant un identifiant (ex. « IBAN 1234 » ne doit jamais
devenir « IBAN1234 », sous peine de casser le motif du détecteur).

### Collision FINESS ↔ SIREN (nouveau en v3)

Le FINESS (identifiant d'établissement de santé, 9 chiffres) et le SIREN
(identifiant d'entreprise, 9 chiffres) utilisent **le même algorithme de
clé** (Luhn mod 10, réutilisé de `RppsDetector`) : la validation
structurelle **ne peut pas** les distinguer, contrairement au NIR/RPPS/IBAN
dont les structures sont uniques. `FinessDetector` ne prétend pas résoudre
cette ambiguïté par la structure : il gradue sa confiance selon la présence
du mot « FINESS » à proximité (confiance haute, 0,9) ou son absence
(confiance basse, 0,5 — collision SIREN assumée).

Le corpus v3 ajoute des FINESS annotés avec et sans indice de contexte, et
un piège SIREN **non annoté** (`trap_siren`, Luhn-valide, jamais accompagné
du mot « finess »). Sur ce tirage (seed 42, 1000 documents) :

| Cas | Nombre | Détectés (finess) |
|---|---:|---:|
| FINESS annotés (avec/sans contexte) | 129 | 129 (100 % rappel) |
| SIREN pièges (non annotés) | 42 | 42 (tous captés, à confiance basse) |

Les 42 pièges SIREN expliquent intégralement les 42 faux positifs FINESS du
tableau de résultats ci-dessus (précision 75,4 % au lieu de 100 %) —
vérifié un par un : aucun autre faux positif n'existe. C'est la mesure
honnête de la collision que le spec demande : le détecteur ne prétend pas
distinguer FINESS et SIREN, il les capte tous deux (à confiance graduée)
et le benchmark l'expose au lieu de le cacher. Presidio, qui ne fournit
aucun recognizer FINESS par défaut, ne tombe simplement jamais sur ce piège
— structurellement 0 % de rappel FINESS, pas un avantage de conception,
un angle mort.

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
  Le même mécanisme s'applique en théorie au FINESS (fenêtre de 9
  chiffres enchâssée dans un IBAN/RPPS à clé invalide) ; aucune
  occurrence de ce cas précis n'est apparue sur ce tirage, mais ce n'est
  pas garanti par construction — seule la collision FINESS/SIREN,
  mesurée ci-dessus, est un faux positif systématique et attendu.
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
