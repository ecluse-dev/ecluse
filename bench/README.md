# Benchmark Écluse vs Microsoft Presidio

Harnais de comparaison sur corpus synthétique français annoté.
Entités cibles : **NIR**, **RPPS**, **IBAN FR**, **FINESS**.

## Résultats (corpus v3, seed 42, 1000 documents, 778 entités)

Appariement strict (span exact + type) :

| Moteur | Entité | Précision | Rappel | F1 |
|---|---|---:|---:|---:|
| **Écluse** | NIR | 100 % | 100 % | 100 % |
| **Écluse** | RPPS | 100 % | 100 % | 100 % |
| **Écluse** | IBAN FR | 100 % | 100 % | 100 % |
| **Écluse** | FINESS | 75,4 % | 100 % | 86,0 % |
| **Écluse** | **TOTAL** | **94,9 %** | **100 %** | **97,4 %** |
| Presidio¹ | NIR | — | 0 % | 0 % |
| Presidio¹ | RPPS | — | 0 % | 0 % |
| Presidio¹ | IBAN FR | 100 % | 68,7 % | 81,4 % |
| Presidio¹ | FINESS | — | 0 % | 0 % |
| Presidio¹ | **TOTAL** | 100 % | **18,9 %** | **31,8 %** |

¹ Presidio rejoué sur le **corpus v3** (seed 42, 1000 documents,
778 entités), configuration par défaut (`presidio-analyzer` 2.2.364,
modèle spaCy `en_core_web_lg`, seuil 0,35). Le rappel NIR/RPPS/FINESS à
0 % est structurel (aucun recognizer français ni FINESS livré par
défaut). Le rappel IBAN de 68,7 % (147/214) vient du style
`irregular` : les 67 IBAN à espacement irrégulier (voir plus bas) ne
sont pas reconnus. Commande exacte de reproduction : voir *Reproduire*.

Lecture : en configuration par défaut, Presidio ne couvre **aucun
identifiant spécifiquement français** (NIR, RPPS, FINESS). Son recognizer
IBAN, à validation de clé, est précis (aucun faux positif) mais ne
retrouve pas les IBAN à espacement irrégulier (rappel 68,7 %). Le
corpus contient des pièges (NIR/IBAN à clé invalide, RPPS à Luhn cassé,
téléphones, SIRET, SIREN) : aucun moteur n'y est tombé à tort, à
l'exception du cas de collision FINESS/SIREN — assumé et mesuré, pas un
bug.

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

### Corpus étendu : FINESS / SIREN / ADELI (profil `extended`, P1-13)

Le gabarit SIREN du corpus v3 est unique et contient toujours le mot
« SIREN » : la mesure de la collision y est circulaire (voir
`agent/specs/P1-03-finess.md` §4). Le profil `extended` du générateur ajoute,
**sans modifier le profil `v3`** (sortie identique octet pour octet), des
SIREN sans le mot « SIREN » (RCS, Kbis, TVA intracommunautaire), des
phrases mêlant FINESS et SIREN, et des ADELI (type annoté `adeli`) avec
mot-clé, sans mot-clé et à clé invalide.

Mesure de l'état actuel d'Écluse (**avant toute correction**, seed 42,
1000 documents, 739 entités annotées), appariement strict :

| Entité | Précision | Rappel | TP | FP | FN |
|---|---:|---:|---:|---:|---:|
| NIR | 100 % | 100 % | 174 | 0 | 0 |
| RPPS | 95,1 % | 100 % | 117 | 6 | 0 |
| IBAN FR | 100 % | 100 % | 151 | 0 | 0 |
| FINESS | 37,7 % | 100 % | 172 | 284 | 0 |
| ADELI | 0 % | 0 % | 0 | 0 | 125 |

Ces chiffres **ne sont pas comparables** à ceux du corpus v3 ci-dessus
(autre mélange de gabarits). Lecture :

- **FINESS : 284 faux positifs** = 184 SIREN (tous les gabarits, avec ou
  sans le mot « SIREN », y compris à côté du mot « FINESS ») + 100 ADELI
  Luhn-valides lus comme FINESS (68 avec le mot « ADELI », 32 sans). La
  piste « rejeter si “siren”/“siret” dans le contexte » de la spec P1-03
  n'aurait traité qu'une partie des 184 : les SIREN du RCS, du Kbis et de
  la TVA n'ont pas ce mot.
