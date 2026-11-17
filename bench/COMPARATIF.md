# Comparatif d'outils (P2-224)

Mesure seule, produite par `bench/comparatif.py`. Elle ne tourne pas dans
`bench/etat.sh`. Aucun chiffre n'est repris dans le README ni dans
l'article.

## Commande exacte

```
python3 bench/comparatif.py --md bench/COMPARATIF.md
```

Environnement : `pip install -r bench/requirements-comparatif.txt` puis
`python3 -m spacy download fr_core_news_lg en_core_web_lg`, et
`pip install git+https://github.com/aphp/eds-pseudo.git` (voir ce fichier).
Les corpus sont ceux que `bench/etat.sh` génère (graine 42) ; `dart` doit
être dans le `PATH`.

## Versions

| Composant | Version |
|---|---|
| Écluse (commit du dépôt) | d88c8b0 |
| Dart | Dart SDK version: 3.14.1 (stable) (Tue Nov 17 00:01:24 2026 -0800) on "linux_x64" |
| Python | 3.13.18 |
| presidio-analyzer | 2.2.366 |
| spacy | 3.8.18 |
| fr_core_news_lg | 3.8.0 |
| en_core_web_lg | 3.8.0 |
| edsnlp | 0.24.0 |
| eds-pseudo (installé depuis GitHub) | 0.4.0, commit 844a6cbb3280 |

## Échantillon

148 documents (graine 42) : 48 dossiers, 50 flou, 50 v3 ; dont 24 sans entité annotée.

## Résultats : entités entièrement couvertes, par outil et par type

| Type annoté | Écluse, document par document | Écluse, session de dossier | Presidio par défaut | Presidio en français | spaCy fr_core_news_lg seul | EDS-Pseudo (règles) |
|---|---:|---:|---:|---:|---:|---:|
| adresse | 50/50 (100 %) | 50/50 (100 %) | 0/50 (0 %) | 0/50 (0 %) | 0/50 (0 %) | 0/50 (0 %) |
| date_naissance | 50/50 (100 %) | 50/50 (100 %) | 41/50 (82 %) | 31/50 (62 %) | 0/50 (0 %) | 50/50 (100 %) |
| email | 22/22 (100 %) | 22/22 (100 %) | 22/22 (100 %) | 22/22 (100 %) | 4/22 (18 %) | 22/22 (100 %) |
| etablissement | 50/50 (100 %) | 50/50 (100 %) | 4/50 (8 %) | 28/50 (56 %) | 28/50 (56 %) | 0/50 (0 %) |
| finess | 6/6 (100 %) | 6/6 (100 %) | 0/6 (0 %) | 0/6 (0 %) | 0/6 (0 %) | 0/6 (0 %) |
| iban | 10/10 (100 %) | 10/10 (100 %) | 8/10 (80 %) | 8/10 (80 %) | 5/10 (50 %) | 0/10 (0 %) |
| nir | 10/10 (100 %) | 10/10 (100 %) | 1/10 (10 %) | 0/10 (0 %) | 0/10 (0 %) | 7/10 (70 %) |
| nom | 112/127 (88 %) | 127/127 (100 %) | 81/127 (64 %) | 127/127 (100 %) | 127/127 (100 %) | 78/127 (61 %) |
| rpps | 6/6 (100 %) | 6/6 (100 %) | 3/6 (50 %) | 3/6 (50 %) | 0/6 (0 %) | 3/6 (50 %) |
| telephone | 40/40 (100 %) | 40/40 (100 %) | 39/40 (98 %) | 39/40 (98 %) | 0/40 (0 %) | 40/40 (100 %) |
| **Toutes entités** | **356/371 (96 %)** | **371/371 (100 %)** | **199/371 (54 %)** | **258/371 (70 %)** | **164/371 (44 %)** | **200/371 (54 %)** |
| Documents sans entité masqués à tort | 11/24 (46 %) | 11/24 (46 %) | 21/24 (88 %) | 12/24 (50 %) | 10/24 (42 %) | 2/24 (8 %) |

Mentions d'Écluse (document par document) sur les documents sans entité annotée, par source et par type prédit : v3 : finess 3, iban 3, identifiant 1, nom 3, telephone 1.

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
  les identifiants structurels, alors que ses phrases contiennent aussi des noms,
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
- Aucun chiffre de ce fichier n'est repris dans le `README.md` ni dans
  l'article : ce comparatif est une mesure interne, à relire avant toute
  citation.

