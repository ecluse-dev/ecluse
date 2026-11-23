# Comparatif d'outils (P2-224)

Mesure seule, produite par `bench/comparatif.py`. Elle ne tourne pas dans
`bench/etat.sh`. Ses chiffres sont la source des parties 2 et 3 de
l'article de benchmark ; ils ne sont pas repris dans `bench/README.md`.

## Commande exacte

```
python3 bench/comparatif.py --md bench/COMPARATIF.md --temoin
```

Environnement : `pip install -r bench/requirements-comparatif.txt` puis
`python3 -m spacy download fr_core_news_lg en_core_web_lg`, et
`pip install git+https://github.com/aphp/eds-pseudo.git` (voir ce fichier).
Les corpus sont ceux que `bench/etat.sh` génère (graine 42) ; `dart` doit
être dans le `PATH`.

## Versions

| Composant | Version |
|---|---|
| Écluse (commit du dépôt) | c813ef4 |
| Dart | Dart SDK version: 3.14.1 (stable) (Tue Nov 17 00:01:24 2026 -0800) on "linux_x64" |
| Python | 3.13.18 |
| presidio-analyzer | 2.2.366 |
| spacy | 3.8.18 |
| fr_core_news_lg | 3.8.0 |
| en_core_web_lg | 3.8.0 |
| edsnlp | 0.24.0 |
| eds-pseudo (installé depuis GitHub) | 0.4.0, commit 844a6cbb3280 |

## Échantillon

148 documents (graine 42) : 48 dossiers, 50 flou, 50 v3 ; dont 12 sans entité annotée.

## Résultats : entités entièrement couvertes, par outil et par type

| Type annoté | Écluse, document par document | Écluse, session de dossier | Presidio par défaut | Presidio en français | spaCy fr_core_news_lg seul | EDS-Pseudo (règles) |
|---|---:|---:|---:|---:|---:|---:|
| adresse | 50/50 (100 %) | 50/50 (100 %) | 0/50 (0 %) | 0/50 (0 %) | 0/50 (0 %) | 0/50 (0 %) |
| date_naissance | 50/50 (100 %) | 50/50 (100 %) | 41/50 (82 %) | 31/50 (62 %) | 0/50 (0 %) | 50/50 (100 %) |
| email | 22/22 (100 %) | 22/22 (100 %) | 22/22 (100 %) | 22/22 (100 %) | 4/22 (18 %) | 22/22 (100 %) |
| etablissement | 50/50 (100 %) | 50/50 (100 %) | 4/50 (8 %) | 28/50 (56 %) | 28/50 (56 %) | 0/50 (0 %) |
| finess | 6/6 (100 %) | 6/6 (100 %) | 0/6 (0 %) | 0/6 (0 %) | 0/6 (0 %) | 0/6 (0 %) |
| iban | 15/15 (100 %) | 15/15 (100 %) | 9/15 (60 %) | 8/15 (53 %) | 7/15 (47 %) | 0/15 (0 %) |
| nir | 10/10 (100 %) | 10/10 (100 %) | 1/10 (10 %) | 0/10 (0 %) | 0/10 (0 %) | 7/10 (70 %) |
| nom | 127/127 (100 %) | 127/127 (100 %) | 81/127 (64 %) | 127/127 (100 %) | 127/127 (100 %) | 78/127 (61 %) |
| rpps | 6/6 (100 %) | 6/6 (100 %) | 3/6 (50 %) | 3/6 (50 %) | 0/6 (0 %) | 3/6 (50 %) |
| siren | 7/7 (100 %) | 7/7 (100 %) | 6/7 (86 %) | 2/7 (29 %) | 0/7 (0 %) | 0/7 (0 %) |
| telephone | 40/40 (100 %) | 40/40 (100 %) | 39/40 (98 %) | 39/40 (98 %) | 0/40 (0 %) | 40/40 (100 %) |
| **Toutes entités** | **383/383 (100 %)** | **383/383 (100 %)** | **206/383 (54 %)** | **260/383 (68 %)** | **166/383 (43 %)** | **200/383 (52 %)** |
| Documents sans entité masqués à tort | 5/12 (42 %) | 5/12 (42 %) | 11/12 (92 %) | 7/12 (58 %) | 5/12 (42 %) | 2/12 (17 %) |

## Comparaison principale : types communs (P2-261)

