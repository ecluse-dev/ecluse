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
7. **Web non visé** pour l'instant (SDK JS/TS en phase 3). `ecluse_redact`
   n'importe pas `dart:io` pour cette fonction : la référence est fournie par
   l'appelant.
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
