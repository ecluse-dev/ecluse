# Benchmark Écluse vs Microsoft Presidio

Harnais de comparaison sur corpus synthétique français annoté.
Entités cibles : **NIR**, **RPPS**, **IBAN FR**, **FINESS**.

## Résultats (corpus v3, seed 42, 1000 documents, 826 entités)

Rejoués le 22 novembre 2026 au commit `91d009c` (Écluse **et Presidio** :
`presidio-analyzer` 2.2.366, modèle `en_core_web_lg`, seuil 0,35, prédictions
régénérées) : les chiffres du tableau ci-dessous sont identiques à ceux publiés
au commit `94749ac`. **Chemin mesuré** : les lignes « Écluse » de ce fichier qui
portent sur les identifiants (corpus v3 et `extended`) sont celles du **moteur
seul** (`ecluse_core`, `bin/run_ecluse.dart`) ; ce n'est **pas** ce que reçoit le
LLM, qui reçoit la sortie d'`Ecluse.redact` (voir les sections « Entités
floues » et suivantes, qui mesurent `Ecluse.redact`). Depuis le 22 novembre, les **48 IBAN à clé
invalide** du corpus (« L'IBAN … a été refusé par la banque ») sont **annotés**
`iban` : un IBAN mal recopié reste le compte de quelqu'un (`DECISIONS.md`,
22 novembre). Avant : 778 entités, 214 IBAN.

Appariement strict (span exact + type) :

| Moteur | Entité | Précision | Rappel | F1 |
|---|---|---:|---:|---:|
| **Écluse** | NIR | 100 % | 100 % | 100 % |
| **Écluse** | RPPS | 100 % | 100 % | 100 % |
| **Écluse** | IBAN FR | 100 % | 100 % | 100 % |
| **Écluse** | FINESS | 100 % | 100 % | 100 % |
| **Écluse** | **TOTAL**² | **95,2 %** | **100 %** | **97,5 %** |
| Presidio¹ | NIR | — | 0 % | 0 % |
| Presidio¹ | RPPS | — | 0 % | 0 % |
| Presidio¹ | IBAN FR | 100 % | 56,1 % | 71,9 % |
| Presidio¹ | FINESS | — | 0 % | 0 % |
| Presidio¹ | **TOTAL** | 100 % | **17,8 %** | **30,2 %** |

¹ Presidio rejoué sur le **corpus v3** (seed 42, 1000 documents,
826 entités), configuration par défaut (`presidio-analyzer` 2.2.366,
modèle spaCy `en_core_web_lg`, seuil 0,35). Le rappel NIR/RPPS/FINESS à
0 % est structurel (aucun recognizer français ni FINESS livré par
défaut). Le rappel IBAN de 56,1 % (147/262) vient de deux familles :
les 67 IBAN à espacement irrégulier (style `irregular`, voir plus bas) et
les 48 IBAN à clé invalide, que son recognizer écarte par la clé (avant
leur annotation : 68,7 %, 147/214).

² Les 42 faux positifs d'Écluse sont les 42 SIREN pièges, nommés `siren` et
masqués à dessein depuis P2-248 (un SIREN d'entrepreneur individuel désigne
une personne) ; ils ne sont plus comptés comme FINESS. Commande exacte de reproduction : voir *Reproduire*.

Lecture : en configuration par défaut, Presidio ne couvre **aucun
identifiant spécifiquement français** (NIR, RPPS, FINESS). Son recognizer
IBAN, à validation de clé, est précis (aucun faux positif) mais ne
retrouve ni les IBAN à espacement irrégulier ni ceux à clé invalide (rappel
56,1 %). Le corpus contient des pièges non annotés (NIR à clé invalide, RPPS à Luhn cassé,
téléphones, SIRET, SIREN) : aucun moteur n'y est tombé à tort, à
l'exception du cas de collision FINESS/SIREN — assumé et mesuré, pas un
bug.

### Espacement irrégulier (nouveau en v2)

Le corpus v2 ajoute un 4ᵉ style de formatage pour NIR et IBAN —
`irregular` : espaces multiples, tabulation, espace insécable (NBSP),
en plus des styles déjà couverts (`compact`, `spaced`, `dotted`). Motif
réel de documents copiés-collés depuis Word/PDF, où un séparateur
simple ne suffit pas à retrouver l'identifiant.

Ce style représente 67 NIR et 67 IBAN valides sur ce tirage (seed 42 ; ce compte a
changé depuis la v2 — l'ajout des gabarits FINESS/SIREN en v3 déplace la
séquence aléatoire, donc tout comptage dérivé du générateur doit être
recalculé à chaque évolution du générateur, pas seulement lu depuis une
version antérieure de ce document). Rappel sur ce sous-ensemble isolé :

| Entité | Cas à espacement irrégulier | Détectés | Rappel |
|---|---:|---:|---:|
| NIR | 67 | 67 | **100 %** |
| IBAN FR (valides) | 67 | 67 | **100 %** |
| IBAN FR (valides, plus les 19 IBAN à clé invalide écrits ainsi, annotés depuis le 22 novembre) | 86 | 86 | **100 %** |

Rejoué le 22 novembre 2026 au commit `91d009c`, **moteur seul** (`run_ecluse.dart`) :
un span est « à espacement irrégulier » s'il contient une tabulation, une
espace insécable ou deux espaces consécutifs, d'après le texte du corpus.

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

Les 42 pièges SIREN expliquaient intégralement les 42 faux positifs FINESS
(précision FINESS 75,4 % au lieu de 100 %) — vérifié un par un : aucun autre
faux positif n'existait. Depuis P2-248, ils sont nommés `siren` : précision
FINESS 100 %, et les mêmes 42 apparaissent comme faux positifs `siren` du
total (note ² ci-dessus). C'est la mesure
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

Mesure **publiée** à P1-13 (« état actuel d'Écluse », **avant toute correction**,
seed 42, 1000 documents, 739 entités annotées : avant l'annotation des IBAN à
clé invalide, qui en ajoute 27 dans ce profil, et avant P2-248), appariement
strict. **Valeurs historiques, conservées** ; l'état d'aujourd'hui est donné
plus bas (« Rejeu du 22 novembre 2026 ») :

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

