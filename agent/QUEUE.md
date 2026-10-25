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
| P1-01 | mesure | Rejouer Presidio sur le corpus v3 et mettre à jour le tableau du benchmark | — | fusionnée |
| P1-02 | code | RPPS : couvrir les variantes de séparateurs (NBSP, espace fine, tabulation, espaces multiples, points, tirets) | — | fusionnée |
| P1-03 | mesure | FINESS : analyser les faux positifs (collision SIREN) et proposer des pistes chiffrées | P1-01 | fusionnée |
| P1-04 | code | Téléphone FR : durcir l'heuristique (formats +33, 0033, séparateurs) | — | fusionnée |
| P1-05 | code | Email : durcir l'heuristique (obfuscations courantes, bornes de span) | — | fusionnée |
| P1-06 | spec | Détecteur ADELI : structure officielle, validation possible, risque de faux positifs | — | fusionnée |
| P1-07 | spec | Secret scanning (clés d'API, jetons) : périmètre, motifs, place dans le pipeline | — | fusionnée |
| P1-08 | spec | `ecluse_audit` v0 : journal chaîné horodaté sans donnée personnelle | — | fusionnée |
| P1-09 | spec | Ingestion PDF texte + garde-fou PDF-image : choix de la bibliothèque, critères de refus | — | fusionnée |
| P1-10 | humain | Valider les specs P1-06 à P1-09 et créer les tâches `code` correspondantes | P1-06, P1-07, P1-08, P1-09 | humain |
| P1-11 | code | Brouillon d'article de benchmark (`bench/ARTICLE.md`) à partir des résultats à jour | P1-01, P1-03 | fusionnée |
| P1-12 | humain | Relire et publier l'article de benchmark | P1-11 | humain |
| P1-13 | code | Corpus : SIREN sans mot-clé, phrases FINESS + SIREN, ADELI avec/sans mot-clé (nouvelle version du générateur) | P1-03 | fusionnée |
| P1-14 | code | Détecteur ADELI contextuel + `EntityType.adeli` + priorité sur `finess` | P1-13 | fusionnée |
| P1-15 | code | Détecteur de secrets (`EntityType.secret`) | P1-13 | PR ouverte |
| P1-16 | code | `ecluse_audit` v0 (entrée, chaîne, vérificateur, sink en mémoire) | P1-08 | à faire |
| P1-17 | code | Ingestion PDF : `PdfTextSource`, garde-fou et refus | P1-18 | à faire |
| P1-18 | code | Générateur de PDF synthétiques pour calibrer les seuils | P1-09 | à faire |
| P1-19 | code | Core : un identifiant suivi d'un nombre (`NIR … 91 12 ans`, `RPPS … 12`) n'est plus détecté (fuite) | — | fusionnée |
| P1-20 | code | Redact : une adresse, un nom ou un établissement en chevauchement partiel écrase l'entité voisine (email cassé, nom en clair) | — | fusionnée |
| P1-21 | code | Redact : collision avec des jetons littéraux du texte (`[NOM_1]`) | — | fusionnée |
| P1-22 | code | Ingest : contenus non lus en silence (préfixe XML autre que `w:`, en-têtes/pieds, UTF-16 sans BOM, exceptions non rattrapées) | — | fusionnée |
| P1-23 | code | Robustesse : ReDoS email et adresse ; démo (taille de corps, JSON non-objet, `Host`/`Origin`, masquage de la consigne) | — | fusionnée |
| P1-24 | code | Redact : noms (prénoms accentués, particules, `Mr`, `Maître`, apostrophe typographique) | — | fusionnée |
| P1-25 | code | Redact : variantes de dates, établissements, adresses et téléphones non détectées | — | fusionnée |
| P1-26 | code | Redact : fusion de deux personnes de même patronyme à la restauration ; carte vs `LIMITES.md` §5.3 | — | fusionnée |
| P1-27 | code | Reid/reference : paliers d'âge, population des départements, normalisation œ, homonymes, validations | — | fusionnée |
| P1-28 | code | Bench : `score.py` (types inconnus, mode souple), `ecluse_sim.py`, README, test d'équivalence | — | fusionnée |
| P1-29 | code | Docs : `LIMITES.md`, `ROADMAP.md`, README du benchmark, `NOTES_SECURITE.md` manquant | — | fusionnée |
| P1-30 | code | Core : NIR à mois fictifs, séparateurs U+2009 et `/`, saut de ligne dans un identifiant groupé | — | fusionnée |
| P1-31 | code | Reid : un nom de commune ambigu (homonymes) est signalé, jamais « faible » | — | fusionnée |
| P1-32 | code | Core : NIR à mois `00` et `21-29` (test d'abord, clé mod 97 exigée) | — | fusionnée |
| P1-33 | code | `DATA_SOURCES.md` : URL, date et licence (lue sur la page) de chaque jeu de données embarqué | — | à faire |
| P1-34 | code | README du benchmark : résultats des entités floues dans un tableau séparé | — | fusionnée |
| P1-35 | mesure | Presidio avec reconnaisseurs NIR/RPPS écrits à la main (objection prévisible à l'article) | P1-01 | à faire |

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

### P1-13 — Corpus enrichi FINESS / SIREN / ADELI (`code`)

Contexte : `agent/specs/P1-03-finess.md` §4 et `agent/specs/P1-06-adeli.md` §5.
La mesure FINESS est circulaire (un seul gabarit SIREN).

- Étendre `bench/generate_corpus.py` : SIREN sans le mot « SIREN » (RCS,
  TVA, Kbis), phrases contenant à la fois FINESS et SIREN, ADELI avec et
  sans mot-clé. Identifiants générés par `luhn_digit`, jamais copiés.
- Ne pas corriger le détecteur : **mesurer** l'état actuel sur le nouveau
  corpus et mettre à jour `bench/README.md` (version de corpus, chiffres).
- **Fini quand** : corpus reproductible (seed 42), chiffres avant correction
  dans la PR, aucune baisse sur NIR/RPPS/IBAN.

### P1-14 — Détecteur ADELI (`code`)

Spec : `agent/specs/P1-06-adeli.md`, décisions de `DECISIONS.md` (2026-10,
« Réponses du mainteneur »). Débloquée. Ajoute `EntityType.adeli`. Clé =
Luhn sur les 9 caractères (algorithme non fourni par les sources : le dire
dans le code). **Numéro corse (`2A`/`2B`) : aucune validation de clé** ; masqué
sans validation quand le mot « ADELI » est accolé. Exception à « Détection
stricte » (confiance 0,6, clé invalide) **uniquement avec le mot « ADELI »
accolé**. Mesurer avant/après sur `--profile extended` (FINESS ne doit pas
régresser).

### P1-15 — Détecteur de secrets (`code`)

Spec : `agent/specs/P1-07-secrets.md`. Débloquée. Fournisseurs de la v1 :
jetons GitHub, identifiants d'accès AWS (préfixés), clés OpenAI et Anthropic,
clés Google (`AIza…`), jetons Slack, clés Stripe live, blocs PEM, chaînes de
connexion avec mot de passe. **Citer la source de chaque format** (les
préfixes ne sont pas vérifiés du jour). Motifs réécrits par nous (gitleaks :
licence MIT d'après des sources secondaires, fichier `LICENSE` non lu), valeurs
de test fabriquées à l'exécution, **pas** de détection par entropie ni de
clé AWS secrète nue.

### P1-16 — `ecluse_audit` v0 (`code`)

Spec : `agent/specs/P1-08-audit.md`. Débloquée. **Dépendance approuvée** :
`package:crypto` (BSD-3-Clause), uniquement dans le nouveau paquet
`ecluse_audit`. Pas d'empreinte du texte en v0 ; horodatage à la minute.

### P1-17 — Ingestion PDF (`code`)

Spec : `agent/specs/P1-09-pdf.md`. Débloquée une fois P1-18 fusionnée.
**Dépendance approuvée** : `pdf_graphics`, version fixée exactement (dans
`ecluse_ingest` seulement). Dépendances de `bidi` non auditées : le signaler.
Plafonds de départ à calibrer sur les PDF de P1-18 : 50 Mo, 200 pages,
30 secondes, refus avec motif au-delà.

### P1-18 — PDF synthétiques (`code`)

Spec : `agent/specs/P1-09-pdf.md` §6. Script qui **génère** des PDF de test
(texte, scan, mixte, chiffré, illisible, tronqué) sans bibliothèque ajoutée
sans accord. Si la génération exige une dépendance, s'arrêter et le signaler.
**Fini quand** : jeu de PDF reproductible et attendus documentés.

### P1-19 à P1-30 — Corrections issues de la relecture du code (octobre 2026)

Source : relecture en lecture seule de tous les paquets (rapport de session du
25 oct. 2026). Chaque tâche suit la règle n°5 : **un test ou un cas de corpus
qui montre le défaut d'abord**, puis la correction, puis la mesure
avant/après. Les défauts ci-dessous ont été reproduits par exécution.

- **P1-19** — `NIR 1 85 05 78 006 084 91 12 ans`, `RPPS 10001234565 12`,
  `Dossier 12 1 85 05 78 006 084 91` : 0 détection (la normalisation colle
  le nombre voisin). Idem IBAN ; FINESS à vérifier.
- **P1-20** — `12 rue des Lilas, 75015 Paris et jean.dupont@example.fr` donne
  `[ADRESSE_1].dupont@example.fr` ; `M. Marc Herbin Foyer Les Tilleuls` laisse
  le nom en clair. Cause : motif de commune insensible à la casse + résolution
  qui supprime tout le perdant d'un chevauchement partiel.
- **P1-21** — `Voir [NOM_1] et M. Jean Dupont.` se restaure en
  `Voir Jean Dupont …`. Attendu : refus avec motif ou numérotation qui évite
  les jetons déjà présents.
- **P1-22** — docx avec préfixe `ns0:` : texte vide sans avertissement ;
  en-têtes/pieds/notes/commentaires ignorés sans signal ; UTF-16 sans BOM
  accepté ; `&#x110000;` fait planter l'appelant. Règle n°4.
- **P1-23** — motif email : 16 000 « a » = 5,5 s ; motif adresse : 16 Ko
  répétés = 5,8 s à 22 s. Démo : pas de limite de taille, JSON non-objet = 500,
  `instruction` envoyée sans masquage, pas de contrôle `Host`/`Origin`.
- **P1-24 à P1-26** — détails dans les cas reproduits du rapport (prénoms
  accentués, particules multiples, `1er`, `Né le :`, CHU, formats de
  téléphone, `12 bis rue`, fusion `Mme Dupont` / `M. Jean Dupont`).
- **P1-27** — palier 65-69 ans → `0-64` ; Paris/Lyon/Marseille/Mayotte à
  population 0 ; communes en « œ » introuvables ; homonymes ignorés ;
  validations manquantes.
- **P1-28** — `score.py` ignore les types non listés et compte 1 caractère
  de recouvrement comme succès (mode souple) ; `ecluse_sim.py` diverge du
  moteur Dart sur un document ; README du benchmark périmé.
- **P1-29** — `LIMITES.md` et `ROADMAP.md` en retard (odt, INS, `ecluse_reid`,
  mois fictifs du NIR, IBAN FR seul) ; `NOTES_SECURITE.md` cité mais absent.
- **P1-30** — NIR à clé valide avec mois 30/42/50/99 non détecté ; U+2009, `/`
  et saut de ligne non gérés.

### P1-31 à P1-35 — Suites des réponses du mainteneur (octobre 2026)

- **P1-31** — `extractQis` ignore un nom de commune ambigu (« Saint-Denis »,
  ~3 700 communes concernées) et `estimate` retombe sur la France entière
  (F = 69 M, « faible »). L'API doit signaler l'ambiguïté ; cas le plus
  prudent = plus petite population parmi les candidates, ou « indéterminé ».
  Changement d'API autorisé par le mainteneur. Test d'abord.
- **P1-32** — `00` et `21-29` (mois inconnus selon la nomenclature DGFiP citée
  dans `DECISIONS.md`) ; la clé mod 97 reste exigée ; 13-19 et 43-49 restent
  rejetés. Test d'abord, mesure avant/après sur le benchmark.
- **P1-33** — Pour chaque fichier de `packages/ecluse_reference/assets/` :
  URL du jeu sur data.gouv.fr ou site source, date de téléchargement,
  licence **lue sur la page**. Si une page est inaccessible ou si le fichier
  ne correspond à aucune source identifiable, s'arrêter et le signaler (ne
  rien inventer).
- **P1-34** — Tableau séparé (réaliste / adversarial / témoin, strict, souple,
  fuite) avec les commandes de reproduction du profil `generate_corpus_flou.py`
  et les mises en garde (corpus synthétique, civilité conservée par choix).
- **P1-35** — `bench/run_presidio.py` avec deux reconnaisseurs personnalisés
  (NIR, RPPS) écrits à la main, **sans nouvelle dépendance** ; rapporter
  précision/rappel avant/après ; ne rien corriger côté Écluse.
