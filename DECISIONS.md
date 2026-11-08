# Journal des décisions

Trace écrite des choix structurants, pour ne pas re-débattre avec
soi-même et éclairer les contributeurs.

## 2026-06 — Dart d'abord, Rust plus tard
Vélocité solo > pureté d'architecture. Le cœur pourra migrer en Rust
derrière la même API quand le revenu justifiera la complexité.

## 2026-06 — Licence Apache 2.0
Permissive, patent grant rassurant pour les juristes d'entreprise,
compatible open-core. MIT écarté (pas de patent grant), AGPL écartée
(freine l'adoption B2B).

## 2026-06 — Détection stricte (clé validée ou rien)
Les détecteurs ne retournent que des entités structurellement validées.
Faux positifs ≈ 0 est l'argument du futur benchmark vs Presidio.
La confiance graduée existe dans l'API pour les détecteurs futurs
(NER local) qui ne pourront pas valider structurellement.

## 2026-06 — Zéro communication avant preuve
Pas d'annonce publique tant que le benchmark vs Presidio n'est pas
publiable. Premier post = chiffres en main.

## 2026-10 — Specs de phase 1 : décisions prises sur recommandation de l'agent
Décisions rédigées par un agent à la demande du mainteneur (« selon tes
recommandations »), à relire à la fusion. Chaque point renvoie à sa spec
dans `agent/specs/`. Ce qui ne peut pas être tranché sans source externe
est marqué **ouvert**.

### ADELI (`P1-06-adeli.md`)
- Type `EntityType.adeli` ajouté, émis **uniquement avec le mot « ADELI »**
  à proximité ; sans mot-clé, `FinessDetector` continue de masquer les
  nombres Luhn-valides.
- Priorité à `adeli` sur `finess` pour un même span quand le mot-clé est
  présent.
- **Ouvert** : structure, clé de Luhn et règle de la lettre corse à
  confirmer sur la fiche officielle de l'ASIP avant tout code.
- **En tension avec « Détection stricte »** : masquer à confiance 0,6 un
  numéro à clé invalide mais étiqueté « ADELI » déroge à « clé validée ou
  rien ». Retenu à titre d'exception documentée (un champ explicitement
  étiqueté qui fuit est pire qu'un sur-masquage), **à confirmer
  explicitement**.

### Secrets (`P1-07-secrets.md`)
- Périmètre étendu aux secrets (clés d'API, jetons, clés privées PEM,
  chaînes de connexion avec mot de passe).
- Un seul `EntityType.secret`, détecteur de tier `pattern`.
- Comportement par défaut : masquer + avertissement ; mode strict optionnel
  qui refuse. Restauration désactivée par défaut pour ce type.
- Chaîne de connexion : masquer `utilisateur:motdepasse`.
- Pas de détection par entropie en v1.
- **Ouvert** : liste finale des fournisseurs ; licence de la source de
  motifs (gitleaks) à confirmer avant toute réutilisation (motifs à
  réécrire par nous dans tous les cas).
- **En tension avec « Détection stricte »** : aucun secret n'a de clé de
  contrôle vérifiable ici ; la confiance est celle d'un motif, comme pour
  le téléphone et l'email.

### Audit (`P1-08-audit.md`)
- **Pas d'empreinte du texte** en v0 (HMAC éventuel en v1, jamais de hash
  simple).
- Horodatage **à la minute**, sans identifiant utilisateur.
- Nouveau paquet `ecluse_audit` ; la bibliothèque ne stocke rien.
- Dépendance de hachage (`package:crypto`) **autorisée sous réserve** de
  confirmer sa licence ; elle n'est ajoutée que par la tâche de code
  correspondante.
- Ancrage externe et signature de la tête de chaîne : hors v0, à ouvrir en
  v1.
- **Ouvert** : validation par un DPO que le journal n'est pas une donnée
  personnelle ; ce n'est pas un avis juridique.

### PDF (`P1-09-pdf.md`)
- `pdf_graphics` retenu comme candidat, derrière une interface interne
  remplaçable, **sous réserve** d'un audit de ses licences transitives et
  d'un essai sur PDF synthétiques. Aucune dépendance ajoutée par cette
  décision.
- PDF mixte (pages texte et pages image) : **refus du document entier**.
- Métadonnées, annotations et formulaires : avertissement explicite s'ils
  existent et ne sont pas extraits.