**Après P1-14** (`AdeliDetector`, même corpus de 739 entités, seed 42, appariement
strict ; valeurs **publiées**, historiques) :

| Entité | Précision | Rappel | TP | FP | FN |
|---|---:|---:|---:|---:|---:|
| FINESS | 44,3 % | 100 % | 172 | 216 | 0 |
| ADELI | 100 % | 74,4 % | 93 | 0 | 32 |

Fuite au caractère des ADELI : 20,0 % → **0,0 %**. Les 32 faux négatifs
stricts sont les ADELI sans le mot « ADELI » : ils sont masqués, sous
l'étiquette `finess` (voir la fuite à 0 %). Les 68 ADELI avec mot-clé
cessent de compter comme faux positifs FINESS (284 → 216) ; NIR, RPPS et
IBAN sont inchangés. Le rappel `adeli` reste bas par construction (décision
§3.3 de la spec) : il n'est pas un défaut à corriger.

**Rejeu du 22 novembre 2026** (commit `91d009c`, **moteur seul**, `run_ecluse.dart` ;
corpus `extended`, seed 42, 1000 documents, **766 entités annotées** : NIR 174,
RPPS 117, IBAN 178, FINESS 172, ADELI 125), appariement strict :

| Entité | Précision | Rappel | TP | FP | FN | Fuite au caractère |
|---|---:|---:|---:|---:|---:|---:|
| NIR | 100 % | 100 % | 174 | 0 | 0 | 0,0 % |
| RPPS | 95,1 % | 100 % | 117 | 6 | 0 | 0,0 % |
| IBAN FR | 100 % | 100 % | 178 | 0 | 0 | 0,0 % |
| FINESS | 53,7 % | 80,2 % | 138 | 119 | 34 | 0,0 % |
| ADELI | 100 % | 74,4 % | 93 | 0 | 32 | 0,0 % |
| `siren` (aucun annoté) | 0 % | — | 0 | 131 | 0 | — |
| **TOTAL** | 73,2 % | 91,4 % | 700 | 256 | 66 | |

Ce qui a changé depuis les tableaux publiés : l'IBAN passe de 151 à 178 annotés
(27 IBAN à clé invalide annotés), et **P2-248** type `siren` un nombre appelé
« SIREN » ou « SIRET » : les FP `finess` passent de 216 à 119 (34 + 32 + 17 + 14 + 12 + 10 :
SIREN du RCS, ADELI sans mot-clé, SIREN du Kbis, SIREN devant « structure FINESS ») et 131 FP
apparaissent sous `siren`. Les **34 FN `finess`** sont des vrais FINESS
(« Structure … , gérée par la société SIREN … ») que le mot « SIREN » voisin fait
typer `siren` : masqués, donc 0,0 % de fuite, seule l'étiquette est fausse
(`LIMITES.md` § 1). Presidio avec les reconnaisseurs `validated` sur le même
corpus : NIR 100 % / 100 %, RPPS 95,1 % / 100 % (les mêmes 6 faux positifs de TVA), IBAN
100 % / 51,7 % (fuite 53,9 %), FINESS et ADELI 0 % ; TOTAL 98,5 % / 50,0 %.

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

### Presidio avec reconnaisseurs NIR et RPPS écrits à la main (P1-35)

L'objection prévisible : « Presidio est extensible ». `run_presidio.py
--recognizers` ajoute à Presidio deux `PatternRecognizer` écrits à la main
(aucune dépendance de plus, code dans `french_recognizers`) :

- `simple` : une expression régulière par identifiant, séparateurs (espaces,
  tabulations, insécables, points) tolérés ;
- `validated` : la même expression + vérification de la clé via
  `validate_result` (mod 97 pour le NIR, Luhn pour le RPPS) — la pratique
  recommandée par Presidio. C'est le **meilleur reconnaisseur raisonnable** :
  je l'ai écrit tolérant, pour ne pas affaiblir artificiellement Presidio.

Corpus v3 (seed 42, 1000 documents, 826 entités depuis le 22 novembre), appariement strict, même
configuration Presidio que la note ¹ (modèle `en_core_web_lg`, seuil 0,35) :

| Configuration | NIR (préc. / rappel) | RPPS (préc. / rappel) | IBAN FR | FINESS | TOTAL (préc. / rappel) |
|---|---:|---:|---:|---:|---:|
| Presidio par défaut | — / 0 % | — / 0 % | 100 % / 56,1 % | — / 0 % | 100 % / 17,8 % |
| + reconnaisseurs `simple` | 85,7 % / 100 % | 81,0 % / 100 % | 100 % / 56,1 % | — / 0 % | 87,4 % / 70,5 % |
| + reconnaisseurs `validated` | **100 % / 100 %** | **100 % / 100 %** | 100 % / 56,1 % | — / 0 % | 100 % / 70,5 % |
| Écluse | 100 % / 100 % | 100 % / 100 % | 100 % / 100 % | 100 % / 100 % | 95,2 % / 100 % (42 SIREN) |

Lignes Presidio rejouées le 22 novembre 2026 (commit `91d009c`, les trois
configurations, prédictions régénérées) : identiques au tableau ci-dessus. Seule
l'annotation des 48 IBAN à clé invalide a changé depuis la publication
(non détectés par le recognizer IBAN), NIR et RPPS sont identiques. Valeurs
d'**avant** cette annotation, publiées et non rejouées : IBAN 68,7 %, rappel
total 18,9 % et 74,8 %.

Lecture, sans l'arrondir en faveur d'Écluse :

- **Sur le NIR et le RPPS, un Presidio étendu et validé égale Écluse** sur ce
  corpus : la valeur d'Écluse n'est pas dans ces deux détecteurs-là, mais dans
  le fait de les livrer déjà écrits et testés. Sans la clé, la précision
  tombe à 85,7 % (NIR, 45 faux positifs) et 81,0 % (RPPS, 39 faux positifs) :
  la validation de clé est ce qui compte, pas le moteur.
- **L'écart restant vient de l'IBAN et du FINESS.** Le recognizer IBAN livré
  par Presidio ne reconnaît ni les 67 IBAN à espacement irrégulier ni les 48
  à clé invalide (rappel 56,1 %, fuite au caractère de 48,3 %, rejoués le
  22 novembre ; avant leur annotation, valeurs publiées non rejouées : 68,7 % et
  36,6 %), et rien ne couvre le FINESS. Un
  utilisateur pourrait écrire ces deux reconnaisseurs aussi : ce n'est pas
  mesuré ici (hors de la tâche).
- **Le même défaut apparaît des deux côtés** : sur le corpus étendu, le RPPS
  validé de Presidio a les mêmes 6 faux positifs que celui d'Écluse (les
  numéros de TVA passent la clé de Luhn par coïncidence), RPPS 95,1 % de
  précision pour les deux (rejoué le 22 novembre 2026).
- Hors périmètre de cette comparaison : tout ce qu'Écluse fait en plus
  (noms, adresses, restauration réversible, garde-fous d'ingestion) et que
  Presidio fait autrement (reconnaissance d'entités nommées anglophone).

Limites : un seul corpus synthétique généré par nous, une graine, un seul
auteur des reconnaisseurs (moi), seuil 0,35 non optimisé. Les scores de
reconnaisseurs (0,6 et 0,4) sont mes choix ; avec la validation, Presidio
remonte le score d'un motif valide à 1,0, donc le seuil n'intervient pas.

Reproduire :

```bash
for r in none simple validated; do
  (cd bench && python3 run_presidio.py --corpus corpus.jsonl \
     --out predictions_presidio_$r.jsonl --recognizers $r)
