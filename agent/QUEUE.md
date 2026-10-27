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
| P1-10 | humain | Valider les specs P1-06 à P1-09 et créer les tâches `code` correspondantes | P1-06, P1-07, P1-08, P1-09 | fusionnée |
| P1-11 | code | Brouillon d'article de benchmark (`bench/ARTICLE.md`) à partir des résultats à jour | P1-01, P1-03 | fusionnée |
| P1-12 | humain | Relire et publier l'article de benchmark | P1-11 | humain |
| P1-13 | code | Corpus : SIREN sans mot-clé, phrases FINESS + SIREN, ADELI avec/sans mot-clé (nouvelle version du générateur) | P1-03 | fusionnée |
| P1-14 | code | Détecteur ADELI contextuel + `EntityType.adeli` + priorité sur `finess` | P1-13 | fusionnée |
| P1-15 | code | Détecteur de secrets (`EntityType.secret`) | P1-13 | fusionnée |
| P1-16 | code | `ecluse_audit` v0 (entrée, chaîne, vérificateur, sink en mémoire) | P1-08 | fusionnée |
| P1-17 | code | Ingestion PDF : `PdfTextSource`, garde-fou et refus | P1-18 | fusionnée |
| P1-18 | code | Générateur de PDF synthétiques pour calibrer les seuils | P1-09 | fusionnée |
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
| P1-33 | code | `DATA_SOURCES.md` : URL, date et licence (lue sur la page) de chaque jeu de données embarqué | — | fusionnée |
| P1-34 | code | README du benchmark : résultats des entités floues dans un tableau séparé | — | fusionnée |
| P1-35 | mesure | Presidio avec reconnaisseurs NIR/RPPS écrits à la main (objection prévisible à l'article) | P1-01 | fusionnée |

## Phase 2 — La profondeur qui rend seul

Découpage proposé dans `agent/specs/P2-decoupage-propose.md` ; seules les
tâches copiées ici sont prises par l'agent.

| Id | Type | Tâche | Dépend de | Statut |
|---|---|---|---|---|
| P2-01 | spec | Critère GO/STOP du NER local (métriques, corpus de décision, plafonds, conditions d'arrêt) | — | fusionnée |
| P2-02 | mesure | Référence chiffrée des heuristiques de noms et d'adresses sur les corpus flous (valeur à battre pour le GO/STOP du NER) | P2-01 | fusionnée |
| P2-03 | spec | Branchement de `ecluse_reid` dans `Ecluse.redact` : contrat public, généralisation irréversible distincte de la pseudonymisation, refus explicites | — | fusionnée |
| P2-03a | code | Profil de corpus de quasi-identifiants annotés (profession, lieu, âge) et son scoreur, dans `bench/` | P2-03 | fusionnée |
| P2-03b | code | `ecluse_reid` : extraction des QI avec positions et estimation totale (résultat typé, sans exception), en ajout et sans changer `estimate` | P2-03a | fusionnée |
| P2-04 | code | Branchement de `ecluse_reid` dans `Ecluse.redact` selon l'option retenue dans la spec P2-03 (test d'équivalence d'abord, mesure avant/après) | P2-03, P2-03a, P2-03b | fusionnée |
| P2-05 | spec | Pseudonymes cohérents entre les documents d'un dossier et cloisonnés entre dossiers : définition du dossier, état en mémoire, menace du recoupement | — | fusionnée |
| P2-05a | code | Profil de corpus multi-documents (dossiers, personnes, identités) et son scoreur, avec la mesure de l'état actuel sans dossier | P2-05 | fusionnée |
| P2-06 | code | État de dossier en mémoire dans `ecluse_redact` : pseudonymes cohérents entre les documents d'un dossier et cloisonnés entre dossiers, selon les décisions de la spec P2-05 (test d'équivalence d'abord, mesure avant/après) | P2-05, P2-05a | fusionnée |
| P2-07 | spec | Généralisation multi-dimensions (date de naissance vers tranche d'âge, âge vers palier, pathologie rare vers catégorie) : dimensions, table de catégories, honnêteté sur ce qui reste ré-identifiable | P2-03 | fusionnée |
| P2-08 | spec | Aperçu avec validation en un clic, option et non défaut (entretien #2) : contrat du composant, sans interface autonome | — | fusionnée |
| P2-09 | spec | Export AIPD : champs du registre pré-rempli, données d'`ecluse_audit` qui y entrent et qui n'y entrent pas | — | fusionnée |
| P2-10 | spec | Transcription vocale locale : choix Vosk ou whisper.cpp, preuve qu'aucun son ne sort de l'appareil, limite sur les chiffres, critère GO/STOP propre | — | bloquée |
| P2-11 | code | `ecluse_bench` : retirer `pubspec_overrides.yaml` (chemin Windows) du suivi git | — | fusionnée |
| P2-12 | code | Script reproductible du décompte de la fuite des noms hors civilité, versionné dans `bench/` | P2-02 | fusionnée |
| P2-13 | code | `Dossier` : règle de noms entre documents activable (N3) : N1 par défaut, fusion par inclusion (N2) à la demande de l'application | P2-06 | fusionnée |
| P2-14 | code | Patronyme seul : mesurer ce qu'un rattrapage sans liste externe ni NER peut détecter, et ne l'implémenter que si le budget de faux positifs est tenu | P2-05a | fusionnée |
| P2-15 | code | `ecluse_audit` : agrégat d'export pour le registre et l'AIPD (période, comptes par type avec seuil, refus par code, versions, état de la chaîne), en lecture seule | P2-09 | fusionnée |
| P2-16 | code | `ecluse_redact` : scinder détection et application de `Ecluse.redact` (test d'équivalence d'abord), préalable de l'aperçu | P2-08 | fusionnée |
| P2-17 | code | `ecluse_reid` : échelle de dates de naissance et dérivation d'âge avec date de référence injectée, palier 85+, en ajout | P2-07 | fusionnée |
| P2-18 | code | `ecluse_redact` : composant d'aperçu avec validation (proposition, refus, ajouts manuels, application), sans interface | P2-16 | fusionnée |
| P2-19 | code | `ecluse_redact` : une proposition d'aperçu périmée (dossier modifié depuis) ou appliquée à un autre dossier est refusée | P2-18 | fusionnée |
| P2-20 | code | `ecluse_redact` : les blancs en bordure d'un ajout manuel d'aperçu ne sont pas masqués | P2-19 | fusionnée |
| P2-21 | code | `ecluse_redact` : un ajout manuel d'aperçu dont une borne coupe une paire de substituts UTF-16 est refusé | P2-20 | fusionnée |
| P2-22 | code | `ecluse_redact` : marquer la provenance « manuelle » des entités ajoutées dans un aperçu (`RedactResult.manuelles`) | P2-21 | fusionnée |
| P2-23 | code | `ecluse_redact` : rapport de risque de l'aperçu avant application (`Apercu.risque`, `Proposition.risque`), sans effet de bord | P2-22 | fusionnée |
| P2-24 | code | `ecluse_ingest` : test de composition fichier → aperçu sur le texte extrait (décision 10 de P2-08) | P2-23 | fusionnée |
| P2-25 | code | `ecluse_redact` : recherche des jetons littéraux sans compiler un motif par jeton et par appel (coût d'un gros dossier) | P2-24 | fusionnée |
| P2-26 | code | `ecluse_audit` : l'export ne laisse plus retrouver un compte masqué par soustraction ni par le nombre d'entrées de la chaîne | P2-25 | fusionnée |
| P2-27 | code | `ecluse_ingest` : refuser un .docx/.odt dont le contenu ne correspond plus au CRC-32 de l'archive | P2-26 | fusionnée |
| P2-28 | code | `ecluse_ingest` : refuser un PDF qui a plus d'objets page en clair que de pages atteignables (page perdue sans avertissement) | P2-27 | fusionnée |
| P2-29 | code | `ecluse_redact` : détecter les identifiants contenant des caractères invisibles ou des tirets et espaces typographiques, sans réécrire le texte | P2-28 | fusionnée |
| P2-30 | code | `ecluse_redact` : ramener les formes pleine chasse, chiffres arabes orientaux et barres de fraction à l'ASCII dans la vue des détecteurs | P2-29 | fusionnée |
| P2-31 | code | `ecluse_redact` : restaurer un jeton échappé en Markdown (`\\[NOM\\_1\\]`) sans jamais approcher le numéro | P2-30 | fusionnée |
| P2-32 | code | `ecluse_redact` : détecter en entier un nom aux accents décomposés (NFD), sans laisser le reste du nom en clair | P2-31 | fusionnée |
| P2-33 | code | `ecluse_redact` : masquer en entier un nom contenant des majuscules ou lettres hors du jeu français (Á, Ñ, Œ, Ł, Ş, Ž, vietnamien…) | P2-32 | fusionnée |
| P2-34 | code | `ecluse_redact` : détecter une date de naissance aux séparateurs espacés (« 12 / 03 / 1950 », « 12 03 1950 ») | P2-33 | fusionnée |
| P2-35 | code | `ecluse_redact` : reconnaître les civilités abrégées avec point (« Mme. », « Mlle. ») | P2-34 | fusionnée |
| P2-36 | code | `ecluse_redact` : masquer le patronyme derrière une étiquette de champ (« Nom de naissance : », « Nom : … Prénom : … ») | P2-35 | fusionnée |
| P2-37 | code | `ecluse_redact` : masquer en entier une adresse dont le numéro de voie porte une lettre (« 12 B rue des Lilas ») | P2-36 | fusionnée |
| P2-38 | code | `ecluse_redact` : détecter un identifiant à chiffres (NIR, IBAN, téléphone, date) coupé par une fin de ligne entre deux groupes | P2-37 | fusionnée |
| P2-39 | code | `ecluse_redact` : détecter une date de naissance séparée de son étiquette (`\|`, `;`, saut de ligne) | P2-38 | fusionnée |
| P2-40 | code | `ecluse_redact` : masquer le prénom derrière « Prénom : » et reconnaître la fiche « Prénom » avant « Nom » | P2-39 | fusionnée |
| P2-41 | code | `ecluse_redact` : masquer le nom derrière « Nom du patient : », « Nom de l'assuré : »… | P2-40 | fusionnée |
| P2-42 | code | `ecluse_redact` : détecter un NIR dont la clé est nommée à part (« 2550814168025 clé 38 ») | P2-41 | fusionnée |
| P2-43 | code | `ecluse_redact` : reconnaître les variantes de contexte et d'écriture d'une date de naissance (département, abréviations, jour de semaine, mois anglais) | P2-42 | fusionnée |
| P2-44 | code | `ecluse_redact` : détecter « (+33) » et les indicatifs d'outre-mer (+262, +590, +594, +596) ; documenter l'exclusion des numéros étrangers | P2-43 | fusionnée |
| P2-45 | code | `ecluse_redact` : masquer le nom de naissance ou d'épouse derrière « née », « épouse », « veuve », « nom de jeune fille » | P2-44 | fusionnée |
| P2-46 | code | `ecluse_redact` : reconnaître « Professeure », « Docteure », « Dre », « Ms », « Mgr », « Abbé » comme civilités | P2-45 | fusionnée |
| P2-47 | code | `ecluse_redact` : reconnaître les particules da, dos, di, del, ben, bin, bint, ibn, ter, ten, zu, af dans un nom | P2-46 | fusionnée |
| P2-48 | code | `ecluse_redact` : supprimer le coût quadratique de la détection de noms sur un texte à milliers de mentions | P2-47 | fusionnée |
| P2-49 | code | `ecluse_redact` : reconnaître les types de voie « sentier », « ruelle », « clos »… et les abréviations « R. », « pl. », « ch. » | P2-48 | fusionnée |
| P2-50 | code | `ecluse_redact` : borner la recherche de la fiche « Prénom » pour supprimer un coût quadratique sur « Nom : » répété | P2-49 | fusionnée |
| P2-51 | code | `ecluse_redact` : détecter les valeurs derrière des étiquettes décorées en Markdown ou HTML (« **Nom :** », « <b>Né le</b> ») | P2-50 | fusionnée |
| P2-52 | code | `ecluse_redact` : détecter une date de naissance derrière une clé de données (`date_naissance`, `dateNaissance`, `dob`, `ddn`…) | P2-51 | fusionnée |
| P2-53 | code | `ecluse_redact` : détecter le nom d'un correspondant dans un en-tête de courriel (`De :`, `From:`, `… a écrit`) | P2-52 | PR ouverte |

La phase 3 sera découpée ici quand la phase 2 sera fusionnée.

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

### P2-01 — Critère GO/STOP du NER local (`spec`)

Contexte : `CLAUDE.md` règle 7 interdit de fusionner le NER ONNX sans un
critère GO/STOP validé par le mainteneur ; ce critère n'est écrit nulle part.
`packages/ecluse_ner` est aujourd'hui un stub sans dépendance native.

- Définir les métriques de décision pour les noms et les adresses : rappel,
  précision et budget de faux positifs, en modes strict et souple du
  benchmark (`bench/score.py`), sur un corpus de décision nommé.
- Définir les plafonds non fonctionnels : taille du modèle, latence, mémoire,
  absence de dépendance native non maîtrisée, licence du modèle et du runtime.
- Écrire les conditions d'arrêt (STOP) explicites et ce qui se passe quand le
  gain de rappel est insuffisant ou que le budget de faux positifs est dépassé.
- Aucune ligne de code de production et aucune dépendance ajoutée. Toute
  valeur chiffrée sans source est marquée « proposée, non mesurée » ; les
  licences non lues sont signalées comme telles.
- **Fini quand** : `agent/specs/P2-01.md` en PR, avec les décisions que le
  mainteneur doit trancher listées en fin de document.

### P2-02 — Référence des heuristiques de noms et d'adresses (`mesure`)

Contexte : `agent/specs/P2-01.md` § 4 compare le NER à la **référence rejouée**
des heuristiques actuelles (`NameDetector`, `AdresseDetector`), pas aux valeurs
publiées dans `bench/README.md`, qui peuvent être périmées.

- Générer les trois corpus flous (`bench/generate_corpus_flou.py`, `--n 400`,
  seed 42) et exécuter `Ecluse.redact` complet puis `bench/score_flou.py`,
  avec les commandes de la section « Entités floues » de `bench/README.md`.
- Rapporter, par corpus (réaliste, adversarial, témoin) et par type (nom,
  adresse, et global) : rappel strict, F1 souple et **fuite au caractère** ;
  pour le témoin, le nombre de documents avec une détection ; pour les trois
  corpus, le nombre de documents à restauration non identique. Ce sont les
  mesures nommées aux conditions A à D de P2-01.
- Rejouer aussi les identifiants à clé sur le corpus v3 (`bench/score.py`,
  `--n 1000 --seed 42`) : référence de la condition B.
- Rejouer une seconde fois avec une autre graine (par exemple 7) pour donner
  le corpus de **calibration** de P2-01 § 4.C, et indiquer l'écart entre les
  deux graines.
- Comparer aux valeurs publiées dans `bench/README.md` et signaler tout écart.
  Ne modifier aucune ligne de détection, aucun générateur ni aucun scoreur.
- **Fini quand** : un rapport `agent/specs/P2-02-reference.md` en PR, avec les
  commandes exactes, les versions d'outils et les chiffres ; les écarts avec le
  README, s'il y en a, sont listés ; si une commande ne peut pas s'exécuter
  (Dart ou Python manquant), la PR le dit et s'arrête au lieu d'estimer.

### P2-03 — Branchement de `ecluse_reid` dans `Ecluse.redact` (`spec`)

Contexte : `ecluse_reid` (estimation de F, bande de risque, généralisation
suggérée) est une bibliothèque seule, **non utilisée** par `Ecluse.redact`
(`LIMITES.md` §§ 6 et 7). Elle « estime et informe ; ne masque rien et ne
décide rien seul » (`packages/ecluse_reid/lib/ecluse_reid.dart`). Aujourd'hui
`ecluse_redact` ne dépend ni d'`ecluse_reid` ni d'`ecluse_reference`.

- Écrire la spec du branchement. **Le contrat public n'est pas tranché** : la
  spec compare au moins deux options — (a) un **rapport de risque seul**, qui
  ne change pas le texte envoyé au LLM ; (b) une **généralisation appliquée**
  au texte, irréversible, distincte de la pseudonymisation — avec leurs coûts
  (utilité du texte, restauration, offsets, tests), donne une recommandation
  motivée et **laisse le choix au mainteneur** en fin de document. Ne pas
  trancher à sa place.
- Traiter explicitement : l'API publique et le type de retour ; comment les
  offsets et la traçabilité restent des invariants si le texte est modifié ;
  le fait qu'une généralisation ne se restaure pas ; le contrat d'honnêteté
  d'`ecluse_reid` (`honestyContract`), qui doit figurer dans chaque sortie ;
  les communes homonymes (jamais « faible », voir `DECISIONS.md`).
- **Refus explicite plutôt qu'échec silencieux** (règle 4) : Paris, Lyon,
  Marseille (agrégés) et Mayotte sont aujourd'hui refusés par une exception
  (`ArgumentError`, `LIMITES.md` § 7). Dire ce que le branchement en fait
  (refus motivé dans le résultat, jamais « rien à signaler »).
- Lever la tension avec `CONCEPTION_BOUCLE.md`, qui place la boucle « après le
  NER » avec des QI « repérés par le NER », alors que `qi_extraction.dart` les
  extrait de façon déterministe sans NER : préciser ce que le branchement
  couvre sans NER et ce qu'il laisse à P2-01/NER.
- Nommer les dépendances internes à ajouter (`ecluse_reid`, `ecluse_reference`
  dans `ecluse_redact`) et vérifier qu'`ecluse_core` reste pur (règle 6). Aucune
  dépendance pub ou pip.
- Prévoir la mesure avant/après (règle 5) : quels cas de corpus montrent le
  défaut visé, quelle fuite ou quel sur-masquage est attendu, avec quelles
  commandes du benchmark ; toute valeur sans source est « proposée, non
  mesurée ».
- Aucune ligne de code de production.
- **Fini quand** : `agent/specs/P2-03.md` en PR, avec les décisions du
  mainteneur listées en fin de document (au minimum le choix entre les
  options a et b).

### P2-04 — Implémentation du branchement de `ecluse_reid` (`code`)

**Débloquée** (25 octobre 2026) : les décisions de la spec sont écrites dans
`DECISIONS.md` (rubrique « Préconisations … validées par délégation »), choix
de l'agent et révocables ; les préalables ci-dessous restent à vérifier.

Préalables :

- Les décisions du § 8 de `agent/specs/P2-03.md` sont écrites dans
  `DECISIONS.md`, au minimum : le choix de l'option (A rapport seul, B
  généralisation appliquée, ou A puis B), l'activation (désactivée par défaut ou
  non), la politique pour les documents de plusieurs personnes, l'acceptation des
  dépendances internes `ecluse_reid` et `ecluse_reference` dans `ecluse_redact`.
- P2-03a et P2-03b sont fusionnées : un profil de corpus de quasi-identifiants
  annotés avec son scoreur, puis `ecluse_reid` avec extraction **positionnée** et
  estimation **totale** (résultat typé, statut « aucun QI détecté » distinct de
  « risque faible »).

Travail :

- Écrire **d'abord** le test d'équivalence : sans activation, la sortie d'
  `Ecluse.redact` est octet pour octet celle d'avant. Puis les tests du nouveau
  comportement, qui échouent avant le code (règle 5).
- Implémenter l'option retenue, avec le contrat de résultat du § 6 de la spec
  (statuts explicites, motifs lisibles pour *non évaluable*, avertissements de
  commune ambiguë, notes d'honnêteté). Jamais d'exception qui fasse échouer la
  pseudonymisation pour un problème d'estimation ; jamais « rien à signaler » sur
  un contenu non évalué (règle 4).
- Si l'option B est retenue : table de décalage des offsets, généralisation
  irréversible hors de `mapping`, comportement de `Ecluse.restore` décrit et testé.
- `ecluse_core` reste inchangé (règle 6). Aucune dépendance pub ou pip : seuls les
  paquets du monorepo sont ajoutés comme dépendances.
- Mesurer avant/après avec les commandes de la spec (§ 7) et rapporter les
  chiffres dans la PR ; vérifier que les mesures de P2-02 sont inchangées (fuite
  globale 7,5 % réaliste, 16,8 % adversarial, 59 restaurations non identiques).
- Mettre à jour `LIMITES.md` §§ 3, 6 et 7 : un lieu isolé n'est plus « en clair sans
  traitement » si l'option le couvre, avec les limites restantes.
- **Fini quand** : `format`, `analyze` et `test` passent, les mesures sont dans la
  PR, et la PR liste ce que le mainteneur doit vérifier.

### P2-03a — Profil de corpus de quasi-identifiants et scoreur (`code`)

Contexte : `agent/specs/P2-03.md` § 7 : aucun corpus ne mesure ce que `ecluse_reid`
extrait. Cette tâche ne touche à aucun détecteur ; elle fournit l'outil de mesure
(règle 5) avant toute correction. Indépendante des décisions du § 8 de la spec.

- Créer `bench/generate_corpus_qi.py`, déterministe (`--n`, `--seed`,
  `--out-dir`), même format JSONL que `bench/generate_corpus_flou.py`
  (`id`, `text`, `entities` avec `type`, `start`, `end`), offsets enregistrés à
  l'insertion et jamais retrouvés par recherche. Peut importer le constructeur
  de documents du générateur existant **sans le modifier**.
- Types annotés : `profession`, `lieu`, `age` (ceux de `QiType`), sur le
  fragment de texte qui porte l'information. Champ supplémentaire par document :
  `personnes` (nombre de personnes évoquées).
- Trois corpus séparés, jamais fusionnés : *réaliste* (compte rendu plausible, une
  personne, les trois types), *adversarial* (communes homonymes, Paris/Lyon/
  Marseille et Mayotte, plusieurs lieux, plusieurs âges, profession sans lieu,
  âges aux bornes, accents, tirets, articles, documents de plusieurs personnes),
  *témoin* (aucun QI rattaché à une personne : durées « depuis 3 ans », quantités,
  mots communs qui coïncident avec un nom de commune).
- Écrire `bench/score_qi.py` : rappel et précision stricts et souples par type,
  fuite au caractère des QI laissés en clair, et taux de documents par statut si
  les prédictions en portent un. Peut s'inspirer de `bench/score_flou.py` sans le
  modifier.
- Tests (`python3 -m unittest discover -s bench`) : reproductibilité par graine,
  offsets exacts (`text[start:end]` égal à la mention), absence de toute donnée
  réelle (règle 1 : personnes et textes synthétiques, seuls les noms de communes
  publiques sont réels), scoreur sur prédictions parfaites et vides.
- Documenter dans `bench/README.md` une section « Quasi-identifiants » avec les
  commandes de reproduction ; ne modifier aucun tableau de résultats existant.
- **Fini quand** : les tests Python passent, la PR donne le nombre d'entités par
  type et par corpus, et liste ce que le mainteneur doit vérifier.

### P2-03b — `ecluse_reid` : extraction positionnée et estimation totale (`code`)

Contexte : `agent/specs/P2-03.md` § 4 (obstacles 1 à 3). Tâche **additive** : les
fonctions existantes (`extractQis`, `extractQisDetailed`, `estimate`, `ReidLoop`)
gardent leur signature et leur comportement, y compris les `ArgumentError`
attendus par leurs tests. Aucun autre paquet n'appelle ces fonctions
aujourd'hui.

- **Test d'abord** (règle 5) : mesurer l'état actuel sur les corpus de P2-03a avec
  un petit programme dans `packages/ecluse_reid/bin/` qui charge
  `EcluseReference` (`ecluse_reference`, chargeur `fileAssets`, avec
  `assetsDir: '../ecluse_reference/assets'` depuis le répertoire du paquet) et rapporte
  le nombre et la part de documents sur lesquels la chaîne actuelle
  `extractQis` puis `estimate` lève une exception, par cause. Ce chiffre est le
  « avant ».
- Ajouter une extraction qui renvoie, pour chaque QI, ses positions `[start, end)`
  dans le texte d'origine, avec les avertissements de commune ambiguë existants.
- Ajouter une estimation **totale** : elle ne lève jamais pour une entrée de
  l'utilisateur et renvoie un résultat typé avec un statut explicite : évalué,
  *aucun QI détecté* (jamais présenté comme un risque faible), ou *non évaluable*
  avec un **motif lisible** : deux lieux, deux âges, profession sans lieu, code de
  profession inconnu, commune inconnue ou sans population (Paris, Lyon, Marseille
  agrégés, Mayotte), niveau de lieu non calculable.
- Commune ambiguë : jamais « faible » (`DECISIONS.md`) ; cas le plus prudent ou
  *indéterminé*. Contrat d'honnêteté (`honestyContract`) dans toute sortie.
- Mesurer l'« après » avec `bench/score_qi.py` : rappel et précision d'extraction
  par type, taux de documents par statut, **zéro exception** sur tous les corpus.
- Ne modifier ni `ecluse_redact`, ni `Ecluse.redact`, ni `ecluse_core` (c'est
  l'objet de P2-04). Aucune dépendance pub ou pip.
- **Fini quand** : `format`, `analyze` et `test` passent, les tests écrits avant le
  code sont dans la PR, le « avant » et l'« après » sont chiffrés, et la PR liste ce
  que le mainteneur doit vérifier.

### P2-05 — Pseudonymes cohérents par dossier et cloisonnés entre dossiers (`spec`)

Contexte : `ROADMAP.md` (phase 2) : « même entité → même jeton au sein d'un
dossier (le LLM garde le fil), jeton différent d'un dossier à l'autre (aucun
recoupement possible entre dossiers) ». Aujourd'hui, `Ecluse.redact`
(`packages/ecluse_redact/lib/src/ecluse.dart`) numérote les jetons et résout les
identités de nom **à l'intérieur d'un seul appel** : deux appels repartent de
`[NOM_1]`. La carte `mapping` « ne quitte jamais le processus local »
(`redact_result.dart`). La fusion de mentions partielles est le « seul cas connu »
de restauration non octet pour octet (`LIMITES.md` § 5.3).

- Écrire la spec. **Le périmètre d'un « dossier » n'est pas défini** : comparer au
  moins deux définitions (par exemple une conversation à plusieurs tours, un lot de
  fichiers importés avec `ecluse_ingest`, une notion fournie par l'application
  cliente), avec qui crée le dossier, sa durée de vie et ce qui l'arrête. Ne pas
  trancher : laisser le choix au mainteneur en fin de document.
- Décrire la mécanique d'un état conservé **en mémoire** entre appels (jetons
  déjà attribués, identités de noms, compteurs) : où il vit, comment l'application
  le crée et le détruit, ce qui se passe à la restauration d'une réponse, et
  pourquoi il n'est jamais sérialisé, journalisé ni écrit sur disque.
- Analyser le **risque de fausses fusions** quand la règle de rapprochement des
  noms (inclusion des segments, civilité) s'applique entre documents : des
  homonymes de documents différents, un patronyme répandu. Dire ce qui est
  acceptable et ce qui ne l'est pas, et l'effet sur la fidélité de la restauration
  (`LIMITES.md` § 5.3).
- Écrire la **menace** que le cloisonnement doit contrer : qui pourrait recouper
  quoi, avec quelles informations (le fournisseur du LLM voyant plusieurs dossiers ?
  d'autres ?). Des jetons séquentiels (`[NOM_1]`) peuvent-ils se corréler d'un
  dossier à l'autre (même ordre d'apparition) ? Comparer des options de
  cloisonnement et leur coût (lisibilité pour le LLM, tolérance de `restore`,
  collision avec le texte), et dire ce que le cloisonnement ne protège **pas**.
- Traiter la collision avec les jetons littéraux du texte (`_freshToken`) quand
  l'état est partagé entre plusieurs textes.
- Invariants à tenir : sans dossier, sortie **identique** à celle d'aujourd'hui
  (test d'équivalence à prévoir) ; règle 3 ; règle 4 (un dossier mal fermé ou une
  carte perdue se signale, jamais en silence).
- Prévoir la mesure avant/après (règle 5) : quels corpus (mêmes personnes dans
  plusieurs documents, homonymes, plusieurs dossiers), quelles mesures (même
  personne → même jeton, fausses fusions, restaurations non identiques) et quelles
  commandes du benchmark ; toute valeur sans source est « proposée, non mesurée ».
- Aucune ligne de code de production, aucune dépendance. Proposer les tâches
  `code` qui en découleraient, sans les copier dans `agent/QUEUE.md`.
- **Fini quand** : `agent/specs/P2-05.md` en PR, avec les décisions du mainteneur
  listées en fin de document (au minimum : la définition du dossier et l'option de
  cloisonnement).

### P2-06 — État de dossier en mémoire dans `ecluse_redact` (`code`)

**Débloquée** (25 octobre 2026) : les décisions de la spec sont écrites dans
`DECISIONS.md` (rubrique « Préconisations … validées par délégation »), choix
de l'agent et révocables ; les préalables ci-dessous restent à vérifier.

Contexte : `agent/specs/P2-05.md`. Aujourd'hui `Ecluse.redact` numérote les jetons
et résout les identités de noms à l'intérieur d'un seul appel ; deux appels
repartent de `[NOM_1]`. La spec a établi par exécution que la même personne reçoit
deux jetons, que deux personnes reçoivent le même jeton, et qu'une réponse restaurée
avec la mauvaise carte remplace une personne par une autre sans signal.

Préalables :

- Les décisions du § 10 de `agent/specs/P2-05.md` sont écrites dans
  `DECISIONS.md`, au minimum : la définition du dossier, ce que devient l'état à la
  perte ou au redémarrage, la règle de noms entre documents (N1, N2 ou N3), la menace
  à contrer et l'option de cloisonnement (C0, C1 ou C2), la forme de l'API, le
  traitement d'un jeton littéral dans un texte ultérieur et la concurrence.
- P2-05a est fusionnée : le profil de corpus multi-documents annoté, son scoreur et
  la mesure de l'état actuel sans dossier (le « avant », règle 5).

Travail :

- Écrire **d'abord** le test d'équivalence : sans dossier, la sortie d'
  `Ecluse.redact` est octet pour octet celle d'avant. Puis les tests du nouveau
  comportement, qui échouent avant le code : même personne dans deux documents, même
  jeton ; deux personnes, deux jetons ; restauration d'une réponse qui cite un jeton
  d'un message précédent.
- Implémenter l'état de dossier selon les décisions prises, en mémoire uniquement :
  jamais sérialisé, journalisé ni écrit, sans représentation textuelle qui expose la
  carte ; fermeture explicite qui l'efface ; un dossier fermé ou perdu **se signale**
  au lieu de renvoyer des jetons sans correspondance (règle 4). Aucune valeur ni aucun
  jeton ne va dans `ecluse_audit`.
- Appliquer la règle de noms entre documents et l'option de cloisonnement retenues.
  Gérer la collision avec un jeton littéral d'un texte ultérieur comme décidé, et la
  concurrence sur un même dossier.
- `ecluse_core` reste inchangé (règle 6). Aucune dépendance pub ou pip.
- Mesurer avant/après avec le corpus du préalable : cohérence (même personne, même
  jeton), collisions, fausses fusions, restaurations non identiques. Vérifier que les
  mesures de P2-02 sont inchangées sans dossier (fuite globale 7,5 % réaliste, 16,8 %
  adversarial, 59 restaurations non identiques).
- Mettre à jour `LIMITES.md` § 5.3 : cohérence entre documents, risque de fausses
  fusions et effet sur la restauration.
- **Fini quand** : `format`, `analyze` et `test` passent, les mesures sont dans la
  PR, et la PR liste ce que le mainteneur doit vérifier.

### P2-05a — Profil de corpus multi-documents et scoreur (`code`)

Contexte : `agent/specs/P2-05.md` § 8 et § 9. Aucun corpus ne contient plusieurs
documents qui parlent des mêmes personnes, donc la cohérence des pseudonymes entre
documents ne se mesure pas. Cette tâche ne touche à aucun détecteur ni à
`Ecluse.redact` : elle fournit l'outil de mesure (règle 5) et chiffre l'état actuel.
Indépendante des décisions du § 10 de la spec : la vérité terrain se construit par
génération, quelle que soit la définition retenue du dossier.

- Créer `bench/generate_corpus_dossiers.py`, déterministe (`--n`, `--seed`,
  `--out-dir`), même format JSONL que `bench/generate_corpus_flou.py` avec, par
  document, un champ `dossier` (entier) et `rang` (position dans le dossier), et, par
  entité, un champ `identite` (entier, unique **par personne ou par valeur**, commun à
  tous les dossiers pour pouvoir mesurer le recoupement). Types annotés : `nom`,
  `email`, `telephone`. Offsets enregistrés à l'insertion, jamais retrouvés par
  recherche. Peut importer le constructeur de documents du générateur existant **sans
  le modifier**.
- Trois corpus séparés, jamais fusionnés : *réaliste* (3 à 6 documents par dossier, une
  poignée de personnes, mentions complètes puis partielles), *adversarial* (même
  personne citée dans des ordres différents, deux personnes en première position, deux
  homonymes de même sexe et un couple, patronymes répandus, mention partielle
  ambiguë marquée `ambigue`, e-mail et téléphone répétés d'un document à l'autre,
  jeton littéral du type `[NOM_1]` dans un texte ultérieur, mêmes personnes dans
  plusieurs dossiers), *témoin* (plusieurs dossiers **sans aucune personne en
  commun**, pour vérifier qu'aucun jeton n'est partagé à tort).
- Personnes, textes, e-mails et téléphones **synthétiques** (règle 1) : prénoms et
  patronymes pris dans les listes de `generate_corpus_flou.py`, adresses en
  `example.fr`, téléphones des plages réservées à la fiction.
- Écrire `bench/score_dossiers.py` : à partir des prédictions (un jeton par mention,
  voir ci-dessous), rapporter pour chaque corpus : **cohérence** (part des identités
  qui reçoivent un seul jeton dans un dossier), **collisions** (jetons qui désignent
  plusieurs identités dans un dossier), **fausses fusions**, **restaurations non
  identiques**, et, pour les identités présentes dans deux dossiers, la part qui reçoit
  **le même jeton dans les deux** (signal de corrélation structurelle, à interpréter
  seulement une fois la menace de la spec confirmée). Les mentions `ambigue` sont
  comptées à part, jamais dans les taux.
- Format des prédictions : une ligne par document, `{"id", "mentions": [{"type",
  "start", "end", "jeton"}], "restaure": bool}`, où `restaure` dit si le texte masqué
  puis restauré redonne le texte d'origine octet pour octet.
- Ajouter `packages/ecluse_redact/bin/run_dossiers_bench.dart` (sur le modèle de
  `run_redact_bench.dart`) qui masque **chaque document séparément** avec l'
  `Ecluse.redact` actuel (aucun état partagé), restaure le texte masqué avec la carte
  de ce même appel, et écrit les prédictions. Aucune modification de `lib/`.
- Tests : `python3 -m unittest discover -s bench` (reproductibilité par graine,
  offsets exacts, identités cohérentes par construction, absence de données réelles,
  scoreur sur prédictions parfaites, vides et en collision) ; `format`, `analyze` et
  `test` Dart pour le paquet touché.
- Documenter dans `bench/README.md` une section « Dossiers » (conventions, commandes
  de reproduction, limites) ; ne modifier aucun tableau de résultats existant. Les
  fichiers générés ne sont pas versionnés (`.gitignore`).
- **Fini quand** : les tests passent, la PR chiffre l'état actuel (cohérence,
  collisions, fausses fusions, restaurations non identiques, recoupement) sur les trois
  corpus et deux graines, dit ce qui n'est pas mesuré, et liste ce que le mainteneur
  doit vérifier.

### P2-07 — Généralisation multi-dimensions (`spec`)

**Débloquée par le mainteneur le 26 octobre 2026.** Les décisions de
`agent/specs/P2-03.md` § 8 sont dans `DECISIONS.md`. **Le choix de la source de la
table de catégories de pathologies n'est pas fait** (aucune table n'existe dans le
dépôt) : il fait partie du travail, sans être tranché par l'agent. Si aucune source
exploitable n'est trouvée, la spec le dit et traite les deux autres dimensions
(date de naissance, âge) sans table de pathologies.

Travail : écrire `agent/specs/P2-07.md`, **aucune ligne de code**. Lister les
dimensions généralisables (date de naissance vers tranche d'âge, âge vers palier,
pathologie rare vers catégorie), les sources candidates pour la table de catégories
avec leur licence **lue sur la page** (URL et date de lecture ; ne rien affirmer si
la page est inaccessible), l'effet sur l'estimation de `ecluse_reid`, et **ce qui reste
ré-identifiable** après généralisation. La généralisation est irréversible : elle
ne se déclenche que sur demande de l'appelant (spec P2-03). Ne pas trancher les
choix produit : les poser au mainteneur en fin de document.

### P2-08 — Aperçu avec validation en un clic (`spec`)

**Débloquée par le mainteneur le 26 octobre 2026** (l'ordre des tâches de la
phase 2 dépendait des signaux des design partners, `ROADMAP.md`). Aucun autre
préalable.

Travail : écrire `agent/specs/P2-08.md`, **aucune ligne de code**. Contrat d'un
composant d'aperçu, **option** et non défaut (entretien #2) : ce qu'il reçoit de
`Ecluse.redact` (texte masqué, entités, avertissements), ce qu'il renvoie
(entités acceptées, refusées, ajoutées à la main), comment un refus ou un ajout
reste cohérent avec les offsets et la traçabilité (règle 3). Pas d'interface
autonome (phase 3). Dire ce que l'aperçu ne garantit pas (un oubli de détection
n'apparaît pas à l'écran).

### P2-09 — Export AIPD (`spec`)

**Débloquée par le mainteneur le 26 octobre 2026.** Deux préalables ne sont **pas**
levés et restent à traiter dans la spec, sans être tranchés par l'agent : le
gabarit de la CNIL n'a pas été lu (la spec le lit, ou dit qu'elle ne peut pas le
lire), et l'avis d'un DPO est requis avant d'affirmer que le journal n'est pas une
donnée personnelle (`DECISIONS.md`) : la spec pose la question, elle n'y répond pas.

