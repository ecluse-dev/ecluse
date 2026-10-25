# P2-02 — Référence des heuristiques de noms et d'adresses

Type : `mesure`. Rien n'a été corrigé : aucune ligne de détection, de
générateur ni de scoreur n'a été modifiée. Ce rapport donne les valeurs que le
NER devra battre (`agent/specs/P2-01.md` § 4, conditions A à D).

## Conditions de la mesure

- Commit de départ : `b4743ba` (`main`). Tests avant mesure : `ecluse_core`
  168 tests, `ecluse_redact` 284 tests, tous passés ; tests Python du
  benchmark (`unittest discover -s bench`) : 14 tests, OK.
- Outils : Dart 3.13.7 (stable, installé pour la session depuis
  `storage.googleapis.com`, comme `agent/setup-cloud-env.sh`), Python 3.13.17.
  La version de Dart de la CI n'est pas fixée (« stable ») : un écart avec
  cette session est possible, il n'a pas eu d'effet visible ici.
- Moteur : `Ecluse.redact` complet avec les détecteurs par défaut (`NameDetector`,
  `AdresseDetector` et les autres). Aucun NER.
- Corpus : générés par `bench/generate_corpus_flou.py --n 400` (graines 42 et 7)
  et `bench/generate_corpus.py --n 1000 --seed 42` ; fichiers générés hors du
  dépôt, non versionnés.

Commandes (depuis la racine du dépôt, `$OUT` = répertoire de sortie) :

```bash
python3 bench/generate_corpus_flou.py --n 400 --seed $SEED --out-dir $OUT
for c in realiste adversarial temoin; do
  (cd packages/ecluse_redact && dart run bin/run_redact_bench.dart \
     $OUT/corpus_flou_$c.jsonl $OUT/pred_$c.jsonl)
  (cd bench && python3 score_flou.py --corpus $OUT/corpus_flou_$c.jsonl \
     --pred "Ecluse=$OUT/pred_$c.jsonl")
done
python3 bench/generate_corpus.py --n 1000 --seed 42 --out $OUT/corpus.jsonl
(cd packages/ecluse_bench && dart run bin/run_ecluse.dart \
   $OUT/corpus.jsonl $OUT/pred.jsonl)
(cd bench && python3 score.py --corpus $OUT/corpus.jsonl \
   --pred "Ecluse=$OUT/pred.jsonl")
```

## Entités floues, graine 42 (corpus de décision)

Colonnes : annotés, détectés, rappel strict, F1 souple, fuite au caractère.

| Corpus | Type | Annotés | Détectés | Rappel strict | F1 souple | Fuite |
|---|---|---:|---:|---:|---:|---:|
| Réaliste | nom | 479 | 479 | 16,3 % | 100 % | 27,7 % |
| Réaliste | adresse | 159 | 159 | 100 % | 100 % | 0 % |
| Réaliste | **global** | 1677 | 1677 | 71,1 % | 100 % | **7,5 %** |
| Adversarial | nom | 594 | 504 | 53,4 % | 83,2 % | 27,2 % |
| Adversarial | adresse | 155 | 106 | 34,2 % | 81,2 % | 15,0 % |
| Adversarial | **global** | 1082 | 943 | 65,0 % | 88,5 % | **16,8 %** |
| Témoin | — | 0 | 0 | — | — | 0 détection |

Précision stricte adversarial : nom 62,9 %, adresse 50,0 %. Sur-masquage
(caractères masqués à tort) : réaliste 166 (0,16 % du texte), adversarial 80
(0,15 %), témoin 0. Les autres types (date de naissance, email, établissement,
téléphone) sont à 100 % de rappel souple et 0 % de fuite sur les deux corpus.

## Entités floues, graine 7 (corpus de calibration)

| Corpus | Type | Annotés | Détectés | Rappel strict | F1 souple | Fuite |
|---|---|---:|---:|---:|---:|---:|
| Réaliste | nom | 481 | 481 | 17,9 % | 100 % | 29,2 % |
| Réaliste | adresse | 162 | 162 | 100 % | 100 % | 0 % |
| Réaliste | **global** | 1680 | 1680 | 71,9 % | 100 % | **8,2 %** |
| Adversarial | nom | 590 | 514 | 51,4 % | 81,3 % | 28,7 % |
| Adversarial | adresse | 172 | 112 | 32,6 % | 78,9 % | 13,9 % |
| Adversarial | **global** | 1084 | 948 | 62,8 % | 86,9 % | **17,4 %** |
| Témoin | — | 0 | 0 | — | — | 0 détection |