done
(cd bench && python3 score.py --corpus corpus.jsonl \
   --pred "Presidio_valide=predictions_presidio_validated.jsonl")
```

### PDF synthétiques pour calibrer l'ingestion (P1-18)

`generate_pdfs.py` (bibliothèque standard seule) écrit à la main 18 PDF
**reproductibles octet pour octet** (graine 42, pas d'horodatage, images en
ASCIIHex) dans `bench/pdf/`, avec `expected.json` : nature, résultat attendu
(`accepte`, `accepte_avertissement`, `refuse`), code de motif et identifiants
fabriqués (clés valides calculées) que le texte extrait doit contenir. Les
attendus décrivent la **cible** de `agent/specs/P1-09-pdf.md` §3, pas le
comportement d'une bibliothèque. Les seuils (20 caractères alphanumériques par
page, 200 pages, 50 Mo) restent des valeurs de départ à calibrer en P1-17.

| Fichier | Contenu | Attendu |
|---|---|---|
| `texte_simple`, `texte_multipage`, `texte_colonnes`, `texte_iban_coupe` | texte, 1 à 3 pages, deux colonnes, IBAN coupé par une fin de ligne | accepté |
| `texte_et_image`, `metadonnees_annotation` | tampon image ; `/Info` et annotation portant un identifiant | accepté **avec avertissement** |
| `page_blanche`, `javascript` | page sans contenu ; `/OpenAction` JavaScript (jamais exécuté) | accepté |
| `scan_pur`, `texte_quasi_vide`, `sans_page` | aucune couche texte | refus `sans_texte` |
| `mixte` | page 1 texte, pages 2 et 3 images | refus `partiellement_numerise` (document entier) |
| `texte_illisible`, `texte_illisible_latin` | police Type0 sans `ToUnicode` : caractères en zone privée / en lettres latines étendues | refus `texte_illisible` |
| `chiffre` | RC4 40 bits, mot de passe utilisateur vide | refus `chiffre` |
| `tronque`, `xref_casse` | sans xref ni trailer ; `startxref` erroné | refus `malforme` |
| `tres_long_250_pages` | 250 pages | refus `plafond_pages` |

`--with-oversize` ajoute `tres_gros.pdf` (51 Mo, non versionné) pour le plafond de taille.

Rejoué le 22 novembre 2026 (commit `91d009c`) : `python3 bench/generate_pdfs.py --out <dossier>`
écrit 18 PDF, **identiques octet pour octet** à ceux versionnés dans `bench/pdf/`
(`diff -rq` sans écart).

**Ce que le jeu montre déjà** (lecture avec `pdftotext` de poppler, outil de
vérification local, pas une dépendance du projet) :

- `texte_illisible_latin` met en défaut les critères de qualité du spec §3 :
  aucun `U+FFFD`, aucun caractère de zone privée, 100 % de lettres. Le texte
  rendu est du bruit (« ŎŵŭťŲů… ») qui passerait le garde-fou tel que spécifié.
  Il faudra un critère sur la part de caractères hors du jeu attendu.
- Un lecteur courant **reconstruit** le `xref_casse` et lit le texte, et lit
  le `chiffre` sans mot de passe : le refus de ces deux cas est une
  **politique** d'Écluse (règle n°4), pas une conséquence de l'échec de la
  lecture.
- `scan_pur` donne un texte vide ; `tronque` et `sans_page` produisent une
  erreur, pas un texte vide.

Tests : `python3 -m unittest discover -s bench` (reproductibilité, jeu
versionné identique à la génération, clés des identifiants, cohérence de la
table xref des PDF intacts, présence des identifiants dans le texte extrait
si `pdftotext` est installé).

### Entités floues : noms, adresses, dates, téléphones, emails, établissements

Les identifiants à clé (NIR, RPPS, IBAN, FINESS) se valident ; les entités
« floues » non. Un second générateur (`generate_corpus_flou.py`) produit
trois corpus **séparés, jamais fusionnés** : *réaliste* (documents
plausibles), *adversarial* (pièges denses : prénoms étrangers, initiales,
dates ISO, adresses atypiques) et *témoin* (aucune entité, que des leurres
légitimes : toute détection est un faux positif). Le scoreur
(`score_flou.py`) donne trois mesures : strict (span exact + type), souple
(recouvrement) et **fuite au caractère** (part des caractères sensibles
restée en clair, toutes catégories confondues) — la fuite est la mesure de
référence. Moteur : `Ecluse.redact` complet (détecteurs à clé + heuristiques) : **c'est le
chemin du produit, ce que reçoit le LLM**. Seed 42, 400 documents par corpus,
rejoués le 22 novembre 2026 au commit `91d009c` (`run_redact_bench.dart` puis
`score_flou.py`). Le corpus réaliste est inchangé depuis la publication ; le
**corpus adversarial a changé** (valeurs publiées avant : voir la note ³).

| Corpus | Type | Annotés | Détectés | Rappel strict | F1 souple | Fuite |
|---|---|---:|---:|---:|---:|---:|
| Réaliste | adresse | 159 | 159 | 100 % | 100 % | 0 % |
| Réaliste | date de naissance | 159 | 159 | 100 % | 100 % | 0 % |
| Réaliste | email | 247 | 247 | 100 % | 100 % | 0 % |
| Réaliste | établissement | 400 | 400 | 79,2 % | 100 % | 0 % |
| Réaliste | nom | 479 | 479 | 16,3 % | 100 % | 27,7 % ² |
| Réaliste | téléphone | 233 | 233 | 100 % | 100 % | 0 % |
| Réaliste | **global** | 1677 | 1677 | 71,1 % | 100 % | **7,5 %** |
| Adversarial | adresse | 155 | 155 | 100 % | 100 % | 0 % |
| Adversarial | date de naissance | 53 | 53 | 100 % | 100 % | 0 % |
| Adversarial | email | 53 | 53 | 100 % | 100 % | 0 % |
| Adversarial | établissement | 114 | 114 | 100 % | 100 % | 0 % |
| Adversarial | nom | 594 | 579 | 71,4 % | 98,7 % | 11,0 % |
| Adversarial | téléphone | 113 | 113 | 100 % | 100 % | 0 % |
| Adversarial | **global** | 1082 | 1067 | 84,3 % | 99,3 % | **5,3 %** |
| Témoin | — | 0 | 0 | — | — | 0 détection (0 faux positif) |

² La fuite de 27,7 % sur les noms du corpus réaliste est **entièrement** la
civilité (« M. », « Monsieur », « Mme », « Madame », « Mademoiselle »), que
le corpus annote dans le nom alors qu'Écluse la conserve volontairement en
clair (`LIMITES.md`, point 4). Ce n'est pas une fuite de nom propre ; le
rappel strict de 16,3 % est le même artefact de convention.

³ Valeurs **publiées** du corpus adversarial avant le rejeu du 22 novembre 2026
(historiques, non rejouées) : adresse 106 détectées sur 155 (rappel strict 34,2 %,
fuite 15,0 %) ; nom 504 sur 594 (rappel strict 53,4 %, F1 souple 83,2 %, fuite 27,2 %) ;
global 943 sur 1082 (rappel strict 65,0 %, F1 souple 88,5 %, fuite 16,8 %).

Lecture : sur le corpus réaliste, aucun nom propre, adresse, date, email ni
téléphone n'échappe. Sur le corpus adversarial, **5,3 % des caractères
sensibles restent en clair**, tous des noms (11,0 % des caractères de noms) : d'après
`leak_hors_civilite.py` (section « Fuite des noms hors civilité »), surtout des prénoms
hors gazetteer (« Souleymane », « Yaroslav ») et quelques patronymes. Aucune adresse
n'est en clair sur ce corpus au rejeu du 22 novembre (15,0 % avant, note ³). Le NER
local est gelé (STOP du 8 novembre, `DECISIONS.md` P2-90) : les heuristiques restent la
détection des noms et adresses.

**Restauration.** Le runner signale 62 documents du corpus adversarial dont
la restauration n'est pas octet pour octet (0 sur le corpus réaliste ; 61 à la
publication, 62 au rejeu du 22 novembre 2026). Ce
sont les variantes d'ordre ou de casse d'une même personne
(« PERROT Olivier », « Olivier Perrot », « OLIVIER PERROT »), harmonisées sur
une seule graphie à la restauration : le compromis documenté en
`LIMITES.md` § 5.3, pas une corruption.

Limites : corpus synthétique et généré par nous, une seule graine, noms issus
de listes courtes (les mêmes patronymes reviennent), corpus adversarial écrit
pour trouver les angles morts. Aucun concurrent n'est mesuré ici.

Reproduire (depuis la racine du dépôt) :

```bash
mkdir -p bench/flou
python3 bench/generate_corpus_flou.py --n 400 --seed 42 --out-dir bench/flou
for c in realiste adversarial temoin; do
  (cd packages/ecluse_redact && dart run bin/run_redact_bench.dart \
     ../../bench/flou/corpus_flou_$c.jsonl ../../bench/flou/pred_$c.jsonl)
  (cd bench && python3 score_flou.py --corpus flou/corpus_flou_$c.jsonl \
     --pred "Ecluse=flou/pred_$c.jsonl")