Travail : écrire `agent/specs/P2-09.md`, **aucune ligne de code**. Lire le gabarit
officiel et en citer l'URL et la date de lecture ; si la page est inaccessible, le
dire et ne rien affirmer sur son contenu. Lister les champs du registre
pré-rempli, les données d'`ecluse_audit` qui y entrent, **celles qui n'y entrent
pas** (aucune valeur ni aucun jeton), et ce que l'export n'atteste pas. Ne rien
affirmer sur la nature juridique du journal : poser la question au mainteneur.

### P2-10 — Transcription vocale locale (`spec`)

**Bloquée** : licences et tailles des modèles non vérifiées. Passer à `à faire`
est une décision du mainteneur.

Travail : écrire `agent/specs/P2-10.md`, **aucune ligne de code**. Comparer Vosk et
whisper.cpp (licence du code et des poids lue sur la page, taille, langues,
plateformes, latence annoncée **sans la présenter comme mesurée**). Décrire la
preuve qu'aucun son ne sort de l'appareil (aucun repli cloud, comment le vérifier),
la limite honnête sur les identifiants numériques (NIR, IBAN : taux d'erreur à
mesurer, pas à supposer) et un critère GO/STOP propre au sens de la règle 7. Poser
les choix au mainteneur en fin de document.