Mêmes prédictions, **`siren` retiré** de l'or et des prédictions pour
**tous les outils** (même règle). Une ligne « Toutes entités » ci-dessus
compte les identifiants d'entreprise, qu'Écluse masque à dessein
(DECISIONS.md, 23 novembre, point 8) : à citer seulement avec cette
précision. Presidio, spaCy et EDS-Pseudo n'ont pas de reconnaisseur
français pour SIREN, SIRET ou TVA : ce que leur ligne `siren` couvre vient
de prédictions d'un **autre type** (la règle de score ne regarde pas le
type) ; elle n'est pas interprétée.

| Type annoté | Écluse, document par document | Écluse, session de dossier | Presidio par défaut | Presidio en français | spaCy fr_core_news_lg seul | EDS-Pseudo (règles) |
|---|---:|---:|---:|---:|---:|---:|
| adresse | 50/50 (100 %) | 50/50 (100 %) | 0/50 (0 %) | 0/50 (0 %) | 0/50 (0 %) | 0/50 (0 %) |
| date_naissance | 50/50 (100 %) | 50/50 (100 %) | 41/50 (82 %) | 31/50 (62 %) | 0/50 (0 %) | 50/50 (100 %) |
| email | 22/22 (100 %) | 22/22 (100 %) | 22/22 (100 %) | 22/22 (100 %) | 4/22 (18 %) | 22/22 (100 %) |
| etablissement | 50/50 (100 %) | 50/50 (100 %) | 4/50 (8 %) | 28/50 (56 %) | 28/50 (56 %) | 0/50 (0 %) |
| finess | 6/6 (100 %) | 6/6 (100 %) | 0/6 (0 %) | 0/6 (0 %) | 0/6 (0 %) | 0/6 (0 %) |
| iban | 15/15 (100 %) | 15/15 (100 %) | 9/15 (60 %) | 8/15 (53 %) | 7/15 (47 %) | 0/15 (0 %) |
| nir | 10/10 (100 %) | 10/10 (100 %) | 1/10 (10 %) | 0/10 (0 %) | 0/10 (0 %) | 7/10 (70 %) |
| nom | 127/127 (100 %) | 127/127 (100 %) | 81/127 (64 %) | 127/127 (100 %) | 127/127 (100 %) | 78/127 (61 %) |
| rpps | 6/6 (100 %) | 6/6 (100 %) | 3/6 (50 %) | 3/6 (50 %) | 0/6 (0 %) | 3/6 (50 %) |
| telephone | 40/40 (100 %) | 40/40 (100 %) | 39/40 (98 %) | 39/40 (98 %) | 0/40 (0 %) | 40/40 (100 %) |
| **Toutes entités** | **376/376 (100 %)** | **376/376 (100 %)** | **200/376 (53 %)** | **258/376 (69 %)** | **166/376 (44 %)** | **200/376 (53 %)** |
| Documents sans entité masqués à tort | 5/19 (26 %) | 5/19 (26 %) | 17/19 (89 %) | 9/19 (47 %) | 5/19 (26 %) | 2/19 (11 %) |

Identifiants d'entreprise (type annoté `siren`), ligne à part, sur les prédictions brutes :

| | Écluse, document par document | Écluse, session de dossier | Presidio par défaut | Presidio en français | spaCy fr_core_news_lg seul | EDS-Pseudo (règles) |
|---|---:|---:|---:|---:|---:|---:|
| `siren` entièrement couvert | 7/7 (100 %) | 7/7 (100 %) | 6/7 (86 %) | 2/7 (29 %) | 0/7 (0 %) | 0/7 (0 %) |

Mentions d'Écluse (document par document) sur les documents sans entité annotée, par source et par type prédit : v3 : identifiant 1, nom 3, telephone 1.

Règle de score : voir l'en-tête de `bench/comparatif.py`. Entité couverte =
tous ses caractères non blancs sont sous une prédiction, quel que soit le
type prédit ; civilité retirée des noms ; masquages à tort comptés sur les
documents sans entité.

## Ce que ce comparatif ne dit pas

- **Les corpus sont produits par le projet** : ses détecteurs ont été écrits en
  regardant ces gabarits. Un outil qui n'a jamais vu ces gabarits part avec un
  handicap que ce comparatif ne chiffre pas ; sur des textes réels les écarts
  seraient différents, dans un sens ou dans l'autre. Aucun document réel n'est
  ici (règle 1 de `CLAUDE.md`).