done
```

Les fichiers générés (`bench/flou/`) ne sont pas versionnés.

### Quasi-identifiants : profession, lieu, âge (profil `qi`, P2-03a)

Les corpus précédents mesurent des **entités masquées**. `ecluse_reid`
(`LIMITES.md` § 7) travaille sur autre chose : trois quasi-identifiants (QI) qui
restent en clair dans le texte masqué, et dont la combinaison peut ré-identifier
une personne. Rien ne mesurait leur extraction ; ce profil est l'outil de mesure
qui manquait (règle 5 de `CLAUDE.md`). Première mesure de `ecluse_reid` plus bas
(P2-03b).

Trois corpus séparés, jamais fusionnés (graine 42, 400 documents chacun) :

| Corpus | QI annotés | Contenu |
|---|---|---|
| Réaliste | 731 (241 âges, 320 lieux, 170 professions) | comptes rendus à **une** personne : profession + lieu + âge, lieu + âge, lieu seul, profession + lieu, âge seul |
| Adversarial | 909 (330 âges, 396 lieux, 183 professions) ; 108 documents de plusieurs personnes | communes homonymes, lieux **sans population** dans les données de référence (Paris, Lyon, Marseille, Mayotte), population nulle, plusieurs lieux, plusieurs âges, profession sans lieu, âges aux bornes (0 à 110 ans), espace insécable, âge en toutes lettres, synonymes et abréviations de spécialités, communes à article, tirets et apostrophes |
| Témoin | 0 | durées (« depuis 3 ans »), mots courants qui sont aussi des communes (« Orange », « Tours de garde »), professions hors périmètre, lieu de réunion sans lien avec une personne : toute extraction est un faux positif |

**Conventions de span.** Âge : les chiffres, l'espace (ou l'espace insécable) et
« ans » (« 94 ans »). Lieu : le nom de la commune tel qu'écrit. Profession : le
terme tel qu'écrit. Les professions **hors périmètre** d'`ecluse_reid`
(infirmière, kinésithérapeute…) figurent dans le texte mais ne sont pas annotées.
Chaque document porte un champ `personnes` (nombre de personnes évoquées).

`score_qi.py` donne, par type : précision, rappel et F1 stricts, F1 souple, et la
part de caractères de QI **non couverts** par une extraction du même type (la
mesure de référence, comme la fuite au caractère de `score_flou.py`) ; le rappel
selon le nombre de personnes ; la répartition des documents par statut si les
prédictions en portent un ; et, sur le témoin, le nombre d'extractions.

```bash
mkdir -p bench/qi
python3 bench/generate_corpus_qi.py --n 400 --seed 42 --out-dir bench/qi
# Prédictions : un fichier JSONL par corpus, {"id", "entities", "statut"?}
python3 bench/score_qi.py --corpus bench/qi/corpus_qi_realiste.jsonl \
    --pred "Moteur=bench/qi/pred_qi_realiste.jsonl"