### P2-11 — Retirer `pubspec_overrides.yaml` d'`ecluse_bench` du suivi git (`code`)

Contexte : `packages/ecluse_bench/pubspec_overrides.yaml` est suivi par git alors que
`.gitignore` exclut `pubspec_overrides.yaml` (fichier généré par Melos). Il contient
un chemin Windows (`..\ecluse_core`) qui fait échouer `dart pub get` sous Linux.
Décision du mainteneur : le retirer du suivi (`DECISIONS.md`, « Petits points de la
phase 2 »).

- `git rm --cached packages/ecluse_bench/pubspec_overrides.yaml` ; ne rien changer
  d'autre dans `.gitignore`.
- Vérifier avant la PR que `melos bootstrap` régénère le fichier sous Linux et que
  `melos run format`, `analyze` et `test` passent. Vérifier que la CI n'en dépend
  pas ; si elle en dépend, s'arrêter et le dire (`.github/` est une zone interdite).
- **Fini quand** : le fichier n'est plus suivi, les trois commandes passent, la PR
  dit ce qui a été vérifié.

### P2-12 — Décompte reproductible de la fuite des noms hors civilité (`code`)

Contexte : `agent/specs/P2-02-reference.md` (§ « Part de la fuite des noms due à la
civilité ») donne un décompte obtenu par un script jetable non versionné : réaliste,
0 caractère en clair hors civilité ; adversarial, 1865 caractères non blancs sur 2657
(graine 42) et 1901 sur 2799 (graine 7). Un chiffre sans commande reproductible ne
peut pas figurer dans l'article (`DECISIONS.md`).