- **Petit échantillon** : environ 150 documents tirés avec une seule graine (42).
  Aucun intervalle de confiance, aucune répétition avec d'autres graines.
- **La règle de score favorise la couverture** : une entité est « couverte » quel
  que soit le type prédit, et une prédiction large compte comme une couverture
  entière. Un outil qui masque tout le texte aurait 100 % de couverture ; c'est la
  ligne « masqués à tort » qui le retient, et elle ne compte que les documents
  **sans** entité annotée.
- **« Masqués à tort » n'est pas toujours une erreur** : le corpus v3 n'annote que
  les identifiants (structurels et d'entreprise), alors que ses phrases contiennent aussi des noms,
  des téléphones et des numéros de dossier non annotés ; un outil qui les masque y
  est compté « à tort » à cause de l'annotation, pas du texte. Les types prédits
  par Écluse sur ces documents sont donnés sous le tableau ; les autres outils
  n'ont pas été décomposés.
- **« Masqués à tort » compte les documents, pas les caractères** : un document
  sans entité qui porte une prédiction sur un mot courant compte autant qu'un
  document entièrement masqué.
- **Presidio** est lancé tel que ses reconnaisseurs prédéfinis le permettent
  (seuil de score 0,35, comme `bench/run_presidio.py`), **sans** reconnaisseurs NIR
  ou RPPS français : voir `bench/README.md` pour le comparatif dédié aux
  identifiants. « En français » veut dire : modèle spaCy `fr_core_news_lg` et
  reconnaisseurs prédéfinis chargés pour la langue `fr` ; rien de plus n'a été
  réglé.
- **spaCy seul** est un modèle d'entités nommées, pas un outil de
  pseudonymisation : il ne cherche ni e-mail, ni téléphone, ni identifiant. Ces
  lignes sont à lire comme « ce qu'il ne fait pas », pas comme un défaut.
- **EDS-Pseudo** : seules les règles sont mesurées (`simple_rules`, `addresses`,
  `dates`), **pas** le modèle appris du même projet, qui n'a pas été lancé ; le
  paquet `eds-pseudo` n'est pas sur PyPI, il est installé depuis son dépôt
  GitHub (commit noté plus haut).
- **Outils non mesurés** : tout ce qui n'est pas listé (autres pipelines de
  pseudonymisation, services en ligne, modèles de langue généralistes).
- **Écluse en session** n'a de sens que pour les documents de dossiers
  (clé `dossier`) ; les autres documents y sont passés un par un, comme en
  « document par document ».
- **Chemin mesuré** : `Ecluse.redact` (ce que reçoit le LLM) pour Écluse ; pour
  les autres outils, la détection de l'outil : aucun n'est branché à un LLM ici.
- Les chiffres de ce fichier sont la source des parties 2 et 3 de l'article
  de benchmark (relu le 22 novembre 2026) ; ils ne sont pas repris dans
  `bench/README.md`. Toute citation renvoie à ce fichier et au commit indiqué
  plus haut.


## Annotation complémentaire des données personnelles non annotées (P2-247)

Mêmes prédictions que ci-dessus, **deux annotations** : celle du corpus, et celle du
corpus plus une annotation propre au comparatif (`annote_complement` dans
`bench/comparatif.py` ; ni `generate_corpus.py` ni les corpus ne sont touchés).

**Règle d'annotation.** Noms : suite « Prénom Nom » dont le prénom et le nom
sont dans `PRENOMS` et `NOMS` de `generate_corpus.py`, civilité exclue.
Téléphones : numéro français à dix chiffres groupés par deux (`0X`, ou `+33 X`).
Numéros de dossier : le nombre qui suit « dossier n° ». Un ajout qui recouvre une
entité déjà annotée est ignoré. **Non annotés** : les numéros de praticien
inconnus (RPPS à Luhn cassé). SIREN, SIRET et TVA sont annotés `siren` par le
corpus lui-même depuis le 23/11/2026 (P2-261), l'IBAN à clé invalide `iban`
depuis le 22/11/2026, le NIR à clé invalide `nir` depuis le 23/11/2026.

Entités ajoutées (source, type : nombre) : v3 dossier : 1, v3 nom : 19, v3 telephone : 1. Documents sans entité : 7 après annotation.