```

Les fichiers générés (`bench/qi/`) ne sont pas versionnés.

#### Première mesure : `ecluse_reid` avant et après P2-03b

```bash
for c in realiste adversarial temoin; do
  # Avant : chaîne extractQis puis estimate (exceptions par cause)
  (cd packages/ecluse_reid && dart run bin/run_reid_bench.dart --avant \
     ../../bench/qi/corpus_qi_$c.jsonl)
  # Après : extractQiSpans + evaluateText (QI positionnés et statut)
  (cd packages/ecluse_reid && dart run bin/run_reid_bench.dart \
     ../../bench/qi/corpus_qi_$c.jsonl ../../bench/qi/pred_qi_$c.jsonl)
  python3 bench/score_qi.py --corpus bench/qi/corpus_qi_$c.jsonl \
     --pred "Ecluse=bench/qi/pred_qi_$c.jsonl"
done
```

Avant : sur combien de documents la chaîne actuelle lève-t-elle une exception ?
(400 documents par corpus ; graine 42, puis graine 7 entre parenthèses.) **Rejoué le
22 novembre 2026** au commit `91d009c`, commande `run_reid_bench.dart --avant` des deux
graines : réaliste et adversarial inchangés, le témoin **a changé**.

| Corpus | Documents en exception | Cause | Sans QI, classés « risque faible » |
|---|---:|---|---:|
| Réaliste | 66 = 16,5 % (48 = 12,0 %) | doublon de type | 0 |
| Adversarial | 166 = 41,5 % (170 = 42,5 %) | 138 doublons de type, 28 professions sans lieu (graine 7 : 144 et 26) | 0 |
| Témoin | **0** (0) | — | **400** (400) |

Valeurs **publiées** du témoin à P2-03b (historiques, non rejouées) : 75 = 18,8 % (69 =
17,3 %) en exception, doublon de type, 63 (67) sans QI classés « risque faible ».

Même sur le corpus **réaliste**, où chaque document ne parle que d'une personne,
des exceptions surviennent : l'extraction actuelle produit des doublons à partir
d'un seul mot (« médecin généraliste » donne deux professions, « chirurgien-
dentiste » en donne trois, « pharmacienne » deux) et lit un patronyme qui est
aussi une commune (« Chevrier ») comme un second lieu.

Après : l'évaluation totale n'a **aucune exception** sur les trois corpus de la graine 42.
**Rejoué le 22 novembre 2026** (commit `91d009c`, `run_reid_bench.dart` puis `score_qi.py` ;
`ecluse_reid` seul, ce n'est pas `Ecluse.redact`). Graine 42 :

| Corpus | évalué | non évaluable | aucun QI |
|---|---:|---:|---:|
| Réaliste | 400 | 0 | 0 |
| Adversarial | 228 | 172 | 0 |
| Témoin | 0 | 0 | 400 |

Extraction (strict, graine 42, rejouée le 22 novembre 2026) :

| Corpus | Type | Précision | Rappel | Non couverts |
|---|---|---:|---:|---:|
| Réaliste | âge / lieu / profession | 100 % / 100 % / 100 % | 100 % / 100 % / 100 % | 0 % / 0 % / 0 % |
| Adversarial | âge | 100 % | 100 % | 0 % |
| Adversarial | lieu | 100 % | 100 % | 0 % |
| Adversarial | profession | 100 % | 100 % | 0 % |
| Témoin | tous types | 0 extraction, 0 document sur 400 touché | | |

Valeurs **publiées** à P2-03b (historiques, non rejouées) : évalué / non évaluable / aucun QI
364 / 36 / 0 (réaliste), 215 / 185 / 0 (adversarial), 262 / 75 / 63 (témoin) ; extraction
réaliste lieu 88,2 % de précision ; adversarial âge 95,5 % de rappel et 12,7 % non couverts,
lieu 92,3 % de précision, profession 96,2 % de rappel et 2,0 % non couverts ; témoin 412
extractions sur 337 documents touchés.

Lecture, sans l'arrondir :

- **Les 100 % du rejeu ne prouvent rien sur des textes réels** : ces corpus sont écrits
  avec les mots que l'extraction connaît et ne sont pas indépendants de son vocabulaire,
  sur le réaliste comme sur l'adversarial (23 communes courantes, 16 professions).
- **L'écart avec la publication est un constat, pas une explication** : à P2-03b,
  l'adversarial laissait 12,7 % des caractères d'âge non couverts (âges en toutes lettres,
  abréviations comme « pneumo », « gynéco »), le réaliste lisait « Chevrier » (un
  patronyme qui est aussi une commune) comme un lieu (43 faux positifs sur 43) et le
  témoin laissait passer 412 extractions (« Nuits », « Tours », durées lues comme des âges).
  Rien de cela ne se reproduit sur ces corpus au 22 novembre 2026 ; ce fichier ne dit pas
  quelles tâches l'ont corrigé, le dépôt (`git log -- packages/ecluse_reid`) le dit.
- Sur le témoin, le statut « aucun QI » (400 / 400) remplace les 262 documents
  « évalués » de P2-03b, qui étaient des fausses évaluations (le statut dit que F est
  estimé, pas que l'estimation est juste).

Limites : corpus synthétique et généré par nous, une graine par exécution (aucune variance mesurée),
vocabulaire court (23 communes courantes, 16 professions, quelques gabarits de
phrase). Les noms de communes sont réels (géographie publique) ; tout le reste est
inventé. L'annotation d'une profession ou d'un âge « en toutes lettres » est un
choix de convention. Aucune vérité terrain n'existe pour la **taille d'une classe
d'équivalence** (F) : ce profil mesure l'extraction, pas la justesse de F.

#### Généralisation appliquée : avant/après (P2-93)

Mesure seulement, rien n'est corrigé. `run_generalisation_bench.dart` exécute
`Ecluse.redact` avec référence, puis applique la suggestion retenue
(`appliquerGeneralisations`, P2-92), à répéter tant qu'une suggestion reste (10
tours au plus). Corpus de QI, graine 42, 400 documents chacun. Chemin mesuré :
`Ecluse.redact` avec référence, puis `appliquerGeneralisations`. **Rejoué le
22 novembre 2026** au commit `91d009c` ; les valeurs publiées à P2-93 sont gardées en
note après le tableau.

```bash
for c in realiste adversarial temoin; do
  (cd packages/ecluse_redact && dart run bin/run_generalisation_bench.dart \
     ../../bench/qi/corpus_qi_$c.jsonl)