- Écrire `bench/leak_hors_civilite.py` : à partir d'un corpus flou et des
  prédictions de `run_redact_bench.dart`, compter, mot par mot, les caractères non
  blancs des noms annotés restés en clair, et la part qui n'est pas une civilité
  (`M.`, `Monsieur`, `Mme`, `Madame`, `Mademoiselle`).
- Retrouver les valeurs ci-dessus sur les corpus flous aux graines 42 et 7, ou
  **expliquer l'écart** dans la PR. Ne pas ajuster le script pour retomber sur les
  chiffres.
- Tests (`python3 -m unittest discover -s bench`) : cas construits à la main,
  civilité seule, civilité plus prénom, nom entièrement masqué, mention absente.
- Section dans `bench/README.md` avec la commande ; aucun tableau existant modifié.
- **Fini quand** : tests passent et la PR donne les chiffres reproduits et la
  commande exacte.

### P2-13 — Règle de noms entre documents activable : N3 (`code`)

Contexte : `agent/specs/P2-05.md` § 5 (options N1, N2, N3) et la PR P2-06. N1 a été
retenue par délégation (`DECISIONS.md`) : entre documents d'un dossier, seule une
identité complète identique (deux segments au moins) garde son jeton. La mesure de
P2-06 a montré le coût : la cohérence des noms baisse (réaliste 63 % → 44–46 %)
parce qu'une mention partielle (« Mme Verdier » après « Mme Sophie Verdier ») reçoit
un nouveau jeton. Le mainteneur demande N3 : N1 par défaut, N2 activable.