Ancienne et nouvelle lignes, côte à côte :

| | Écluse, document par document | Écluse, session de dossier | Presidio par défaut | Presidio en français | spaCy fr_core_news_lg seul | EDS-Pseudo (règles) |
|---|---:|---:|---:|---:|---:|---:|
| Couverture, annotation du corpus | 383/383 (100 %) | 383/383 (100 %) | 206/383 (54 %) | 260/383 (68 %) | 166/383 (43 %) | 200/383 (52 %) |
| Couverture, avec annotation complémentaire | 404/404 (100 %) | 404/404 (100 %) | 218/404 (54 %) | 280/404 (69 %) | 185/404 (46 %) | 206/404 (51 %) |
| Sans entité masqués à tort, annotation du corpus | 5/12 (42 %) | 5/12 (42 %) | 11/12 (92 %) | 7/12 (58 %) | 5/12 (42 %) | 2/12 (17 %) |
| Sans entité masqués à tort, avec annotation complémentaire | 0/7 (0 %) | 0/7 (0 %) | 7/7 (100 %) | 2/7 (29 %) | 1/7 (14 %) | 1/7 (14 %) |

Détail par type avec annotation complémentaire :

| Type annoté | Écluse, document par document | Écluse, session de dossier | Presidio par défaut | Presidio en français | spaCy fr_core_news_lg seul | EDS-Pseudo (règles) |
|---|---:|---:|---:|---:|---:|---:|
| adresse | 50/50 (100 %) | 50/50 (100 %) | 0/50 (0 %) | 0/50 (0 %) | 0/50 (0 %) | 0/50 (0 %) |
| date_naissance | 50/50 (100 %) | 50/50 (100 %) | 41/50 (82 %) | 31/50 (62 %) | 0/50 (0 %) | 50/50 (100 %) |
| dossier | 1/1 (100 %) | 1/1 (100 %) | 0/1 (0 %) | 0/1 (0 %) | 0/1 (0 %) | 0/1 (0 %) |
| email | 22/22 (100 %) | 22/22 (100 %) | 22/22 (100 %) | 22/22 (100 %) | 4/22 (18 %) | 22/22 (100 %) |
| etablissement | 50/50 (100 %) | 50/50 (100 %) | 4/50 (8 %) | 28/50 (56 %) | 28/50 (56 %) | 0/50 (0 %) |
| finess | 6/6 (100 %) | 6/6 (100 %) | 0/6 (0 %) | 0/6 (0 %) | 0/6 (0 %) | 0/6 (0 %) |
| iban | 15/15 (100 %) | 15/15 (100 %) | 9/15 (60 %) | 8/15 (53 %) | 7/15 (47 %) | 0/15 (0 %) |
| nir | 10/10 (100 %) | 10/10 (100 %) | 1/10 (10 %) | 0/10 (0 %) | 0/10 (0 %) | 7/10 (70 %) |
| nom | 146/146 (100 %) | 146/146 (100 %) | 92/146 (63 %) | 146/146 (100 %) | 146/146 (100 %) | 83/146 (57 %) |
| rpps | 6/6 (100 %) | 6/6 (100 %) | 3/6 (50 %) | 3/6 (50 %) | 0/6 (0 %) | 3/6 (50 %) |
| siren | 7/7 (100 %) | 7/7 (100 %) | 6/7 (86 %) | 2/7 (29 %) | 0/7 (0 %) | 0/7 (0 %) |
| telephone | 41/41 (100 %) | 41/41 (100 %) | 40/41 (98 %) | 40/41 (98 %) | 0/41 (0 %) | 41/41 (100 %) |
| **Toutes entités** | **404/404 (100 %)** | **404/404 (100 %)** | **218/404 (54 %)** | **280/404 (69 %)** | **185/404 (46 %)** | **206/404 (51 %)** |
| Documents sans entité masqués à tort | 0/7 (0 %) | 0/7 (0 %) | 7/7 (100 %) | 2/7 (29 %) | 1/7 (14 %) | 1/7 (14 %) |

Limites : la règle ne voit que les personnes posées par les listes du générateur, les téléphones et dossiers de format régulier ; une donnée personnelle d'une autre forme (dans les dossiers ou le flou) resterait non annotée. Le chemin mesuré est inchangé : `Ecluse.redact` pour Écluse, la détection propre de chaque outil pour les autres.