done
```

| Corpus | Avec suggestion | Refus | F médian avant → après 1er tour | Bande après 1er tour |
|---|---:|---:|---|---|
| Réaliste | 170 | 0 | 74,0 → 2002,0 | faible 170 |
| Adversarial | 118 | 0 | 7,0 → 2320,0 | faible 110, moyen 7, élevé 1 |
| Témoin | 0 | 0 | n/a | n/a |

Valeurs **publiées** à P2-93 (historiques, non rejouées) : réaliste 170 suggestions,
F 74,0 → 2978,7, faible 165 et moyen 5 ; adversarial 109 suggestions,
F 6,0 → 142346,0, faible 70, élevé 7, non évaluable 32.

Invariants tenus sur les trois corpus (rejoué) : table et entités inchangées, texte
inchangé quand il n'y a rien à appliquer, restauration des entités masquées
exacte (0 écart). Au premier tour, F monte dans les 170 documents du réaliste et les
118 de l'adversarial (0 cas où F ne monte pas) ; plus aucune suggestion après 3 tours au
plus, aucun document au plafond de 10 tours.

Défauts constatés à P2-93, **non corrigés alors** ; **le rejeu du 22 novembre 2026 ne les
reproduit plus** (F ne monte pas : 0 / 170 et 0 / 118 ; 3 tours au plus ; aucun « non
évaluable » parmi les 118 documents à suggestion, bande finale faible 111, moyen 7) :

- **F ne monte pas après une généralisation censée le faire monter** : 6
  documents sur 170 (réaliste) et 7 sur 109 (adversarial) à F **inchangé ou en
  baisse** au premier tour. Exemples : « 103 ans » → « 100-104 ans » (F 8,5 →
  4,8) ; « médecin généraliste » → « médecin (toute spécialité) » (F 379 → 96).
  Le texte généralisé n'est pas relu comme l'a simulé `ReidLoop`.
- **Bouclage sur les âges de 100 ans et plus** : « 104 ans » devient « 100-104
  ans », dont l'extraction relit « 104 ans » ; une nouvelle suggestion donne
  « 100-100-104 ans », etc. 7 documents de l'adversarial atteignent le plafond de
  10 tours (« 100-100-…-104 ans »). Un appelant qui boucle sans plafond ne
  s'arrête pas.
- **Généraliser fait parfois perdre l'évaluation** : 32 documents de
  l'adversarial passent à « non évaluable » (profession généralisée en « médecin
  (toute spécialité) » avec un lieu sans population, p. ex. Marseille).

Limites : corpus synthétique, une graine, F médian sur les seuls documents
évaluables ; la mesure ne dit pas si la généralisation protège réellement une
personne (aucune vérité terrain sur la taille d'une classe).

#### Généralisation du lieu (P2-103)

Mesure seulement. Le corpus de P2-93 ne généralisait jamais le lieu ;
`run_generalisation_lieu_bench.dart` construit 810 documents synthétiques
déterministes et applique la suggestion de lieu.

```bash
(cd packages/ecluse_redact && dart run bin/run_generalisation_lieu_bench.dart)
```

Résultat, **rejoué le 22 novembre 2026** (commit `91d009c`) : 24 documents (lieu + âge
extrême) ont une suggestion de lieu. Après application, « département N » est relu (un QI
lieu relu sur 24) : F recalculé = F simulé dans les 24 cas (rapport médian 1,000) et la
bande recalculée est celle de la simulation (élevé 1, faible 3, moyen 20). **Valeurs
publiées à P2-103** (historiques) : « département N » n'était pas relu (0 QI lieu sur 24),
F recalculé valait en médiane 157 fois le F simulé et la bande passait à « faible » dans
les 24 cas, alors que la simulation annonçait « moyen » dans 20. Détails et limites :
`agent/specs/P2-103.md`.

## Dossiers (P2-05a)

Corpus multi-documents et scoreur pour mesurer la cohérence des jetons d'un
document à l'autre (spec `agent/specs/P2-05.md`). Un *dossier* est une suite de
3 à 6 documents sur les mêmes personnes ; chaque mention annotée porte une
`identite` (une par personne, ou par valeur pour e-mail et téléphone, partagée
entre dossiers quand la même personne y figure). Trois corpus, jamais fusionnés :
réaliste, adversarial (ordres différents, homonymes de même sexe, couple,
patronymes courants, mention partielle `ambigue`, contacts répétés, jeton
littéral `[NOM_1]` dans le texte, mêmes personnes dans plusieurs dossiers) et
témoin (aucune personne commune entre dossiers).

```bash
python3 bench/generate_corpus_dossiers.py --n 400 --seed 42 --out-dir bench/dossiers
(cd packages/ecluse_redact && dart run bin/run_dossiers_bench.dart \
  ../../bench/dossiers/corpus_dossiers_realiste.jsonl \
  ../../bench/dossiers/pred_dossiers_realiste.jsonl)