- Ajouter à `Dossier` une option explicite (par exemple un paramètre nommé du
  constructeur) qui choisit la règle de noms entre documents : N1 (défaut) ou N2
  (la règle d'inclusion et de civilité de `_resolveNomToken`, appliquée comme dans un
  document). Sans l'option, comportement **octet pour octet** celui de P2-06 (test
  d'équivalence d'abord).
- Sous N2, garder les garde-fous de la règle actuelle (civilités de sexe différent,
  ambiguïté entre plusieurs identités) et décrire dans la doc de l'option le risque
  de fausse fusion entre documents (homonymes, patronyme répandu) et la restauration
  qui écrit la forme la plus complète.
- Mesurer avant/après avec `run_dossiers_bench.dart --dossier` (ajouter l'option au
  programme) sur les trois corpus de P2-05a, graines 42 et 7 : cohérence, collisions,
  fausses fusions, restaurations non identiques, pour N1 et pour N2. Rapporter les
  deux dans la PR sans choisir à la place du mainteneur lequel recommander par défaut.
- Mettre à jour `LIMITES.md` § 5.3 et `DECISIONS.md` (N3 demandé après la mesure de
  P2-06).
- `ecluse_core` inchangé (règle 6). Aucune dépendance pub ou pip.
- **Fini quand** : `format`, `analyze` et `test` passent, la PR chiffre N1 et N2 et
  liste ce que le mainteneur doit vérifier.

### P2-14 — Patronyme seul : ce qu'un rattrapage sans liste ni NER peut détecter (`code`)

Contexte : P2-06 a relevé que, dans le corpus réaliste de dossiers (graine 42), 112
mentions nominales sur 116 qui sont un patronyme seul (sans civilité ni prénom) ne
sont pas détectées. `LIMITES.md` § 5.2 et § 5.4 posent que le rattrapage ne s'arme que
sur un patronyme déjà établi dans le même document, « jamais de liste externe,
jamais d'apprentissage », et que l'arbitrage plus large « attend le NER local de la
phase 2 » (règle 7 : le NER ONNX n'est pas fusionné sans GO/STOP). Cette tâche ne
touche pas au NER.

- **Mesurer d'abord** (règle 5). Ajouter au corpus de dossiers ou aux corpus flous des
  cas annotés de patronyme seul, en séparant : (a) le patronyme seul **après** une
  mention établie dans le même document (déjà rattrapé par § 5.4) ; (b) le patronyme
  seul **en première mention** ; (c) le patronyme seul dans un **autre document** du
  dossier. Chiffrer le rappel actuel pour chaque cas.
- Identifier ce qui est atteignable **sans liste externe ni NER** et quel budget de
  faux positifs cela coûte sur le corpus témoin (seuil de référence : 1 % de faux
  positifs sur le témoin, voir `agent/specs/P2-01.md` § 4). Ne rien implémenter si le
  budget est dépassé : la PR est alors une mesure.
- Si une règle tient le budget, l'implémenter avec ses tests (cas valides, rejets,
  positions), sans toucher aux détecteurs hors du périmètre, et chiffrer avant/après
  (précision, rappel, fuite globale, budget de faux positifs). Vérifier que les
  mesures de P2-02 sont inchangées hors cas visés (fuite globale 7,5 % réaliste,
  16,8 % adversarial, 59 restaurations non identiques).
- Mettre à jour `LIMITES.md` §§ 5.2 et 5.4 avec ce qui est et n'est pas couvert.
- Aucune dépendance pub ou pip ; `ecluse_core` reste inchangé sauf si la règle vit
  dans un détecteur du cœur (le dire dans la PR).
- **S'arrêter et rendre la main** si la seule voie est une liste de patronymes ou un
  NER.
- **Fini quand** : la mesure par cas est dans la PR, la règle éventuelle est
  implémentée ou l'impossibilité sans NER est établie par les chiffres.

### P2-15 — Agrégat d'export pour le registre et l'AIPD (`code`)

Contexte : `agent/specs/P2-09.md` § 4 et `DECISIONS.md` (« Préconisations des specs
P2-07, P2-08 et P2-09 »). Aucune agrégation ni export n'existe dans `ecluse_audit`.

- Écrire une fonction **pure** qui prend une liste d'entrées (`AuditEntry`) et produit
  un agrégat : période (première et dernière entrée), nombre d'opérations `redact` et
  `ingest_refused`, entités détectées par type, refus par code de motif, versions de
  moteur rencontrées, résultat de `AuditVerifier` (intacte ou rompue, rang de la
  première rupture).
- **Seuil de faible effectif** : tout compte par type inférieur à 5 devient « moins
  de 5 » ; si le nombre d'opérations est inférieur à 5, la période est donnée au
  jour. Seuil paramétrable, défaut 5.
- Rendu en JSON canonique et en texte lisible. Les **mentions d'honnêteté** de la
  § 6 de la spec figurent dans la sortie elle-même, toujours, y compris pour un
  journal vide.
- Aucune écriture, aucune valeur, aucun jeton, aucune position : un test vérifie que
  la sortie ne contient aucune clé hors liste fermée.
- Tests : journal vide, une seule entrée, chaîne rompue, seuil, reproductibilité.
  `format`, `analyze` et `test` dans `ecluse_audit`. Aucune dépendance ajoutée.
- Ne rien affirmer sur la nature juridique du journal ni sur la conformité.
- **Fini quand** : tests passent, la PR liste ce que le mainteneur doit vérifier.

### P2-16 — Scinder détection et application dans `Ecluse.redact` (`code`)

Contexte : `agent/specs/P2-08.md` §§ 2 et 4. `Ecluse.redact` est monolithique : un
aperçu ne peut ni proposer sans masquer, ni appliquer une décision.

- **Test d'équivalence d'abord** : la sortie d'`Ecluse.redact` (texte masqué, carte,
  avertissements, ordre des clés) est inchangée, avec et sans `Dossier`, sur les
  corpus de `bench/` (flou, QI, dossiers).
- Séparer la détection (entités résolues, aucun effet de bord, aucun numéro de jeton
  consommé, `Dossier` intact) de l'application (jetons, carte, texte masqué, état du
  `Dossier`). `Ecluse.redact` devient leur composition ; rien ne change pour les
  appelants.
- Mesurer la non-régression : fuite 7,5 % / 16,8 %, 59 restaurations non identiques ;
  performance comparable.
- Hors périmètre : le composant d'aperçu lui-même (types de la proposition, décision,
  refus, ajouts), à traiter ensuite.
- `ecluse_core` inchangé (règle 6). Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze` et `test` passent, les mesures sont dans la PR.

### P2-17 — Échelle de dates de naissance et dérivation d'âge (`code`)

Contexte : `agent/specs/P2-07.md` §§ 2.1 et 2.2 et `DECISIONS.md`. `ecluse_reid`
généralise l'âge (exact, 5 ans, 10 ans, senior, retrait) mais pas la date de naissance,
et n'a pas de palier pour les grands âges.

- Ajouter, **en ajout** (aucune modification de `estimate`) : une échelle de dates
  (mois/année, année, décennie, retrait) ; la dérivation d'un âge à partir d'une date
  avec une **date de référence fournie par l'appelant** (aucune horloge système) ; un
  palier « 85+ ».
- Ne pas modifier le masquage de la date de naissance par `Ecluse.redact` : ce travail
  est de la bibliothèque `ecluse_reid` seulement.
- Tests : cas limites de calendrier (29 février, anniversaire le jour de référence),
  reproductibilité (date de référence explicite), âges hors pyramide.
- `ecluse_reid` : `format`, `analyze`, `test`. Aucune dépendance ajoutée.
- **Fini quand** : tests passent et la PR dit ce que les nouveaux paliers changent à
  l'estimation (rien, tant qu'`estimate` n'est pas étendu).

### P2-18 — Composant d'aperçu avec validation (`code`)

Contexte : `agent/specs/P2-08.md` et `DECISIONS.md` (préconisations validées par
délégation, révocables). Bibliothèque seulement : aucune interface.

- `Apercu.propose` : détection sans masquer (via `Ecluse.detect`), entités
  identifiées, résumé par type ; `refuseSecrets` avant toute proposition.
- `Apercu.applique` : texte masqué selon la décision (refus d'entités, ajouts
  manuels), via la même étape d'application que `Ecluse.redact` : « tout accepté »
  est identique à `redact`.
- Garde-fous : texte envoyé identique au texte analysé ; identifiant inconnu,
  ajout hors bornes ou de type secret, chevauchement partiel : erreur explicite ;
  refus d'une entité structurelle seulement avec une option ; refus d'un secret
  interdit ; toute validation avant la première modification d'état.
- Tests : équivalence, absence d'effet de bord, restauration identique sur décisions
  aléatoires (graine fixe). Mesures : prédictions du banc inchangées.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et la PR dit ce qui n'est pas
  fait (interface, tests utilisateurs, trace d'audit, rapport de risque dans la
  proposition).

### P2-19 — Péremption d'une proposition d'aperçu (`code`)

Contexte : limite signalée par la PR de P2-18 et par `LIMITES.md` § 6 : une
proposition établie sur un dossier n'était pas détectée comme périmée.

- Une `Proposition` retient le dossier qui l'a produite et le nombre de documents
  qu'il avait masqués (lu dans la même section sérialisée que la détection).
- `Apercu.applique` refuse (`ApercuException`, avant toute modification d'état) si le
  dossier diffère (y compris absent d'un côté) ou si le dossier a masqué un autre
  document depuis.
- Tests d'abord (5 cas rouges avant le correctif) ; comportement inchangé sans dossier
  et pour toute séquence propose → applique directe.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent ; `LIMITES.md` mis à jour.

### P2-20 — Blancs en bordure d'un ajout manuel (`code`)

Contexte : mesure du 26 octobre 2026 sur 2 191 documents synthétiques avec 2 431 ajouts
aléatoires de type `nom` : un ajout « e de » (avec espace final) et le même texte sans
espace partageaient un jeton dont la carte gardait la première forme ; la restauration
ajoutait un espace (3 documents non identiques en plus de `redact`).

- Test d'abord : deux ajouts identiques à l'espace près (sélection à la souris) se
  restaurent à l'identique ; un ajout fait seulement de blancs est refusé.
- `Apercu.applique` réduit les bornes d'un ajout pour exclure les blancs de bordure
  (ils restent en clair) avant les contrôles de chevauchement.
- Mesure après : 3 → 2 documents ; les 2 restants relèvent de l'harmonisation des
  re-mentions (`LIMITES.md`, point 5), comportement existant et documenté.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-21 — Ajout manuel coupant une paire de substituts (`code`)

Contexte : sondage du 26 octobre 2026. Un ajout `AjoutManuel` dont le début ou la fin
tombe au milieu d'un émoji était accepté : le texte masqué contenait une moitié de
caractère isolée (`Bonjour �[NOM_1] arrive.`), qui ne s'encode pas en UTF-8 sans
remplacement. Une interface qui compte en unités UTF-16 peut produire ces bornes.

- Test d'abord : trois bornes coupant l'émoji sont refusées ; un ajout qui encadre
  l'émoji entier reste accepté et se restaure à l'identique.
- `Apercu.applique` refuse (`ApercuException`, avant toute modification d'état) un
  ajout dont une borne est entre un substitut haut et un substitut bas.
- Sondage des détecteurs sur un échantillon d'émojis et de lettres mathématiques : 0
  coupure sur 7 entités (étroit, non garanti).
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-22 — Provenance « manuelle » des ajouts d'aperçu (`code`)

Contexte : `DECISIONS.md`, P2-08, décision 4 : « provenance marquée "manuelle" ». P2-18
ne la livrait pas : une entité ajoutée à la main était indiscernable d'une détection
dans `RedactResult.entities`.

- Test d'abord : après `Apercu.applique` avec un ajout, `RedactResult.manuelles`
  contient l'entité ajoutée (positions, type) et pas les détections ; sans ajout et
  pour `Ecluse.redact`, la liste est vide.
- Champ additif `manuelles` (défaut vide) dans `RedactResult` ; les entités manuelles
  restent comprises dans `entities`. Aucune autre sortie ne change.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze` et `test` passent sur `ecluse_redact` et
  `analyze` sur les paquets qui consomment `RedactResult`.