Précision stricte adversarial : nom 58,9 %, adresse 50,0 %. Sur-masquage :
réaliste 154 (0,15 %), adversarial 140 (0,27 %), témoin 0.

**Écart entre graines** (42 → 7), pour juger le bruit de mesure : fuite
globale réaliste +0,7 point, adversarial +0,6 point ; fuite des noms adversarial
+1,5 point ; fuite des adresses adversarial −1,1 point. Seuil proposé de 5 points
dans P2-01 § 4.A : il est supérieur à ces écarts, mais deux graines ne donnent
pas une variance fiable.

## Restauration non identique

Documents dont la restauration n'est pas octet pour octet (alertes du runner) :

| Corpus | Graine 42 | Graine 7 |
|---|---:|---:|
| Réaliste | 0 | 0 |
| Adversarial | 59 | 54 |
| Témoin | 0 | 0 |

## Identifiants à clé, corpus v3 (graine 42, 1000 documents, 778 entités)

Appariement strict : NIR 100 % / 100 % (269 TP, 0 FP, 0 FN) ; RPPS 100 % / 100 %
(166 TP) ; IBAN FR 100 % / 100 % (214 TP) ; FINESS 75,4 % / 100 % (129 TP, 42 FP,
0 FN) ; total 94,9 % / 100 %, F1 97,4 %. L'appariement souple est identique.
Fuite au caractère : 0 % pour les quatre types. Les 42 faux positifs FINESS sont
les pièges SIREN que le README documente. ADELI n'a aucune entité dans ce
corpus (0 annotée) et `bench/score.py` ne note pas ce type : la condition B de
P2-01 ne couvre donc pas ADELI avec cet outil.

## Part de la fuite des noms due à la civilité

Le README affirme que la fuite des noms du corpus réaliste est « entièrement »
la civilité conservée volontairement. Vérifié par un script jetable (non
versionné) qui regarde, mot par mot, ce qui reste en clair dans les noms
annotés : **réaliste, 0 caractère en clair hors civilité** sur les deux
graines ; **adversarial, environ 70 % de la fuite des noms est hors civilité**
(1865 sur 2657 caractères non blancs en graine 42 ; 1901 sur 2799 en graine 7),
surtout des prénoms hors gazetteer (« Souleymane », « Krzysztof », « Yaroslav »,
« Mei-Ling ») et des patronymes (« Vasseur », « Verdier »). Ce décompte exclut
les espaces : ses pourcentages ne sont pas comparables à ceux du scoreur, seule
la part l'est. Conséquence pour P2-01 § 4.A : la comparaison « hors civilité »
n'a de sens que sur le corpus réaliste ; sur l'adversarial, la fuite des noms
est majoritairement un vrai défaut des heuristiques.

## Écarts avec les valeurs publiées

**Aucun.** Toutes les valeurs de la graine 42 (corpus flous : rappel strict, F1
souple, fuite, 59 restaurations, sur-masquage ; corpus v3 : précisions, rappels,
TP/FP/FN) sont identiques à `bench/README.md`. Les valeurs publiées sont donc
reproductibles à l'identique avec Dart 3.13.7.

## Constat hors périmètre (non corrigé)

`packages/ecluse_bench/pubspec_overrides.yaml` est **versionné** et contient un
chemin au format Windows (`path: ..\\ecluse_core`). Sous Linux,
`dart pub get` y échoue (« could not find package ecluse_core at
`..\\ecluse_core` ») et `dart run bin/run_ecluse.dart` ne compile pas, avec une
erreur de type (`num` / `int`) qui est probablement une conséquence du paquet
manquant (non vérifié). C'est le seul fichier `pubspec_overrides.yaml` versionné
du dépôt. Cette mesure a contourné le défaut sur une copie jetable ; le dépôt
n'a pas été modifié. À traiter par une tâche `code` si vous le souhaitez ;
`melos bootstrap` régénère ce fichier en CI, d'où l'absence de signal.

## Ce que cette mesure ne dit pas

- Les corpus sont synthétiques et générés par nous (listes courtes de noms,
  corpus adversarial écrit pour trouver les angles morts) ; une graine de
  décision et une de calibration ne mesurent pas la variance.
- Aucun document réel n'a été utilisé.
- Presidio n'a pas été rejoué (hors périmètre de cette tâche).