python3 bench/score_dossiers.py \
  --corpus bench/dossiers/corpus_dossiers_realiste.jsonl \
  --pred bench/dossiers/pred_dossiers_realiste.jsonl
python3 -m unittest discover -s bench
```

(`mkdir -p bench/dossiers` d'abord ; idem pour `adversarial` et `temoin`.)

Le programme Dart masque chaque document **séparément** avec l'`Ecluse.redact`
actuel et restaure avec la table de cet appel : il mesure l'état sans dossier.
Avec `--dossier` (P2-06), les documents d'un même dossier partagent un
`Dossier` et sont restaurés par lui ; avec `--regle=n2` (P2-13), le dossier
utilise la fusion par inclusion entre documents au lieu de N1.
Le scoreur rapporte la cohérence, les collisions, les fausses fusions, les
restaurations non identiques et le recoupement (définitions en tête de
`score_dossiers.py`). Les mentions annotées non détectées sont comptées à part
et exclues des autres mesures. Le recoupement est un signal structurel (la
numérotation des jetons repart de 1 à chaque appel) : il est donné avec sa
référence et ne s'interprète pas tant que la menace n'est pas confirmée.

Les fichiers générés (`bench/dossiers/`, `bench/corpus_dossiers_*.jsonl`) ne
sont pas versionnés.

## Fuite des noms hors civilité (P2-12)

`bench/leak_hors_civilite.py` compte, mot par mot, les caractères non blancs des
noms annotés restés en clair (non couverts par un span prédit, de n'importe quel
type, comme `score_flou.py`) et sépare la civilité du reste. Il vérifie
l'affirmation du README selon laquelle la fuite des noms du corpus réaliste est
« entièrement » la civilité conservée volontairement. Les comptes excluent les
espaces : leurs pourcentages ne sont pas comparables à ceux de `score_flou.py`,
seule la **part** hors civilité l'est.

```bash
mkdir -p bench/flou
python3 bench/generate_corpus_flou.py --n 400 --seed 42 --out-dir bench/flou
(cd packages/ecluse_redact && dart run bin/run_redact_bench.dart \
  ../../bench/flou/corpus_flou_adversarial.jsonl \
  ../../bench/flou/pred_redact_adversarial.jsonl)
python3 bench/leak_hors_civilite.py \
  --corpus bench/flou/corpus_flou_adversarial.jsonl \
  --pred bench/flou/pred_redact_adversarial.jsonl
```

Résultat, **rejoué le 22 novembre 2026** (400 documents, `Ecluse.redact` au commit
`91d009c`, `leak_hors_civilite.py` sur les corpus `realiste` et `adversarial` des
graines 42 et 7) : réaliste, **0** caractère hors civilité sur 2167 (graine 42) et
2366 (graine 7) ; adversarial, **279 sur 1057** (26,4 %, graine 42) et **256 sur 1142**
(22,4 %, graine 7), surtout les prénoms « Souleymane » et « Yaroslav » (hors
gazetteer), puis quelques patronymes. **Valeurs publiées** (`Ecluse.redact` du
25 octobre 2026, historiques, non rejouées) : adversarial 1865 sur 2657 (70,2 %,
graine 42) et 1901 sur 2799 (67,9 %, graine 7), celles de
`agent/specs/P2-02-reference.md` ; le réaliste était identique.

## Patronyme seul (P2-14)

`bench/generate_corpus_patronymes.py` et `bench/score_patronymes.py` séparent les
cas du patronyme sans civilité ni prénom : **a** (après une mention complète du
même document), **b** (en première mention, sans ancrage), **c** (dans un
document ultérieur du dossier) et des **leurres** (le patronyme du dossier est
aussi un mot courant : « Petit déjeuner », « Marchand de journaux »).
« Rose » en est exclu : c'est aussi un prénom du gazetteer, déjà détecté seul.

```bash
mkdir -p bench/patronymes
python3 bench/generate_corpus_patronymes.py --n 400 --seed 42 --out-dir bench/patronymes
for c in a b c leurres; do
  (cd packages/ecluse_redact && dart run bin/run_dossiers_bench.dart --dossier \
    ../../bench/patronymes/corpus_patronymes_$c.jsonl \
    ../../bench/patronymes/pred_patronymes_$c.jsonl)
  python3 bench/score_patronymes.py \
    --corpus bench/patronymes/corpus_patronymes_$c.jsonl \
    --pred bench/patronymes/pred_patronymes_$c.jsonl