### P2-23 — Rapport de risque de l'aperçu avant application (`code`)

Contexte : `DECISIONS.md`, P2-08, décision 7 (« rapport de risque inclus dans la
proposition quand l'appelant fournit une référence »), écart signalé dans la PR de
P2-18 : le rapport n'était calculé qu'à l'application.

- Tests d'abord : le rapport simulé est égal à celui de `Apercu.applique` (tout
  accepté, avec refus et ajout, dans un dossier déjà alimenté) ; aucun effet de bord
  sur le dossier ; mêmes refus que `applique` (décision invalide, dossier fermé,
  proposition périmée) ; `Proposition.risque` absent sans référence.
- `Apercu.risque(proposition, decision:, riskReference:, dossier:)` simule le
  masquage sur une copie profonde de l'état (`_Etat.copie`) ; `Apercu.propose`
  accepte `riskReference` et renseigne `Proposition.risque` (tout accepté).
- Mesure : sur 2 191 documents synthétiques avec refus aléatoires (graine 42), dans un
  dossier, 0 différence avec le rapport de l'application.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-24 — Aperçu d'un fichier : composition sur le texte extrait (`code`)

Contexte : `DECISIONS.md`, P2-08, décision 10 : l'aperçu porte sur le texte extrait.

- Aucun code d'intégration : `ingestFile` donne le texte, `Apercu.propose` le prend.
  Le livrable est un **test de caractérisation** dans `ecluse_ingest` (txt, md, docx) :
  entités retombant sur le texte extrait, « tout accepté » égal à `Ecluse.redact`, un
  refus restauré à l'identique ; un fichier refusé ne donne aucun aperçu.
- `LIMITES.md` : ce qui n'est pas extrait n'apparaît pas dans l'aperçu ; l'application
  doit afficher les avertissements d'ingestion avec lui.