## Témoin sans aucune donnée personnelle (P2-246)

480 documents synthétiques du soin et du social, **sans aucune donnée personnelle** (générés par `bench/generate_corpus_temoin_sans_pii.py`, graine 42) : consignes de service, comptes rendus sans nom, protocoles, plannings de salles, notes logistiques, courriers types. Toute prédiction y est un masquage en trop ; aucune correction n'est faite ici.

Chemin mesuré : `Ecluse.redact` (ce que reçoit le LLM) pour les deux colonnes Écluse ; la détection propre de chaque outil pour les autres.

| | Écluse, document par document | Écluse, session de dossier | Presidio par défaut | Presidio en français | spaCy fr_core_news_lg seul | EDS-Pseudo (règles) |
|---|---:|---:|---:|---:|---:|---:|
| Documents masqués à tort | 16/480 (3 %) | 16/480 (3 %) | 447/480 (93 %) | 456/480 (95 %) | 480/480 (100 %) | 257/480 (54 %) |
| Caractères (hors blancs) masqués à tort | 253/141910 (0 %) | 253/141910 (0 %) | 9459/141910 (7 %) | 11521/141910 (8 %) | 24311/141910 (17 %) | 2471/141910 (2 %) |
| type prédit `DATE` (documents / caractères) | — | — | — | — | — | 257/2469 |
| type prédit `DATE_TIME` (documents / caractères) | — | — | 80/579 | — | — | — |
| type prédit `LOC` (documents / caractères) | — | — | — | — | 348/4754 | — |
| type prédit `LOCATION` (documents / caractères) | — | — | 242/1972 | 348/4754 | — | — |
| type prédit `MISC` (documents / caractères) | — | — | — | — | 420/12806 | — |
| type prédit `NDA` (documents / caractères) | — | — | — | — | — | 1/2 |
| type prédit `NRP` (documents / caractères) | — | — | 5/20 | — | — | — |
| type prédit `ORG` (documents / caractères) | — | — | — | — | 291/2871 | — |
| type prédit `ORGANIZATION` (documents / caractères) | — | — | — | 291/2871 | — | — |
| type prédit `PER` (documents / caractères) | — | — | — | — | 242/3880 | — |
| type prédit `PERSON` (documents / caractères) | — | — | 361/6888 | 242/3880 | — | — |
| type prédit `PHONE_NUMBER` (documents / caractères) | — | — | 3/16 | 3/16 | — | — |
| type prédit `etablissement` (documents / caractères) | 16/253 | 16/253 | — | — | — | — |

Écluse (document par document), documents masqués à tort par famille : compte_rendu 7/80 ; consigne_service 0/80 ; courrier_type 0/80 ; note_logistique 9/80 ; planning_salles 0/80 ; protocole 0/80.

Familles de masquage à tort d'Écluse sur le témoin (type `etablissement` seul, 16 documents sur 480, 253 caractères ; exemples synthétiques, aucune correction) :

1. **Sigle ou type d'établissement suivi de « à » et d'une ville**, 8 documents, tous des comptes rendus : « Prévoir un point d'étape avec CHU à Lille. » masque « CHU à Lille » (idem « SSIAD à Tours », « EHPAD à Nantes »). Le texte désigne un type de structure générique et une ville, pas une structure identifiable ; Écluse y lit une tournure d'établissement.
2. **Dénomination de service en majuscules de titre** après un titre de note, 8 documents, toutes des notes logistiques : « Note Logistique La Résidence Autonomie. » masque « Résidence Autonomie » (idem « Foyer D'accueil Médicalisé »). La casse de titre fait lire un nom propre d'établissement ; la même dénomination en casse ordinaire (« la résidence autonomie ») n'est pas masquée dans ce témoin.

Aucun masquage à tort d'Écluse dans les quatre autres familles (consignes de service, courriers types, protocoles, plannings de salles) ni sur les numéros de salle, pages, articles de loi, codes de protocole, marques ou villes seules.

Limite propre à ce témoin : il est produit par le projet, à partir de pools de mots limités (une quinzaine de villes, une dizaine de sigles) ; l'absence d'autres familles chez Écluse ne dit rien des tournures que ce générateur ne tire pas. Les autres outils produisent des types différents (`PERSON`, `LOC`, `MISC`…) sur des mots de ces mêmes phrases ; leurs masquages n'ont pas été décomposés famille par famille.