- Seuils de départ : 20 caractères alphanumériques par page, 100 % des
  pages non blanches, 5 % de caractères parasites, plafond de taille de
  50 Mo ; **à calibrer** sur PDF synthétiques avant fusion. Plafonds de
  pages et de durée : **ouverts**.

### FINESS (`P1-03-finess.md`)
- Piste « contexte obligatoire » écartée (rappel 66,7 %).
- Avant toute correction : enrichir le corpus (SIREN sans mot-clé, phrases
  mêlant FINESS et SIREN), puis mesurer.

## 2026-10 — Réponses du mainteneur aux points ouverts des specs
Complète et remplace, là où ils se contredisent, les points « ouverts » de
l'entrée « Specs de phase 1 » ci-dessus. Les sources non lues par l'agent
restent signalées comme telles.

### ADELI
- Structure : 9 caractères (2 département, 2 profession, 4 numéro
  d'enregistrement, 1 clé). La clé est de type Luhn selon une fiche ASIP/ANS ;
  ni cette fiche ni App'Ines ne donnent l'algorithme (on applique Luhn, à
  re-vérifier si une source officielle le contredit).
- **Numéro corse** (lettre `2A`/`2B` dans les deux premiers caractères) :
  **pas de validation de clé** tant que la règle n'est pas écrite. Précédé du
  mot « ADELI », il est masqué sans validation.
- `EntityType.adeli` dans l'API publique d'`ecluse_core` : **confirmé**.
- Exception à « Détection stricte » (confiance 0,6 pour un numéro à clé
  invalide) : **confirmée uniquement quand le mot « ADELI » est accolé au
  numéro**.

### Secrets
- Motifs de gitleaks : licence MIT d'après deux sources secondaires, fichier
  `LICENSE` du dépôt non lu. Motifs réécrits par nous dans tous les cas.
- Fournisseurs de la v1 : jetons GitHub, identifiants d'accès AWS (préfixés),
  clés OpenAI et Anthropic, clés Google (`AIza…`), jetons Slack, clés Stripe
  live, blocs de clé privée PEM, chaînes de connexion avec mot de passe.
  Les préfixes viennent de la connaissance du mainteneur, pas d'une
  vérification du jour : la tâche cite la source de chaque format.
- Exception à « Détection stricte » : **confirmée** pour les formats à
  préfixe spécifique uniquement ; ni détection par entropie, ni clé AWS
  secrète nue.

### Journal d'audit
- `package:crypto` : BSD-3-Clause, **approuvé** pour un nouveau paquet
  `ecluse_audit`.
- Avis d'un DPO : nécessaire **avant d'affirmer publiquement** que le journal
  n'est pas une donnée personnelle, pas pour coder.

### PDF
- `pdf_graphics` : **approuvé**, version **fixée exactement**. Dépendances
  directes permissives (`bidi` et `image` en MIT, `pdf_cos` et `pdf_document`
  en Apache-2.0) ; les dépendances de `bidi` ne sont pas auditées.
- Plafonds de départ, à calibrer sur les PDF synthétiques de P1-18 : 50 Mo,
  200 pages, 30 secondes, refus avec motif au-delà (valeurs proposées, non
  sourcées).

### Estimation de ré-identification
- Communes homonymes : l'API doit **signaler l'ambiguïté** et ne jamais
  renvoyer « faible » ; prendre le cas le plus prudent (plus petite
  population parmi les candidates) ou « indéterminé ».
- Fichier `DATA_SOURCES.md` à créer : URL, date de téléchargement et licence
  **lue sur la page du jeu de données**, pour chaque fichier embarqué.

### NIR, mois fictifs
- Source citée par le mainteneur : nomenclature DGFiP (annexe 2, via l'AMUE)
  et Wikipédia : `00` et `20` à `30` (mois inconnu), `31` à `42` (mois connu
  codé +30), `50` et suivants (mois inconnu). L'instruction INSEE n'a pas été
  lue. Le code accepte `01-12, 20, 30-42, 50-99` : il faut ajouter `00` et
  `21-29` (la clé mod 97 filtre les faux positifs), test d'abord.

### Divers
- Résultats du benchmark des entités floues : à ajouter au README du
  benchmark, dans un tableau séparé, avec les mêmes mises en garde.
- Avant publication de l'article : mesurer Presidio avec des reconnaisseurs
  NIR/RPPS écrits à la main (c'est l'objection prévisible d'un lecteur).
  « 18,9 % » = Presidio en configuration par défaut, à dire dès le chapeau.
- Dependabot : #7 et #8 à fusionner si la CI passe ; #18 (melos 6.3.3 →
  8.9.0, saut majeur) à tester en local avant fusion. PR #10 et #11 : ne pas
  y toucher.


## 2026-10 — Petits points de la phase 2 (validés par le mainteneur)
Points validés explicitement (« ok pour les petits points »). Les autres
avis échangés (décisions de P2-01, P2-03, P2-05, valeurs de P2-04) **ne sont
pas des décisions** tant que le mainteneur ne les a pas validés un par un.

- **Seuil de 5 points de fuite (P2-01)** : conservé comme valeur de départ,
  **provisoire** jusqu'au test GO/STOP en local. Le motif avancé (« plus de
  trois fois l'écart entre graines, 0,6 à 1,5 point ») n'a pas été retrouvé
  dans le dépôt : à mesurer et à documenter avant de s'en servir.
- **`packages/ecluse_bench/pubspec_overrides.yaml`** : le fichier versionné
  contient un chemin Windows (`..\ecluse_core`) qui casse `dart pub get` sous
  Linux. Décision : une tâche `code` le retirera de git (`git rm --cached`) ;
  `.gitignore` l'exclut déjà. Melos le régénère.
- **Décompte de la civilité** : le script qui produit le chiffre sera
  versionné dans `bench/`. Un chiffre sans commande reproductible ne figure
  pas dans l'article.
- **P2-06 à P2-10** : à copier dans la file après relecture ; P1-00 et P1-12
  restent `humain`.
- **P2-03b (#75)** : une population légale nulle, ou plusieurs
  quasi-identifiants du même type, rendent le document « non évaluable »
  (comportement déjà livré).

## 2026-10 — Préconisations des specs P2-01, P2-03 et P2-05 validées par délégation
Le mainteneur a demandé à l'agent de **valider ses propres préconisations**
pour que le travail continue (message du 25 octobre 2026). Ce sont donc des
choix de l'agent, pris sur la base des specs et **révocables** : ils ne
valent pas relecture par le mainteneur. Ce qui dépend d'une source externe ou
d'une mesure reste **ouvert** (dernière rubrique).

### P2-03 — branchement de `ecluse_reid` (`agent/specs/P2-03.md` § 8)
1. **A puis B.** Livrer d'abord le rapport de risque seul : `Ecluse.redact`
   ne change pas le texte envoyé. La généralisation (B) viendra plus tard,
   appliquée explicitement par l'appelant ; elle est irréversible et ne se
   déclenche jamais d'elle-même. Les suggestions positionnées d'A ne sont pas
   livrées dans P2-04 (non nécessaires au rapport).
2. **Désactivée par défaut**, référence fournie par l'appelant. Sans elle, la
   sortie d'`Ecluse.redact` est octet pour octet celle d'avant.
3. **Document de plusieurs personnes** : « non évaluable » avec motif, comme
   l'évaluation livrée en P2-03b (plusieurs QI du même type, population
   nulle). Limite : plusieurs personnes de QI de types différents ne sont pas
   détectées comme telles et s'évaluent ensemble ; le rapport le dit.
4. **Seuil** : *Standard* seul (F ≥ 10), valeur à confirmer avec les design
   partners.
5. **« Aucun QI détecté »** : jamais « sûr » ni « faible » ; le libellé de
   `Evaluation` (« ce n'est pas un risque faible, c'est une absence
   d'évaluation ») est conservé.
6. **Dépendances internes** : `ecluse_redact` peut dépendre d'`ecluse_reid` et
   d'`ecluse_reference` (paquets du monorepo, aucune dépendance externe).
7. **Web non visé** pour l'instant (SDK JS/TS en phase 3). La référence est
   fournie par l'appelant, mais `ecluse_reference` exporte `file_assets.dart`
   (`dart:io`) : en important `ecluse_reid`, `ecluse_redact` tire `dart:io`
   dans son graphe. Isoler `dart:io` reste à faire avant tout portage web
   (constaté en P2-04).
8. **Brancher maintenant**, sans NER, en affichant le rappel limité dans le
   rapport.

### P2-05 — pseudonymes cohérents par dossier (`agent/specs/P2-05.md` § 10)
1. **Dossier** : notion de l'application cliente (D1, D2 ou D3 selon son
   usage). La bibliothèque ne la définit pas ; elle reçoit un objet « dossier »
   créé et fermé par l'appelant.
2. **État perdu ou redémarrage** : l'état reste en mémoire, jamais sérialisé.
   Un dossier fermé ou perdu **se signale** par un refus explicite avec motif ;
   jamais de restauration partielle ou silencieuse.
3. **Noms entre documents** : N1 (fusion seulement si l'identité complète est
   identique, deux segments au moins).
4. **Menace** : T1 reste une hypothèse de travail, non confirmée.
5. **Cloisonnement** : C0 (état et numérotation propres à chaque dossier). C1
   et C2 sont reportés tant que T1 n'est pas confirmée.
6. **Jeton littéral dans un texte ultérieur** : avertir (`warnings`) ; le texte
   n'est pas modifié ; la restauration de ce jeton littéral n'est alors pas
   octet pour octet, et l'avertissement le dit.
7. **API** : objet « dossier » en paramètre optionnel de `redact` ; sans lui,
   comportement inchangé.
8. **Concurrence** : appels d'un même dossier sérialisés (file d'attente), pas
   de refus.

### P2-01 — NER local (`agent/specs/P2-01.md` § 7)
- **NER en option**, hors de `Ecluse.defaultDetectors`, tant que le critère
  GO/STOP n'est pas validé (règle 7) ; paquet séparé, aucune dépendance
  Flutter dans `ecluse_core`.
- **Modèle** : téléchargement explicite avec empreinte vérifiée, jamais
  silencieux ; poids hors du dépôt.
- Les seuils restent ceux de la spec, **provisoires** jusqu'au test en local.

### Reste ouvert (non validé)
- Modèle de PC et de téléphone de référence (latence, mémoire).
- **Licence des poids** du NER : à lire sur la page du modèle.
- Confirmation de la menace T1 et du choix C0, C1 ou C2.
- Valeurs de P2-04 à confirmer avec les design partners (seuil).

## 2026-10 — Règle de noms entre documents : N3 (P2-13)
Après la mesure de P2-06 (cohérence des noms en baisse avec N1), le mainteneur
a demandé N3 : N1 reste le **défaut**, N2 (fusion par inclusion) est activable
par l'application à la création du `Dossier`
(`RegleNoms.inclusion`). Le choix du défaut n'est pas modifié ; les mesures de
N1 et N2 sont dans `LIMITES.md` § 5.3 et dans la PR P2-13.

## 2026-10 — Préconisations des specs P2-07, P2-08 et P2-09 validées par délégation
Le mainteneur a demandé formellement à l'agent de valider ses propres
préconisations (message du 26 octobre 2026). Ce sont des choix de l'agent,
**révocables**, qui ne valent pas relecture par le mainteneur. Tout ce qui
dépend d'une source externe, d'une lecture de licence ou d'un avis juridique
reste **ouvert** (dernière rubrique).

### P2-07 — généralisation multi-dimensions (`agent/specs/P2-07.md` § 8)
1. **v1 : date de naissance et âge seulement.** La pathologie est renvoyée à une
   tâche ultérieure (ni extracteur, ni table, ni corpus annoté, rappel
   dépendant d'un lexique).
2. **Le masquage de la date de naissance n'est jamais relâché par défaut.**
   Envoyer une année ou une tranche d'âge à la place du jeton est une option
   explicite de l'appelant, irréversible, jamais déclenchée par le moteur.
3. **Date de référence injectée par l'appelant** pour dériver un âge d'une date
   (aucune horloge système dans le calcul).
4. **Palier « 85+ »** ajouté pour les grands âges ; échelle des dates :
   mois/année, année, décennie, retrait.
5. **Seuil : *Standard* seul** en v1 (cohérent avec la décision P2-03 n° 4).
6. **v1 = suggestions seulement** ; l'application explicite d'une suggestion est
   une fonction appelée par l'application (option B de P2-03).
7. **Dates d'événement : hors périmètre.**

### P2-08 — aperçu avec validation en un clic (`agent/specs/P2-08.md` § 7)
1. **Dans `ecluse_redact`** (le composant a besoin de l'état de masquage et de la
   résolution des chevauchements) ; `ecluse_core` inchangé.
2. **Deux temps** : proposer (pur), puis appliquer.
3. **Refus** : interdit par défaut pour les entités structurelles
   (`tier = structural`) et pour les secrets ; l'appelant peut l'autoriser par une
   option explicite pour les entités structurelles, **jamais** pour les secrets.
4. **Ajouts manuels** : tout type sauf `secret` ; un ajout qui recouvre entièrement
   des détections les remplace ; un chevauchement partiel est une **erreur
   explicite** ; un ajout inclus dans une détection est refusé (redondant) ;
   provenance marquée « manuelle ».
5. **Trace d'audit** : rien en v1 (aucune modification d'`ecluse_audit`).
6. **Liaison au texte** : comparaison du texte d'origine complet, pas de condensat
   (la proposition le contient déjà) ; aucune dépendance de hachage ajoutée.
7. **Rapport de risque** : inclus dans la proposition quand l'appelant fournit une
   référence.
8. **Libellés** : laissés à l'application ; la bibliothèque fournit les comptes par
   type.
9. **`refuseSecrets`** refuse **avant** toute proposition (rien n'est affiché).
10. **Fichiers** : l'aperçu porte sur le texte extrait, avec l'avertissement du § 5.5
    de la spec.

### P2-09 — export AIPD (`agent/specs/P2-09.md` § 8)
1. **Objet** : matière première factuelle pour le registre des activités de
   traitement et pour l'AIPD ; pas l'outil PIA de la CNIL.
2. **Périmètre** : uniquement le contenu du § 4 de la spec ; aucune rubrique vide à
   remplir, pour ne pas être pris pour un registre.
3. **Format** : JSON structuré et texte lisible ; le tableur au format de la CNIL
   seulement après lecture du modèle.
4. **Seuil d'agrégation (provisoire)** : tout compte par type inférieur à 5 est
   remplacé par la mention « moins de 5 » ; quand le nombre d'opérations est
   inférieur à 5, la période est donnée au jour et non à la minute.
5. **Code dans `ecluse_audit`**, en lecture seule des entrées ; aucune écriture.
6. **Mentions d'honnêteté dans la sortie elle-même**, jamais omises.
7. **Estimation de ré-identification : non journalisée** (hors périmètre).

### Reste ouvert (non validé)
- **Source de la table de catégories de pathologies** et lecture de sa licence sur la
  page d'origine (P2-07 n° 4 de la spec) : aucune page n'a pu être lue.
- **Avis d'un DPO** sur la nature du journal et sur la publication de l'export
  (P2-09 n° 7 de la spec) ; l'export n'est pas publié avant son retour.
- **Lecture du gabarit de registre de la CNIL** et du texte des articles 30 et 35 du
  RGPD (P2-09) : pages injoignables depuis l'environnement d'exécution.
- Seuil d'agrégation de l'export (5) et palier « 85+ » : à confirmer avec les design
  partners.

## 2026-10 — Arbitrages du mainteneur du 27 octobre (14 questions)

Réponses données une à une, avec les conséquences de chaque choix exposées. Les
arbitrages qui demandent du travail sont devenus les tâches P2-59 à P2-64 de
`agent/QUEUE.md` ; les autres confirment l'état du code.

**À réaliser**

- **Identifiants : un type par catégorie** (question 1). `identifiant` est scindé
  (dossier ou numéro administratif, document d'identité, véhicule, réseau) : P2-59.
- **Téléphones étrangers : pays voisins et Maghreb** (question 5) : P2-60.
- **Exports structurés : clés explicites et CSV à en-tête** (question 7). La clé
  nue « nom » reste exclue ; refus explicite si le CSV est ambigu : P2-61.
- **IBAN de l'espace SEPA avec clé mod 97** (question 8), dans `ecluse_core` ; le BIC
  reste non traité : P2-62.
- **Tableaux HTML et titres Markdown** (question 9), dans la vue de détection
  seulement : P2-63.
- **Optimiser la résolution des pseudonymes** au-delà de ~50 000 mentions
  (question 12), avec test différentiel complet avant/après : P2-64.

**Confirmés (aucun travail)**

- Étiquettes de rôle « Patient : », « Résident : »… avec au moins 2 mots (question 2, P2-55).
- Adresse sans code postal, telle quelle (question 3, P2-56).
- Saut de ligne dans un identifiant numérique conservé (question 4, P2-38).
- Étiquettes génériques « Contact », « Tuteur », « Représentant légal »,
  « Destinataire » : non traitées (question 6).
- E-mails à IP littérale ou à partie locale avec espace : non traités (question 10).
- Sur-masquages connus : acceptés, en cas de doute on protège (question 11).
- Tests de coût chronométrés : gardés, bornes larges ; un rouge sporadique est
  relancé une fois avant conclusion (question 13).
- P2-10, P1-00 et P1-12 : laissées en l'état (question 14).

## 2026-11 — P2-10 : transcription vocale locale (arbitrage délégué)

Le mainteneur a délégué l'arbitrage à l'agent (1er novembre 2026). Détail,
sources et niveaux de vérification dans `agent/specs/P2-10.md`.

- **Moteur retenu : whisper.cpp** (code et poids sous licence MIT, lus sur les
  README). Vosk reste le repli : sa sortie en minuscules risquerait de contourner
  les détecteurs de noms, qui s'appuient sur la capitalisation.
- **Mode** : enregistrement puis transcription, sans flux. Paquet séparé
  (`ecluse_voice`), jamais dans `ecluse_core`.
- **Aucun code vocal sur `main`** sans le critère GO/STOP du § 7 de la spec
  (test d'absence de réseau, licences lues, rappel et fuite des chiffres mesurés
  sur audio synthétique) validé par le mainteneur.

## 2026-11 — Arbitrages du mainteneur du 3 novembre (P2-87, P2-96a)
Réponses données par le mainteneur lui-même, le 3 novembre 2026.

### P2-87 — Seuils du critère GO/STOP du NER (`agent/specs/P2-01.md` § 7)
- Seuils **validés tels que proposés** : baisse de la fuite au caractère d'au
  moins 5 points, au plus 1 % des documents du corpus témoin avec une
  détection, modèle quantifié d'au plus 300 Mo sur disque, au plus 2 s au
  95e centile pour un document de 1 000 mots.
- **Machine de référence** : le PC de développement du mainteneur (MSI,
  Windows). Les mesures de latence et de mémoire s'y font.
- La condition STOP n° 2 (licence des poids ou des données illisible) reste
  entière : voir `agent/specs/P2-86.md` § 2.2.

### P2-96a — Branchement d'`ecluse_audit` (`agent/specs/P2-95.md` § 7)
1. **Option A** : un objet `JournalAudit` (paquet `ecluse_audit`) passé en
   option à `Ecluse.redact`, qui écrit après le masquage et avant de rendre
   le résultat. Sans journal, la sortie ne change pas.
2. **`package:crypto` accepté** dans le graphe d'`ecluse_redact`, par la
   dépendance interne à `ecluse_audit` (licence BSD-3-Clause déjà approuvée).
3. **Refus de secrets journalisé** : nouvelle opération `secrets_refused`,
   donc **schéma version 2**. Les entrées de version 1 restent vérifiables
   telles quelles.
4. **Description du moteur construite par Écluse** à partir des détecteurs
   actifs, pas fournie par l'application.

## 2026-11 — Fin de la phase 2 : SDK Python et chatbot reportés (5 novembre)
Décision du mainteneur, sur proposition de `agent/specs/P2-decoupage-fin.md`
§ 3 et § 5 (question 1).
- Le **SDK Python** passe en phase 3, avec le SDK JS/TS et les adaptateurs
  Presidio et LiteLLM : il relève de la distribution, pas de la profondeur
  de détection.
- Le **chatbot de support « propulsé par Écluse »** passe en phase 3, après
  l'offre cloud : il dépend d'un LLM tiers et n'apporte rien avant.
- La phase 2 se termine donc avec le NER (GO ou STOP), la généralisation
  appliquée, le journal d'audit branché, le vocal (GO ou STOP) et le
  routage on-device / cloud.

## 2026-11 — Vérificateur LLM : arbitrages P2-104a (5 novembre)
Réponses du mainteneur aux décisions de `agent/specs/P2-104.md` § 6 et de
`agent/specs/P2-106.md` § 4.
- **Seuils validés tels que proposés** : au moins 50 % des indices trouvés,
  au plus 2 % de fausses alertes sur le témoin, au plus 1 % de documents
  « non vérifié », au plus 10 points d'écart sous injection, modèle quantifié
  d'au plus 2 Go, au plus 10 s au 95e centile pour 1 000 mots.
- **Un indice trouvé par le vérificateur est signalé, pas masqué d'office** :
  il s'affiche dans l'aperçu et l'utilisateur décide.
- **Licence des données d'un LLM : règle de transparence.** Poids sous
  licence permissive lue chez l'éditeur, et liste publique des jeux
  d'entraînement, chaque jeu consultable. La règle stricte de P2-01 (licence
  de chaque jeu lue) reste celle du NER tant que le mainteneur n'en décide
  pas autrement.
- **Ordre** : le corpus de fuites sémantiques se construit maintenant
  (P2-105) ; la mesure attend la décision sur le NER (P2-90).

## 2026-11 — P2-94 : source de la table pathologie → catégorie (5 novembre)
Décision du mainteneur sur la proposition de `agent/specs/P2-94.md` § 4.
- **Maladies rares : Orphadata Science** (CC BY 4.0), sous deux conditions :
  licence lue sur le site d'Orphadata (**remplie le 5 novembre 2026**, voir
  `agent/specs/P2-94.md` § 7) et libellés disponibles en français
  (**remplie le 5 novembre 2026** sur le pack de nomenclature français 2026
  fourni par le mainteneur, voir `agent/specs/P2-94.md` § 8). Le fichier
  n'est pas versionné ; son intégration reste une tâche à part.
- **Pathologies fréquentes : table écrite par le projet**, à partir des
  intitulés de la liste des ALD, avec validation clinique par le mainteneur
  (proposition : `agent/specs/P2-94-table.md`).
- **CIM-10 française exclue** (CC BY-NC-ND) ; CIM-11 non retenue sans lecture
  de ses conditions détaillées.

## 2026-11 — P2-113 : intégration d'Orphanet (5 novembre)
Décisions prises **par délégation** (« je te laisse prendre les meilleures
décisions »), sur la proposition de `agent/specs/P2-113.md` § 6. Le
mainteneur peut les revoir ; la liste blanche relève de son jugement
clinique.
- **Sigles : option B.** Les mentions de quatre caractères ou moins sont
  retirées, sauf une liste blanche réduite à **« SLA »**. Toute autre entrée
  dans la liste demande un cas de corpus qui montre le besoin (règle 5).
- **Priorité : la table maison prime** sur Orphanet pour ses propres
  mentions (mucoviscidose, drépanocytose, tuberculose…), parce qu'elle
  reflète la fréquence en France.
- **Extraction : feu vert.** `tools/build_orphanet_asset.py` produit
  `patho_orphanet.tsv.gz` dans `ecluse_reference/assets`, sous CC BY 4.0 avec
  attribution (`NOTICE`, `DATA_SOURCES.md`). Le chargement côté Dart et
  l'appariement sont une tâche à part (P2-115).

## 2026-11 — P2-110 : table des pathologies fréquentes validée (7 novembre)
Réponses du mainteneur aux points de `agent/specs/P2-94-table.md` § 4.
- **Systèmes** : les douze systèmes sont suffisants pour le médico-social.
- **Abréviations** : « AVC » et « BPCO » gardés ; « SEP » reste écarté
  (sens multiples, choix de P2-112 confirmé).
- **Pathologies hors liste ALD** (obésité, hypertension, troubles du spectre
  de l'autisme, trisomie 21, handicap psychique) : **hors table**.
- **Seuil** : *Standard* seul pour la pathologie.
- **Conséquence** : la table et les formes adjectivales ne sont plus
  « provisoires » (`tablePathologies`, `formesAdjectivales`).

## 2026-11 — P2-143 : seules les maladies rares sont masquées (7 novembre)
Décision du mainteneur : « les pathologies rares sont les seules à cacher ».
- **Maladies rares** : masquées par un jeton réversible `[MALADIE_RARE_n]`
  quand l'application passe le catalogue Orphanet (`maladiesRares:`).
- **Pathologies fréquentes** : en clair, signalées par le rapport de risque,
  généralisables sur demande (inchangé).

Précisions prises **par délégation** (à relire, `agent/specs/P2-143.md`) :
- Une mention de la table maison qu'Orphanet connaît aussi (mucoviscidose,
  drépanocytose, phénylcétonurie, maladie de Gaucher) est rare ; la table
  prime pour la catégorie (P2-113), pas pour la rareté. **Exceptions** :
  tuberculose et bilharziose, infections courantes dans le médico-social.
- Une mention de la table suivie d'un éponyme (« myopathie de Duchenne »)
  est rare.
- Masquée si rattachée à une personne, **ou** si le texte nomme quelqu'un ;
  jamais si elle est niée, ni dans un texte sans nom de personne.
- Opt-in par le catalogue : sans lui, la sortie d'`Ecluse.redact` est
  inchangée (le catalogue se charge de façon asynchrone).

## 2026-11 — P2-144 et P2-145 : casse et dossiers (7 novembre)
Demandes du mainteneur : analyser et corriger les noms non détectés en
minuscules (P2-140), mesurer un dossier à casse mixte.
- **Patronyme repris seul** en minuscules ou capitales, comme en casse
  ordinaire (P2-14) : même sur-masquage assumé d'un mot courant homonyme.
- **Civilité de genre en clair** en minuscules et en capitales, par
  délégation (`agent/specs/P2-144.md`) : cohérence avec la casse ordinaire et
  un seul jeton par personne quelle que soit la casse. Le chiffre de fuite
  en minuscules monte (2,2 % → 30 % sur les noms) par la seule civilité.

## 2026-11 — P2-101 : Melos 8 et workspace pub (7 novembre)
Le mainteneur a demandé à l'agent de faire la migration lui-même.
- Configuration de Melos dans le `pubspec.yaml` racine (`melos:`), workspace
  pub (`workspace:`, `resolution: workspace`) ; `melos.yaml` supprimé.
- **Plancher SDK relevé** : racine Dart 3.9 (minimum de Melos 7 et 8), packages
  Dart 3.6 (minimum d'un membre de workspace), au lieu de 3.3. `CLAUDE.md`
  dit encore « SDK ≥ 3.3 » : à mettre à jour par le mainteneur (zone
  interdite aux agents).
- La CI n'est pas modifiée : `dart pub global activate melos` délègue à la
  version locale du workspace. Les commandes de `CONTRIBUTING.md` sont
  inchangées.
- La PR dependabot #243 devient sans objet.

## 2026-11 — P2-99 et P2-109 (7 novembre)
- **P2-99 : whisper.cpp dans un dépôt à part**, pas dans le monorepo. La
  règle 6 (« pas de dépendance native dans `ecluse_core` ») et une CI sans
  chaîne de compilation C++ restent intactes ; la transcription locale, si
  elle passe son GO/STOP, sera un paquet séparé qui dépend d'Écluse, pas
  l'inverse. Le dépôt n'est pas créé tant que le GO/STOP vocal n'est pas
  tranché.
- **P2-109** : corrigé sur la branche `feat/llm-scaffold` (#330), qui reste
  non fusionnée dans `main` : `VerificationStatus.nonVerifie` et un motif sur
  échec d'analyse, troncature ou réponse coupée ; `isClean` exige un texte
  vérifié.

## 2026-11 — Réponses du mainteneur du 7 novembre (questions 12 à 16)
Corrigé le 8 novembre : une première version attribuait ces réponses aux
mauvaises questions.
- **12. Doublons table maison / Orphanet** (la table maison l'emporte,
  P2-113) : « pas pour le moment ». **Non confirmé.** Le code applique
  toujours la priorité de la table pour la catégorie ; pour le masquage
  (P2-143), la mention qu'Orphanet connaît reste traitée comme rare
  (mucoviscidose, drépanocytose, phénylcétonurie, maladie de Gaucher).
- **13. Pathologies sans score** : confirmé. Signalées et généralisables
  sur demande, jamais comptées dans le score de risque.
- **14. Exceptions** (`AdresseDetector` en capitales, P2-122 ; préposition
  réécrite devant un département, P2-132) : réponse « les pathologies rares
  sont les seules à cacher », appliquée par P2-143. Les deux exceptions
  restent en place.
- **15. Démo** : `ecluse_demo` dépend de `ecluse_reference`, paquet interne
  (P2-141) : confirmé.
- **16** : « ok » ; énoncé à retrouver avec le mainteneur.
- La liste blanche des sigles Orphanet reste « SLA » seule (P2-113), sans
  réponse du mainteneur sur ce point.