- **ADELI : 0 détecté sous son type.** Les 100 ADELI à clé valide sont
  masqués, mais sous l'étiquette `finess`. Les **25 ADELI à clé invalide**
  (même avec le mot « ADELI ») ne sont **pas détectés du tout** : c'est le
  cas de fuite que la spec ADELI veut couvrir.
- **RPPS : 6 faux positifs**, tous sur le gabarit « N° de TVA
  intracommunautaire » (35 documents) : les 11 chiffres « clé TVA + SIREN »
  passent la clé de Luhn du RPPS par coïncidence. Défaut nouveau, révélé
  par ce profil.

Limites de cette mesure : mêmes que le corpus v3 (synthétique, généré par
nous, une graine) ; les codes profession des ADELI sont tirés au hasard (la
liste officielle n'est pas connue) ; pas d'ADELI corse (règle de la lettre
non établie).

Reproduire :

```bash
python3 bench/generate_corpus.py --n 1000 --seed 42 --profile extended --out bench/corpus_ext.jsonl
(cd packages/ecluse_bench && dart run bin/run_ecluse.dart \
  ../../bench/corpus_ext.jsonl ../../bench/predictions_ext.jsonl)
python3 bench/score.py --corpus bench/corpus_ext.jsonl \
  --pred "Ecluse=bench/predictions_ext.jsonl"
```

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
- **Cas RPPS enchâssé dans un IBAN.** Une fenêtre de 11 chiffres passant
  Luhn par hasard à l'intérieur d'un IBAN, valide ou non, est écartée par
  `RppsDetector` (forme d'IBAN) et par `resolveOverlaps` ; sur ce tirage
  le RPPS ne produit aucun faux positif (166 TP, 0 FP, 0 FN). Une version
  antérieure de ce document mentionnait 1 faux positif RPPS : il n'est
  plus reproduit par le code actuel. Le même mécanisme pourrait en théorie
  toucher le FINESS (fenêtre de 9 chiffres) ; aucune occurrence n'apparaît
  sur ce tirage, mais ce n'est pas garanti par construction. Seule la
  collision FINESS/SIREN, mesurée ci-dessus, est un faux positif
  systématique et attendu.
- Presidio est rejoué avec le modèle `en_core_web_lg` (voir la note ¹ du
  tableau). L'option `--blank` de `run_presidio.py` (pipeline spaCy vierge,
  recognizers à motifs uniquement) n'est qu'un repli quand le modèle ne
  peut pas être installé ; les chiffres publiés n'en viennent pas.
- Les modes de score : le **strict** est celui publié. Le **souple** compte
  un recouvrement d'un seul caractère comme un succès et ne doit pas être
  cité comme rappel ; la section **FUITE** de `score.py` donne la part des
  caractères annotés restés en clair.

## Reproduire

Toutes les commandes se lancent **depuis la racine du dépôt**.

```bash
# 1. Dépendances Python
pip install -r bench/requirements.txt   # épingle cymem/preshed/murmurhash
python3 -m spacy download en_core_web_lg   # config Presidio standard

# 2. Générer le corpus (déterministe)
python3 bench/generate_corpus.py --n 1000 --seed 42 --out bench/corpus.jsonl

# 3. Prédictions Écluse (runner Dart officiel : NIR, RPPS, IBAN, FINESS)
(cd packages/ecluse_bench && dart run bin/run_ecluse.dart \
  ../../bench/corpus.jsonl ../../bench/predictions_ecluse.jsonl)
#    Sans SDK Dart : python3 bench/ecluse_sim.py — port de contrôle
#    approximatif (voir son en-tête : il diverge du moteur Dart).

# 4. Prédictions Presidio (ajouter --blank si le modèle est indisponible)
(cd bench && python3 run_presidio.py --corpus corpus.jsonl)

# 5. Scores
(cd bench && python3 score.py --corpus corpus.jsonl \
    --pred "Ecluse=predictions_ecluse.jsonl" \
    --pred "Presidio=predictions_presidio.jsonl")

# 6. Tests du scoreur
(cd bench && python3 test_score.py)
```

Les fichiers générés (`corpus.jsonl`, `predictions_*.jsonl`) ne sont
pas versionnés : ils se régénèrent à l'identique.