done
# faux positifs sur un corpus dont toutes les personnes sont annotées :
python3 bench/score_patronymes.py --faux-positifs --corpus <corpus_dossiers.jsonl> --pred <pred.jsonl>
# règle naïve « mot capitalisé hors début de phrase » sur le témoin flou :
python3 bench/score_patronymes.py --regle-naive --corpus <corpus_flou_temoin.jsonl> --pred <pred_flou.jsonl>
```

Sans `--dossier`, le programme mesure l'état d'avant P2-14 (un appel par
document). Résultats (400 documents, graines 42 et 7) : voir `LIMITES.md` § 5.4.

## Fuites sémantiques : corpus du vérificateur LLM (P2-105)

Corpus de mesure du vérificateur LLM local (critère de
`agent/specs/P2-104.md`). Une **fuite sémantique** est un indice qui
ré-identifie sans être un identifiant ni un nom : rôle unique (« la seule
pédiatre de Vesoul »), événement daté (« qui a démissionné le 3 mars »),
rareté (« atteint de la maladie de Huntington »), coréférence (« Sa fille,
interne en cardiologie au CHU de Besançon »). Les détecteurs d'Écluse ne les
masquent pas.

```bash
mkdir -p bench/semantique
python3 bench/generate_corpus_semantique.py --n 300 --seed 42 --out-dir bench/semantique
# Prédictions du vérificateur : bench/semantique/pred/pred_semantique_<corpus>.jsonl
python3 bench/score_semantique.py --dir bench/semantique --pred-dir bench/semantique/pred
```

Graine 42, 300 documents par corpus (régénérés le 22 novembre 2026 au commit
`91d009c`, mêmes comptes) : `indices` (412 indices annotés),
`temoin` (aucun indice : rôles collectifs, faits banals), `injection` (les
documents de `indices` au même rang, avec une instruction qui demande au
vérificateur de se taire). Les textes sont des textes **d'origine** (avant
`Ecluse.redact`) : les noms de personnes y figurent, sans annotation.

Le scoreur rend les conditions A (indices trouvés, un caractère de
recouvrement suffit), C (fausses alertes du témoin), D (documents « non
vérifié ») et E (écart sous injection). Un document absent des prédictions
compte comme « non vérifié », jamais comme « rien à signaler ».

Limites : gabarits peu nombreux et écrits par nous ; un indice est un
segment de phrase dont les bornes sont un choix de convention (d'où la règle
du recouvrement) ; aucun texte réel ; aucune mesure n'a encore été faite
(elle attend la décision sur le NER, P2-104a).

## Rejeu du 22 novembre 2026 (P2-256)

Chaque mesure citée par ce fichier a été rejouée au commit `91d009c` (`main`), graine 42
(et 7 là où le fichier cite la graine 7), avec la commande que la section donne. Ce
tableau dit **quel chemin** chaque section mesure et si le chiffre a changé :

| Section | Chemin mesuré | Commande rejouée | Écart avec la publication |
|---|---|---|---|
| Résultats (corpus v3), collision FINESS ↔ SIREN, espacement irrégulier | moteur seul (`ecluse_core`) ; Presidio rejoué | `run_ecluse.dart`, `run_presidio.py` (3 configurations), `score.py` | aucun ; ligne ajoutée (86 IBAN irréguliers, 19 à clé invalide) |
| Corpus étendu (`extended`) | moteur seul | `generate_corpus.py --profile extended`, `run_ecluse.dart`, `run_presidio.py --recognizers validated`, `score.py` | **état actuel ajouté** (766 entités) ; tableaux de P1-13 / P1-14 gardés comme historiques |
| Presidio étendu (P1-35) | Presidio | `run_presidio.py` ×3, `score.py` | aucun |
| PDF synthétiques (P1-18) | — (génération) | `generate_pdfs.py` | aucun (18 PDF identiques) |
| Entités floues | `Ecluse.redact` | `run_redact_bench.dart`, `score_flou.py` | **adversarial changé** ; réaliste et témoin inchangés |
| Quasi-identifiants (P2-03a, P2-03b) | `ecluse_reid` seul | `run_reid_bench.dart` (avant et après), `score_qi.py` | **extraction, statuts et témoin changés** ; exceptions « avant » inchangées sauf le témoin |
| Généralisation (P2-93), du lieu (P2-103) | `Ecluse.redact` + `appliquerGeneralisations` | `run_generalisation_bench.dart`, `run_generalisation_lieu_bench.dart` | **changés** (défauts de P2-93 et P2-103 non reproduits) |
| Dossiers (P2-05a) | `Ecluse.redact` | `run_dossiers_bench.dart`, `score_dossiers.py` | aucun chiffre cité par le fichier |
| Fuite des noms hors civilité (P2-12) | `Ecluse.redact` | `run_redact_bench.dart`, `leak_hors_civilite.py` | **adversarial changé** ; réaliste inchangé |
| Patronyme seul (P2-14) | `Ecluse.redact` avec dossier | — | aucun chiffre cité (renvoi à `LIMITES.md` § 5.4) |
| Fuites sémantiques (P2-105) | corpus seul (aucune prédiction) | `generate_corpus_semantique.py` | aucun (412 indices) |

Presidio : rejoué avec `presidio-analyzer` 2.2.366 et le modèle `en_core_web_lg`
(installé par `python3 -m spacy download en_core_web_lg`) ; l'option `--blank` n'a pas
servi. Les fichiers générés (`bench/*.jsonl`, `bench/flou/`, `bench/qi/`) ne sont pas
versionnés.

## Honnêteté méthodologique

- **Presidio est extensible.** Un développeur peut écrire des
  recognizers NIR/RPPS personnalisés. Le tableau principal mesure ce qui est
  livré clé en main ; l'extension est mesurée à part (P1-35, plus haut) et
  **égale Écluse sur le NIR et le RPPS** dès qu'elle vérifie la clé.
- **Le corpus est synthétique et généré par nous.** Générateur et seed
  publics : quiconque peut le reproduire, le critiquer ou l'étendre
  (`generate_corpus.py --seed 42 --n 1000`). Changer le générateur
  (comme l'ajout du style `irregular` en v2) change le corpus produit à
  seed égal : les résultats ci-dessus ne sont comparables qu'entre
  exécutions du même générateur.
- **Cas RPPS enchâssé dans un IBAN.** Une fenêtre de 11 chiffres passant
  Luhn par hasard à l'intérieur d'un IBAN, valide ou non, est écartée par
  `RppsDetector` (forme d'IBAN) et par `resolveOverlaps` ; sur ce tirage
  le RPPS ne produit aucun faux positif (166 TP, 0 FP, 0 FN ; rejoué le 22 novembre 2026,
  moteur seul). Une version
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

PDF synthétiques :

```bash
python3 bench/generate_pdfs.py --out bench/pdf
```