- Le test n'était pas rouge avant : il fixe un comportement, il n'en corrige pas.
- `ecluse_core` inchangé. Aucune dépendance ajoutée (`ecluse_ingest` dépendait déjà
  d'`ecluse_redact`).
- **Fini quand** : `format`, `analyze`, `test` passent sur `ecluse_ingest`.

### P2-25 — Coût de la recherche des jetons littéraux dans un gros dossier (`code`)

Contexte : mesure du 26 octobre 2026 (`LIMITES.md` § 5.5) : 53 ms par appel après 2 000
documents d'un même `Dossier`, dont environ 38 ms pour la recherche des jetons déjà
attribués écrits en clair dans le texte (un motif compilé par jeton et par appel).

- Test d'équivalence d'abord (vert avant et après) : les avertissements « jeton
  littéral » sont ceux de `tolerantTokenPattern` sur 13 variantes (casse, espaces,
  jeton collé, crochet ouvert ou fermé seul, imbriqué, sur plusieurs lignes) et 300
  textes aléatoires (graine 42).
- La recherche se limite aux segments `[...]` sans crochet du texte et réutilise les
  motifs compilés (cache par jeton dans l'état du dossier).
- Mesure : 52,65 → 0,3 ms par appel à 2 000 documents sans crochet, 3,3 ms avec ;
  prédictions du banc dossiers inchangées octet pour octet.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` § 5.5 est à jour.

### P2-26 — Recoupement des comptes masqués dans l'export du journal (`code`)

Contexte : vérification de P2-15 (26 octobre 2026), deux divulgations reproduites :
(1) `chaine.entrees` publiait le nombre exact d'entrées (3) alors que `operations` valait
« moins de 5 » ; (2) avec 9 opérations `redact` et 3 refus, `operations = 12` et
`redact = 9` redonnaient les 3 refus masqués.

- Tests d'abord (4 rouges avant) : le nombre d'entrées de la chaîne suit le masquage ;
  le total n'est exact que si aucune opération n'est masquée ; si un seul code de refus
  est masqué alors que le nombre de refus est exact, un autre code l'est aussi ; propriété
  (graine 42, 400 journaux) : jamais une seule inconnue dans une somme exacte.
- Suppression complémentaire sous la mention « non communiqué (recoupement) » (jamais
  « moins de N », qui serait faux pour un compte supérieur ou égal à N).
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent sur `ecluse_audit` et `LIMITES.md`
  § 8 est à jour. Limite assumée : ces règles ne protègent que contre les sommes publiées
  par l'export lui-même.

### P2-27 — Vérification du CRC-32 des archives `.docx` et `.odt` (`code`)

Contexte : essai de falsification de l'ingestion (26 octobre 2026) : sur 4 000 `.docx`
abîmés au hasard, 81 étaient lus avec un texte altéré et 34 avec un texte vide, comme des
succès. Cause : `package:archive` 4.5.2 ne vérifie pas le CRC-32 (`verify` est sans effet).
C'est un « lu à moitié » silencieux (règle 4).

- Tests d'abord (2 rouges avant) : un `.docx` et un `.odt` dont un octet du contenu est
  modifié sans toucher au CRC sont refusés ; les archives intactes restent lues.
- `decompressBounded` compare le CRC-32 des octets réellement produits à celui de
  l'entrée (`ZipCrcMismatch`, message sans contenu) ; les extracteurs refusent déjà toute
  exception de lecture avec le motif « corrompue ».
- Mesure : 81 textes altérés et 34 textes vides lus comme des succès, puis 0 et 0.
- `ecluse_core` inchangé. Aucune dépendance ajoutée (`getCrc32` vient d'`archive`).
- **Fini quand** : `format`, `analyze`, `test` passent sur `ecluse_ingest` et `LIMITES.md`
  § 4 est à jour.

### P2-28 — Page de PDF perdue sans avertissement (`code`)

Contexte : essai de falsification de l'ingestion PDF (26 octobre 2026) : sur 1 500 copies
abîmées d'un PDF de trois pages, 63 étaient lues comme des succès sans une page, sans
avertissement. La spec P1-09 § 3 n'accepte un PDF que si tout son contenu est lu.

- Test d'abord (1 rouge avant) : une copie du PDF de bench abîmée en deux octets (page 3
  perdue) est refusée (`malforme`) ; l'intact est lu en entier.
- `ingestPdf` recoupe le nombre d'objets `/Type /Page` visibles en clair avec le nombre de
  pages lues et refuse s'il y en a plus.
- Mesure : pages perdues sans avertissement 63 -> 6 sur 1 500 ; 40 PDF de bench inchangés.
- Limites assumées : flux compressés non comptés ; refus possible à tort pour un PDF
  mis à jour par ajout (à mesurer sur de vrais fichiers) ; pas de détection d'un texte
  modifié sans effet sur la structure.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent sur `ecluse_ingest` et `LIMITES.md`
  § 4 est à jour.

### P2-29 — Identifiants avec caractères invisibles ou séparateurs typographiques (`code`)

Contexte : sondage de recall (26 octobre 2026) : un NIR, un IBAN ou un téléphone contenant
un espace sans chasse (U+200B), un trait d'union conditionnel, un tiret demi-cadratin ou
insécable n'est pas détecté, donc pas masqué (22 cas sur 33 détectés en entier). Vecteur
d'évasion facile et accident de copier-coller courant.

- Tests d'abord (25 rouges sur 30 avant) : 9 séparateurs × NIR/téléphone/IBAN (détection
  complète, valeur d'origine conservée, masquage, restauration), invisible en bordure,
  séquence d'émojis ZWJ inchangée, propriété (graine 42, 400 textes).
- `Ecluse._detecter` fait tourner les détecteurs sur une vue du texte (espaces Unicode →
  espace, tirets typographiques → `-`, caractères invisibles retirés), puis ramène positions
  et valeur au texte d'origine (jamais réécrit). Sans caractère concerné : détection identique.
- Mesure : 22/33 → 32/33 ; 47/48 avec cinq séparateurs de plus ; prédictions du banc
  (dossiers, flou) inchangées octet pour octet.
- `ecluse_core` inchangé (règle 6). Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` § 5.2 est à jour.

### P2-30 — Formes pleine chasse et autres chiffres dans un identifiant (`code`)

Contexte : suite de P2-29. Sondage (26 octobre 2026) de 17 variantes : 4 non détectées après
P2-29 (téléphone et NIR pleine chasse ; arobase pleine chasse ; barre de fraction dans une date).

- Tests d'abord (6 rouges avant) : téléphone, NIR, IBAN pleine chasse ; courriel à arobase
  pleine chasse ; téléphone en chiffres arabes orientaux ; date à barre de fraction ; un texte
  pleine chasse sans identifiant reste intact.
- La vue de détection ramène U+FF01 à U+FF5E, U+0660 à U+0669, U+06F0 à U+06F9, U+2044 et
  U+2215 à l'ASCII (une unité pour une unité) ; positions, valeur et restauration d'origine.
- Mesure : 4 variantes manquées → 0 ; banc (dossiers, flou) inchangé octet pour octet.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` § 5.2 est à jour.

### P2-31 — Restauration d'un jeton échappé en Markdown (`code`)

Contexte : sonde de 17 déformations d'un jeton par un LLM (26 octobre 2026) : 8 restaurées.
L'échappement Markdown (`\[NOM\_1\]`), fréquent quand le modèle répond en Markdown, laissait
le jeton tel quel dans la réponse.

- Tests d'abord (5 rouges avant) : cinq formes échappées sont restaurées (crochets et
  soulignement, crochets seuls, soulignement seul, dans du gras, avec espaces) ; jamais
  restaurés : chiffre différent, numéro absent de la carte, jeton sans crochets, autres
  délimiteurs ; les jetons exacts sont restaurés comme avant.
- `tolerantTokenPattern` tolère une barre oblique inversée facultative devant les crochets
  et chaque soulignement (échappement exact, sans perte) ; le numéro reste exact.
- Mesure : 8/17 → 10/17 formes de la sonde (les 5 formes échappées des tests sont restaurées) ; banc dossiers inchangé octet pour octet ; 452 tests.
- Non fait par choix : délimiteurs de remplacement, jeton sans crochets (risque de
  restaurer la mauvaise valeur).
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` § 5.3 est à jour.

### P2-32 — Noms aux accents décomposés (NFD) (`code`)

Contexte : sonde de noms (26 octobre 2026) : un nom dont l'accent initial est écrit « E » + U+0301
était détecté « E » seulement ; le reste du nom restait en clair (`Mme [NOM_1]́lodie Lefèvre`). Forme
courante des noms de fichiers macOS et de copier-coller de PDF. Fuite directe d'un nom.

- Tests d'abord (6 rouges avant) : six noms NFD (aigu initial, grave, cédille, tréma, accent
  final, plusieurs accents) masqués en entier avec restauration identique ; la forme NFC est
  inchangée ; un diacritique combinant hors nom ne crée pas d'entité.
- La vue des détecteurs (P2-29) retire aussi les diacritiques combinants ; la fin d'une entité
  ramenée au texte d'origine absorbe les diacritiques qui suivent sa dernière lettre.
- Mesure : 371/397 → 397/397 documents accentués du corpus dossiers (NFD = NFC en nombre de
  jetons) ; banc (dossiers, flou) inchangé octet pour octet.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` § 5.2 est à jour.

### P2-33 — Majuscules et lettres étendues dans un nom (`code`)

Contexte : sonde de 20 formes de noms (26 octobre 2026) : 15 détectées en entier ; « François Œil »,
« Zoë Ångström », « Łukasz Kowalski », un nom vietnamien échappaient en partie (le patronyme restait en
clair) : la majuscule initiale d'un mot de nom ne couvrait que A-Z et quelques lettres françaises.

- Tests d'abord (11 rouges sur 11 noms, avant) : noms espagnols, portugais, polonais, tchèque, turc,
  vietnamien et scandinave masqués en entier avec restauration identique ; un mot capitalisé isolé
  (« Œuvre », « Ångström ») ne devient pas un nom.
- `_cap` : majuscule initiale étendue au Latin-1 (À-Ö, Ø-Þ) et aux majuscules du Latin étendu A ;
  lettres suivantes étendues au Latin étendu additionnel (vietnamien).
- Mesure : 11/11 ; banc (dossiers, flou, patronymes avec leurres de faux positifs) inchangé octet pour
  octet ; 471 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` § 5.2 est à jour.

### P2-34 — Dates de naissance aux séparateurs espacés (`code`)

Contexte : sonde de 23 formulations de date de naissance (26 octobre 2026) : 16 détectées ; les formes
numériques à séparateurs entourés d'espaces (« 12 / 03 / 1950 ») ou à simples espaces (« 12 03 1950 »)
échappaient.

- Tests d'abord (6 rouges, avant) : formes espacées détectées avec offsets exacts ; restauration
  identique ; pas de faux positif hors contexte de naissance.
- `date_naissance_detector.dart` : deux alternatives numériques tolérant des blancs autour du séparateur ;
  l'année à quatre chiffres reste exigée pour la forme à simples espaces.
- Mesure : formulations détectées 16/23 → 18/23 ; banc inchangé octet pour octet.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-35 — Civilités abrégées avec point (`code`)

Contexte : sonde de 10 formes de noms (26 octobre 2026) : « Mme. Sophie Mac Donald » laissait
« Donald » en clair ; « Mme. » et « Mlle. » n'étaient pas reconnues comme civilités.

- Tests d'abord (3 rouges, avant) : avec point, avec prénom inconnu ou patronyme de deux mots ;
  restauration identique.
- `name_detector.dart` : `Mme` et `Mlle` acceptent un point final.
- Mesure : 3 rouges → verts ; banc inchangé octet pour octet ; 495 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-36 — Patronyme derrière une étiquette de champ (`code`)

Contexte : sonde de P2-35 : « Nom : Dupont ; Prénom : Jean » masquait « Jean » mais laissait « Dupont ».

- Tests d'abord (6 rouges, avant) : étiquettes précises toujours ; « Nom » seul seulement si
  « Prénom » suit (même ligne ou suivante) ; contre-exemples (« Nom : Aspirine », « Nom du
  médicament : », « inconnu » en minuscules) intacts ; restauration identique.
- `name_detector.dart` : `_champNom` + contrôle de fenêtre `_fichePrenomSuit` ; confiance 0,6 ;
  le patronyme alimente la deuxième passe.
- Mesure : 6 rouges → verts ; banc inchangé octet pour octet (sans cas couvrant la règle) ;
  509 tests. Une première version était cubique (126 s pour 2000 « Nom ») : corrigée avant
  fusion, test de non-régression ajouté.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-37 — Numéro de voie suivi d'une lettre (`code`)

Contexte : sonde d'adresses (26 octobre 2026) : « 12 B rue des Lilas, 75011 Paris » laissait « 12 B ».

- Tests d'abord (4 rouges, avant) : « 12 B », « 12B », « 3 A », « 7 C, » masqués en entier avec
  restauration identique ; « Le groupe B rue vite », « Annexe 12 B : voir page 3 », « Lot 4 C du
  marché » restent intacts.
- `adresse_detector.dart` : `_numero` accepte une lettre majuscule A-F isolée.
- Mesure : 4 rouges → verts ; banc inchangé octet pour octet ; 517 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-38 — Identifiant coupé par une fin de ligne (`code`)

Contexte : sonde de 14 formes (26 octobre 2026) : tout identifiant à chiffres coupé par une fin de ligne
entre deux groupes échappait à la détection (limite jusqu'ici documentée, `texte_iban_coupe`).

- Tests d'abord (11 rouges, avant) : téléphone, NIR, IBAN et date coupés (dont `\r\n`, blancs de part
  et d'autre, coupure après un tiret) ; contre-exemples (« Total : 150⏎Page 12 », « Chambre 12⏎Lit 3 »,
  tableau d'une colonne de nombres) intacts ; deux numéros sur deux lignes restent deux numéros ;
  restauration identique.
- `ecluse.dart` : `_vueDeDetection` neutralise la coupure (`_coupuresDeLigne`, lookbehind chiffre ou
  `/ . -`, lookahead chiffre) ; le texte n'est jamais réécrit, les offsets sont remappés.
- Mesure : 11 rouges → verts ; banc inchangé octet pour octet ; 533 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée. Assouplit une limite documentée
  (`LIMITES.md` § 5.2 conserve la règle pour noms, adresses, établissements).
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-39 — Date de naissance séparée de son étiquette (`code`)

Contexte : sonde de formats de formulaire (26 octobre 2026) : « Date de naissance :⏎12/03/1950 », « Date de
naissance | 12/03/1950 », « Date de naissance;12/03/1950 » n'étaient pas détectées.

- Tests d'abord (10 rouges, avant) : formes avec saut de ligne (`\n`, `\r\n`), `|` (avec et sans barres
  de bord), `;`, étiquettes « DDN » et « Né le », formats `12 mars 1950` et ISO ; contre-exemples
  (ligne vide, ligne étrangère, virgule, « naissance du projet », date sans étiquette) intacts ;
  restauration identique.
- `date_naissance_detector.dart` : `_sepContexte` (blancs, `|` ou `;`, ou un seul saut de ligne).
- Mesure : 10 rouges → verts ; banc inchangé octet pour octet ; 549 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-40 — Prénom derrière une étiquette, fiche Prénom avant Nom (`code`)

Contexte : contrôle de P2-36 (26 octobre 2026) : « Prénom : Zorglub » (prénom hors gazetteer) restait en clair, et
« Prénom : Zorglub⏎Nom : Quenelle » laissait le patronyme.

- Tests d'abord (8 rouges, avant) : prénoms derrière « Prénom », « Prénoms » (3 mots), « Prénom usuel »,
  « Prénom de naissance », majuscules ; ordre inverse Prénom → Nom ; contre-exemples (« Prénom du chat »,
  minuscules, étiquette vide, « Nom : Aspirine ») intacts ; restauration identique.
- `name_detector.dart` : `_champPrenom`, `_fichePrenomPrecede` (fenêtre bornée de 300 caractères).
- Mesure : 8 rouges → verts ; banc inchangé octet pour octet (sans cas couvrant la règle) ; 563 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-41 — Étiquettes « Nom du patient », « Nom de l'assuré »… (`code`)

Contexte : sonde d'étiquettes courantes (26 octobre 2026) : « Nom du patient : Quenelle » restait en clair.

- Tests d'abord (10 rouges, avant) : patient(e), assuré(e), bénéficiaire, demandeur, salarié, employé(e),
  résident, majuscules ; contre-exemples (« Nom du médicament », « du fichier », « du projet », valeur en
  minuscules ou vide) intacts ; restauration identique.
- `name_detector.dart` : `_nomQualifie` ajouté aux étiquettes précises de `_champNom`.
- Mesure : 10 rouges → verts ; banc inchangé octet pour octet (sans cas couvrant la règle) ; tests passent.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : étiquettes génériques (« Contact : »…) + nom hors gazetteer sans civilité (décision de
  périmètre, documentée).
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-42 — Clé du NIR nommée à part (`code`)

Contexte : sonde de variantes de NIR (26 octobre 2026) : « 2550814168025 clé 38 » laissait les 13 chiffres en clair
(métropole, Corse 2A/2B, DOM, étranger).

- Tests d'abord (10 rouges, avant) : « clé », « Clé : », « CLÉ », « cle », « clef », parenthèses, numéro
  groupé ou non, 2A, 2B, 971, restauration identique ; contre-exemples (clé fausse, clé à un chiffre,
  « Chambre 12 clé 38 », nombre quelconque + « clé 99 ») non détectés.
- `ecluse.dart` : `_vueDeDetection` neutralise le mot « clé » (`_cleNommee`) entre un chiffre et deux
  chiffres ; `ecluse_core` inchangé, la validation de la clé reste celle du détecteur de NIR.
- Mesure : 10 rouges → verts ; banc inchangé octet pour octet ; 592 tests ; coût linéaire.
- Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-43 — Variantes du contexte et de la date de naissance (`code`)

Contexte : sonde de 23 écritures (26 octobre 2026) : 12 manquées (« né(e) à Lyon (69) le … », « Date de naiss. »,
« D.D.N. », jour de semaine, « 12 mars 50 », mois anglais derrière « DOB »).

- Tests d'abord (18 rouges, avant) ; 7 contre-exemples sans contexte de naissance restent intacts ;
  restauration identique.
- `date_naissance_detector.dart` : département facultatif après le lieu, contexte élargi
  (`naiss.`, `D.D.N.`, `date of birth`, `birth date`, `born on`), jour de semaine facultatif, année à
  deux chiffres avec un mois en lettres, mois anglais.
- Mesure : 18 rouges → verts ; banc inchangé octet pour octet ; 617 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-44 — Téléphone : préfixe entre parenthèses et outre-mer (`code`)

Contexte : sonde de 22 numéros (26 octobre 2026) : « (+33) 6 12 34 56 78 » laissait « (+33) » et classait le reste
en FINESS ; « +262 692 12 34 56 » (outre-mer, numéro français) n'était pas détecté.

- Tests d'abord (10 rouges, avant) : « (+33) » avec et sans « (0) » et sans séparateur ; +262, +590,
  +594, +596 avec séparateurs variés ; contre-exemples (trop ou trop peu de chiffres) intacts ;
  restauration identique.
- `telephone_detector.dart` : `(+33)` dans le préfixe, `_outreMer`.
- Documenté : les numéros étrangers (+32, +41, +44, +1…) ne sont pas détectés (limite non écrite
  jusqu'ici).
- Mesure : 10 rouges → verts ; banc inchangé octet pour octet ; 631 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-45 — Nom de naissance ou d'épouse (`code`)

Contexte : sonde de 24 civilités et titres (26 octobre 2026) : « Mme Quenelle née Dupont » laissait « Dupont »
en clair (de même « épouse », « ép. », « veuve », « nom de jeune fille »).

- Tests d'abord (17 rouges, avant) ; 9 contre-exemples (« née le », « née à », « Née Lundi », « épouse de
  l'intéressé »…) intacts ; restauration identique.
- `name_detector.dart` : `_nomDeNaissance` (marqueur + un ou deux mots à majuscule initiale, mois et jours
  exclus), confiance 0,7 ; le nom alimente la deuxième passe.
- Mesure : 17 rouges → verts ; banc inchangé octet pour octet (sans cas couvrant la règle) ; 657 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : titres et fonctions sans prénom connu (« Professeure », « Dre », « abbé », « Infirmière »…).
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-46 — Titres supplémentaires (`code`)

Contexte : sonde de 24 civilités et titres (26 octobre 2026) : « Professeure », « Dre », « Ms », « Mgr », « Abbé »
ne déclenchaient pas la règle de civilité ; un nom sans prénom connu restait en clair.

- Tests d'abord (10 rouges, avant) ; 5 contre-exemples en minuscules ou sans nom intacts ; restauration
  identique.
- `name_detector.dart` : alternation de `_civility` étendue ; `Professeure`, `Docteure`, `Dre` ajoutés aux
  titres professionnels (masqués avec le nom).
- Mesure : 10 rouges → verts ; banc inchangé octet pour octet ; 672 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-47 — Particules de noms d'origine étrangère (`code`)

Contexte : sonde de 27 noms à particules (26 octobre 2026) : « M. Pedro dos Santos », « M. Luis da Silva »,
« M. Ahmed ben Ali » étaient masqués à moitié.

- Tests d'abord (15 rouges, avant) ; 4 contre-exemples sans civilité ni prénom connu intacts ;
  restauration identique.
- `name_detector.dart` : `_particules` étendue (da, das, do, dos, di, del, della, ben, bin, bint, ibn, ter,
  ten, zu, af).
- Mesure : 15 rouges → verts ; banc inchangé octet pour octet ; 691 tests. Le coût quadratique sur mentions
  identiques est antérieur (10,9 s sur la base à ×4000) : non aggravé (5,3 s).

### P2-48 — Coût quadratique de la détection de noms (`code`)

Contexte : mesure (26 octobre 2026) : 4 000 mentions répétées prenaient 11 s (32 000 : plus de 100 s) ; le
détecteur de noms seul en prenait 6.

- Test d'abord (2 rouges, avant : 36 s) : 4 000 mentions en moins de 4 s.
- `name_detector.dart` : recherche du mot précédent bornée à 400 caractères, plages réservées dans un
  masque par caractère (`_Reserve`), expression d'écart précompilée.
- Mesure : 4 000 mentions 11 s → 0,5 s ; 32 000 : 39 s → 13 s ; fuzz différentiel de 1 500 textes
  identique avant/après ; banc inchangé octet pour octet ; 674 tests.

- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-49 — Types de voie et abréviations (`code`)

Contexte : sonde de 26 adresses (27 octobre 2026) : « 25 R. de la Paix, 75002 Paris » laissait le numéro et le nom de
rue en clair (seul « code postal + commune » était masqué).

- Tests d'abord (17 rouges, avant) ; 5 contre-exemples sans code postal ou hors adresse intacts ;
  restauration identique.
- `adresse_detector.dart` : `_voies` étendue (sentier, ruelle, traverse, venelle, parvis, promenade, montée,
  clos ; abréviations r, pl, ch, imp, all, sq, crs).
- Mesure : 17 rouges → verts ; banc inchangé octet pour octet ; 715 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-50 — Recherche de la fiche « Prénom » bornée (`code`)

Contexte : sonde de robustesse sur 16 textes d'environ 1 Mo (27 octobre 2026) : « Nom : » répété 160 000 fois sans saut de
ligne prenait 43,6 s ; le détecteur de noms seul en prenait la presque totalité pour 0 entité.

- Tests d'abord (2 rouges, avant) : 160 000 « Nom : » et 64 000 « Nom : Aspirine » en moins de 15 s (borne
  large pour l'intégration continue ; 43 s et plus avant la correction).
- `name_detector.dart` : `_fichePrenomSuit` extrait d'abord la fenêtre de 300 caractères puis y cherche les
  sauts de ligne (au lieu de `indexOf` sur tout le reste du texte).
- Mesure : 43,6 s → 1,8 s ; fuzz différentiel de 2 000 textes identique avant/après ; banc inchangé octet
  pour octet ; 718 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-51 — Étiquettes décorées en Markdown ou en HTML (`code`)

Contexte : sonde de 16 présentations (27 octobre 2026) : « **Date de naissance :** 12/03/1950 », « **Nom :** Quenelle »,
« **Né le** 12/03/1950 » laissaient la valeur en clair.

- Tests d'abord (17 rouges, avant) ; 5 contre-exemples (`jean_dupont`, `3 * 4`, `__init__`, gras ordinaire, jetons
  `[NOM_1]`) intacts ; restauration identique ; 6 tests de coût (200 000 marques en moins de 10 s).
- `ecluse.dart` : `_vueDeDetection` retire les marques d'emphase (`_decorations`) ; classe de caractères sans
  alternatives qui se recouvrent (une première version avait un retour arrière exponentiel : 50 000 étoiles,
  51 s).
- Mesure : 17 rouges → verts ; banc inchangé octet pour octet ; 747 tests ; 1 Mo d'étoiles en 1,6 s ;
  aller-retour exact sur 3 000 textes aléatoires sans nom.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-52 — Date de naissance derrière une clé de données (`code`)

Contexte : sonde d'exports structurés (27 octobre 2026) : `{"date_naissance": "12/03/1950"}`, `dateNaissance = …`,
`<dateNaissance>…</dateNaissance>` laissaient la date en clair.

- Tests d'abord (18 rouges, avant) : JSON, YAML, XML, paramètres d'URL, clés `date_naissance`, `date-naissance`,
  `dateNaissance`, `birth_date`, `date_of_birth`, `dob`, `ddn`, `naissance` ; 9 contre-exemples (`date_creation`,
  `date_naissance_projet`, `dobby`, `ddns`, valeur non numérique…) intacts ; restauration identique.
- `date_naissance_detector.dart` : séparateur de mots `[ _-]` dans le contexte, `naissance` suivi de `:`/`=`/`>`,
  séparation tolérant guillemets, `=`, `:` et `>`.
- Mesure : 18 rouges → verts ; banc inchangé octet pour octet ; 774 tests ; coût identique à la base.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : nom et prénom en clé de données (clé ambiguë), colonnes d'un CSV à en-tête.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-53 — Nom d'un correspondant dans un en-tête de courriel (`code`)

Contexte : sonde d'en-têtes et de signatures (27 octobre 2026) : « From: Zorglub Quenelle <z@exemple.fr> » ne masquait
que l'adresse quand le prénom n'est pas au gazetteer.

- Tests d'abord (11 rouges, avant) ; 5 contre-exemples intacts ; restauration identique.
- `name_detector.dart` : `_enteteMail` (étiquette d'en-tête en début de ligne + nom + `<`) et `_aEcrit` (nom + `<adresse>`
  + « a écrit »/« wrote »), mots-clés d'établissement exclus.
- Mesure : 11 rouges → verts ; banc inchangé octet pour octet ; 790 tests ; coût identique à la base.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : signatures, destinataires suivants d'une liste, nom d'affichage sans chevrons.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.
