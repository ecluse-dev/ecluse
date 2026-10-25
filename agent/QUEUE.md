# File de travail des agents — Écluse

Fichier tenu par le mainteneur. Un agent ne modifie que la colonne
**Statut** de la tâche qu'il traite (règles complètes dans `CLAUDE.md`).

**Statuts** : `à faire` · `PR ouverte` · `fusionnée` · `bloquée` · `humain`
(réservée au mainteneur, un agent ne la prend jamais).

**Types** : `code` (implémentation + tests) · `spec` (conception seule,
dans `agent/specs/<id>.md`, aucun code de production) · `mesure` (exécuter
et rapporter, ne rien corriger).

L'ordre des lignes est l'ordre de priorité. L'agent prend la première
tâche `à faire` dont toutes les dépendances sont `fusionnée`.

## Phase 1 — Le sas minimal vendable

| Id | Type | Tâche | Dépend de | Statut |
|---|---|---|---|---|
| P1-00 | humain | Pousser les tests produits par l'essai d'agent du 10 août (branche locale `test-prime-agent`) | — | humain |
| P1-01 | mesure | Rejouer Presidio sur le corpus v3 et mettre à jour le tableau du benchmark | — | PR ouverte |
| P1-02 | code | RPPS : couvrir les variantes de séparateurs (NBSP, espace fine, tabulation, espaces multiples, points, tirets) | — | à faire |
| P1-03 | mesure | FINESS : analyser les faux positifs (collision SIREN) et proposer des pistes chiffrées | P1-01 | à faire |
| P1-04 | code | Téléphone FR : durcir l'heuristique (formats +33, 0033, séparateurs) | — | à faire |
| P1-05 | code | Email : durcir l'heuristique (obfuscations courantes, bornes de span) | — | à faire |
| P1-06 | spec | Détecteur ADELI : structure officielle, validation possible, risque de faux positifs | — | à faire |
| P1-07 | spec | Secret scanning (clés d'API, jetons) : périmètre, motifs, place dans le pipeline | — | à faire |
| P1-08 | spec | `ecluse_audit` v0 : journal chaîné horodaté sans donnée personnelle | — | à faire |
| P1-09 | spec | Ingestion PDF texte + garde-fou PDF-image : choix de la bibliothèque, critères de refus | — | à faire |
| P1-10 | humain | Valider les specs P1-06 à P1-09 et créer les tâches `code` correspondantes | P1-06, P1-07, P1-08, P1-09 | humain |
| P1-11 | code | Brouillon d'article de benchmark (`bench/ARTICLE.md`) à partir des résultats à jour | P1-01, P1-03 | à faire |
| P1-12 | humain | Relire et publier l'article de benchmark | P1-11 | humain |

Les phases 2 et 3 seront découpées ici quand la phase 1 sera fusionnée.

---

## Fiches détaillées

### P1-01 — Rejouer Presidio sur le corpus v3 (`mesure`)

Contexte : `bench/README.md` signale que les chiffres Presidio datent du
corpus v1 et n'ont pas été rejoués.

- Générer le corpus v3 (`--n 1000 --seed 42`), exécuter
  `bench/run_presidio.py` en configuration par défaut (modèle
  `en_core_web_lg`), puis `bench/score.py`.
- Si le modèle spaCy ne peut pas être téléchargé, utiliser `--blank` et le
  dire explicitement dans la PR et dans la note du tableau.
- Mettre à jour le tableau et la note ¹ de `bench/README.md`. Ne toucher à
  aucun code de détection.
- **Fini quand** : le tableau ne contient plus de chiffre Presidio issu du
  corpus v1, et la commande exacte pour les reproduire est écrite.

### P1-02 — RPPS et séparateurs (`code`)

Contexte : un essai du 10 août a montré que 6 variantes de normalisation
sur 8 n'étaient pas reconnues pour le RPPS. `RppsDetector._candidate`
n'accepte qu'une espace simple entre chiffres.

- D'abord un test qui échoue, couvrant au moins : NBSP (U+00A0), espace
  fine insécable (U+202F), tabulation, espaces multiples, point, tiret.
- Vérifier ce que fait déjà `digit_compaction` / `NormalizedText` dans
  `EcluseEngine` avant de modifier le détecteur : la correction va au bon
  étage, pas en double.
- Garder l'exclusion des RPPS enchâssés dans une forme d'IBAN.
- **Fini quand** : les variantes sont détectées avec les bons offsets dans
  le texte d'origine, et la précision RPPS du benchmark ne baisse pas
  (chiffres avant/après dans la PR).

### P1-03 — FINESS et collision SIREN (`mesure`)

Contexte : précision FINESS à 75,4 % dans `bench/README.md`.

- Classer les faux positifs du corpus par cause (SIREN, SIRET tronqué,
  autre nombre de 9 chiffres valide par coïncidence…).
- Pour chaque piste de correction (contexte lexical, préfixe
  départemental, liste de catégories…), estimer le gain de précision et la
  perte de rappel attendue sur le corpus.
- **Fini quand** : un rapport `agent/specs/P1-03-finess.md` chiffré est en
  PR. Aucune modification du détecteur.

### P1-04 — Téléphone FR (`code`)

- Fichier : `packages/ecluse_redact/lib/src/heuristics/telephone_detector.dart`.
- Couvrir : `+33 6…`, `+33 (0)6…`, `0033 6…`, séparateurs espace, point,
  tiret, NBSP, et numéros courts à exclure (15, 112, 3114…).
- Tests avec offsets exacts et cas de rejet (dates, montants, codes
  postaux).
- **Fini quand** : tests verts, aucun nouveau faux positif sur le corpus
  adversarial négatif s'il est présent dans `bench/`.

### P1-05 — Email (`code`)

- Fichier : `packages/ecluse_redact/lib/src/heuristics/email_detector.dart`.
- Couvrir : sous-adressage (`+tag`), sous-domaines, TLD longs, ponctuation
  collée en fin de phrase (ne pas l'inclure dans le span), majuscules.
- Les obfuscations (`[at]`, `(arobase)`) : les détecter si c'est sans
  risque de faux positif, sinon les documenter dans `LIMITES.md`.
- **Fini quand** : tests verts, spans exacts, limites restantes écrites.

### P1-06 — ADELI (`spec`)

- Établir, sources officielles à l'appui (liens dans la spec), la structure
  du numéro ADELI et s'il existe une clé de contrôle.
- Sans clé, proposer une détection contextuelle (mots déclencheurs) et
  estimer le risque de faux positifs face aux autres nombres à 9 chiffres
  (FINESS, SIREN).
- Si une information ne peut pas être vérifiée, l'écrire comme telle.
- **Fini quand** : `agent/specs/P1-06-adeli.md` en PR.

### P1-07 — Secret scanning (`spec`)

- Recenser les formats de secrets à couvrir en priorité (clés d'API des
  principaux fournisseurs de LLM et de cloud, jetons GitHub, clés privées
  PEM, chaînes de connexion), avec la source de chaque format.
- Proposer : nouveau type d'entité ou catégorie à part, place dans
  `EcluseEngine`, comportement attendu (masquer, refuser l'envoi, ou les
  deux).
- **Fini quand** : `agent/specs/P1-07-secrets.md` en PR.

### P1-08 — `ecluse_audit` v0 (`spec`)

Contrainte forte : l'exemption HDS repose sur le fait qu'Écluse ne stocke
rien. Le journal ne doit contenir **aucune donnée personnelle ni valeur
détectée**.

- Proposer le format d'entrée (horodatage, empreinte du texte, nombre
  d'entités par type, version du moteur, chaînage par hash de l'entrée
  précédente), le stockage (à la charge de l'application cliente) et la
  vérification d'intégrité.
- Lister ce que le journal ne contient jamais.
- **Fini quand** : `agent/specs/P1-08-audit.md` en PR.

### P1-09 — PDF texte (`spec`)

- Comparer les bibliothèques Dart capables d'extraire le texte d'un PDF
  avec offsets : licence (compatible Apache 2.0), Dart pur ou natif,
  maintenance, taille.
- Définir le garde-fou PDF-image : seuils (couche texte vide ou quasi
  vide, ratio pages sans texte), message de refus, cas des PDF mixtes.
- **Fini quand** : `agent/specs/P1-09-pdf.md` en PR, avec une
  recommandation et ses risques.

### P1-11 — Brouillon d'article (`code`)

- Écrire `bench/ARTICLE.md` à partir des seuls chiffres présents dans
  `bench/README.md` après P1-01 et P1-03.
- Ton factuel, limites incluses (corpus synthétique, collisions FINESS).
  Aucun nom de prospect ni d'établissement.
- **Fini quand** : brouillon en PR, chaque chiffre renvoie à une commande
  reproductible.
