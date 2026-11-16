# Archive des fiches — Écluse

Fiches des tâches au statut `fusionnée`, déplacées de `agent/QUEUE.md` pour alléger la lecture des agents. Le tableau des tâches reste complet dans `QUEUE.md`. Contenu inchangé.

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

**Déblocage** : le mainteneur a délégué l'arbitrage à l'agent le 1er novembre 2026.
Spec livrée dans `agent/specs/P2-10.md` (choix tranchés au § 8, GO/STOP au § 7).

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

### P2-54 — Nom de signature sous une formule de clôture (`code`)

Contexte : sonde de signatures (27 octobre 2026) : « Cordialement,⏎Zorglub Quenelle » laissait le nom en clair quand le
prénom n'est pas au gazetteer (non traité de P2-53).

- Tests d'abord (10 rouges, avant) ; 9 contre-exemples intacts (même ligne, structures, articles, adresse) ; restauration identique.
- `name_detector.dart` : `_signature` (formule de clôture seule sur sa ligne + nom seul sur la suivante), `_motsStructure`,
  rejet des lignes de trois mots tout en majuscules.
- Mesure : 10 rouges → verts ; banc inchangé octet pour octet ; 810 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : signature sans formule, nom suivi d'une fonction sur la même ligne.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-55 — Nom derrière une étiquette de rôle sans ambiguïté (`code`)

Contexte : sonde d'étiquettes (27 octobre 2026) : « Patient : Zorglub Quenelle », « Résident : … », « Médecin traitant : … »
laissaient le nom en clair quand le prénom n'est pas au gazetteer. Reprend sous forme bornée le point laissé au mainteneur en P2-41.

- Tests d'abord (15 rouges, avant) ; 10 contre-exemples intacts + 3 établissements (jamais `NOM`) ; restauration identique.
- `name_detector.dart` : `_etiquetteRole` (étiquettes de rôle + 2 à 3 mots en majuscule initiale), `_nonNoms`, établissements exclus.
- Mesure : 15 rouges → verts ; banc inchangé octet pour octet ; 838 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : un seul mot après l'étiquette ; « Contact », « Tuteur », « Représentant légal », « Destinataire ».
- Révocable : retirer `_etiquetteRole` de la boucle de `detect`.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-56 — Adresse sans code postal (`code`)

Contexte : sonde d'adresses (27 octobre 2026) : « 12 rue des Lilas », « 27 boulevard Haussmann » restaient en clair
(limite « adresse sans code postal » connue de `adresse_detector.dart`).

- Tests d'abord (11 rouges, avant) ; 9 contre-exemples intacts ; restauration identique.
- `adresse_detector.dart` : `_patternSansCodePostal` (numéro + type de voie + nom de 1 à 5 mots), en dernier, sans chevauchement
  des adresses déjà retenues (recherche dichotomique, pas de balayage quadratique).
- Test modifié : `adresse_multiligne` cas 4 attend maintenant deux adresses (voie, commune) au lieu d'une.
- Mesure : 11 rouges → verts ; banc inchangé octet pour octet ; 861 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : nom de voie en minuscules, ville seule, lieu-dit sans numéro.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-57 — Identifiants étiquetés : type `identifiant` (`code`)

Contexte : sonde d'identifiants (27 octobre 2026) : IPP, n° de dossier, de patient, d'adhérent, passeport, CNI, plaque, adresse IP
restaient en clair (17 sur 20), sans type d'entité pour les accueillir.

- Tests d'abord (22 rouges, avant) ; 14 contre-exemples intacts ; restauration identique ; type exposé (`EntityType.identifiant`).
- `ecluse_core` : valeur `identifiant` ajoutée à `EntityType` (seul changement du paquet, aucun détecteur).
- `ecluse_redact` : `IdentifiantDetector` (étiquette obligatoire + valeur ressemblant à un identifiant ; plaque SIV sans étiquette),
  jeton `IDENTIFIANT`, enregistré dans `defaultDetectors`.
- Mesure : 22 rouges → verts ; banc inchangé octet pour octet ; core 168, redact 898, audit 34, ingest 121, reid 134,
  reference 29, demo 37 tests verts ; coût linéaire (10 entrées pathologiques d'1 Mo).
- Un défaut de coût trouvé en cours de mesure (« AB-123- » répété : ~47 s dès 140 Ko, avec ou sans cette règle) venait de P2-53 ; corrigé séparément en P2-58 (fusionnée).
- Aucune dépendance ajoutée.
- Révocable : retirer `IdentifiantDetector` de `Ecluse.defaultDetectors`.
### P2-58 — Coût cubique d'un mot composé très long (`code`)

Contexte : en mesurant P2-57, « AB-123- » répété (140 Ko) prenait 47 s. Bissection : régression de P2-53 (`_aEcrit`),
5 ms avant ; le motif repartait de chaque segment d'un mot composé.

- Test d'abord (2 rouges sur 3 formes, 16 s et 9,9 s) puis correctif ; cas fonctionnel « a écrit » après un nom composé conservé.
- `name_detector.dart` : lookbehind de `_aEcrit` étendu au tiret et à l'apostrophe (début de mot strict).
- Mesure : 36 Ko en 16 s → < 5 s ; ~1 Mo de mots composés en 1,3 à 5,7 s ; banc inchangé octet pour octet ; 865 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-59 à P2-64 — Arbitrages du 27 octobre (`code`)

Fiches courtes ; le détail de chaque choix est dans `DECISIONS.md` (section « Arbitrages du mainteneur du 27 octobre »).
Chaque tâche suit la méthode du dépôt : test qui montre le défaut, correction, mesure avant/après, banc inchangé, tests
de coût, `LIMITES.md` à jour. Une tâche par PR. Les fiches détaillées sont ajoutées par la PR de chaque tâche.

- **P2-59** : `identifiant` devient quatre types (dossier, document d'identité, véhicule, réseau), jetons distincts.
- **P2-60** : +32, +41, +352, +49, +34, +39, +44, +212, +213, +216, avec leurs groupements usuels.
- **P2-61** : clés `nom_patient`, `nom_famille`, `prenom`, `nom_naissance`, `lastname`, `firstname` (JSON, XML, URL) ; en-têtes CSV associés à leurs colonnes ; refus explicite si ambigu.
- **P2-62** : code pays + clé mod 97 + longueur par pays ; BIC non traité.
- **P2-63** : `<td>`, `<th>`, `<tr>` et marques de titre `#` neutralisés dans la vue de détection ; texte jamais réécrit.
- **P2-64** : index des mentions à la place du parcours ; test différentiel complet avant/après sur la restauration.

### P2-60 — Téléphones étrangers : voisins et Maghreb (`code`)

Contexte : arbitrage du 27 octobre (question 5) : détecter +32, +41, +352, +49, +34, +39, +44, +212, +213, +216.

- Tests d'abord (25 rouges, avant) ; 10 contre-exemples intacts ; restauration identique.
- `telephone_detector.dart` : table `_pays` (indicatif, longueur minimale et maximale), indicatif obligatoire, `(0)` facultatif,
  zéro initial admis pour l'Italie.
- Test modifié : `telephone_detector_test` « préfixe 00 non FR » (0044) devient « pays non couvert » (001 202 555 0143).
- Mesure : 25 rouges → verts ; banc inchangé octet pour octet ; 937 tests ; coût linéaire (7 entrées de ~0,9 Mo).
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : autres pays, extensions, numéros sans indicatif.
### P2-59 — Un type par catégorie d'identifiant (`code`)

Contexte : arbitrage du 27 octobre (question 1) : `identifiant` scindé en catégories (voir `DECISIONS.md`).

- Tests d'abord (11 rouges, avant) : un jeton par catégorie (`IDENTIFIANT`, `PIECE_IDENTITE`, `VEHICULE`, `RESEAU`), les 22 + 14 cas de P2-57 inchangés.
- `ecluse_core` : trois valeurs ajoutées à `EntityType` (`pieceIdentite`, `vehicule`, `reseau`) ; `identifiant` conservé pour ne pas casser `ecluse_audit`.
- `ecluse_redact` : `IdentifiantDetector` choisit le type d'après l'étiquette ; jetons dans `tokenizer.dart`.
- Mesure : 11 rouges → verts ; banc inchangé octet pour octet ; core 168, redact 902, audit 34, ingest 121, reid 134, reference 29, demo 37 tests verts.
- Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-62 — IBAN de l'espace SEPA avec clé mod 97 (`code`)

Contexte : arbitrage du 27 octobre (question 8) : étendre l'IBAN au-delà de la France, BIC non traité.

- Tests d'abord : 38 pays générés (BBAN de graine fixe, clé calculée, jamais copiés) en forme compacte et groupée ; rejets (clé fausse, longueur
  fausse, pays hors espace, enchâssement) ; 6 rouges d'intégration dans `Ecluse.redact`.
- `ecluse_core` : `IbanDetector` (table de longueurs par pays, clé ISO 7064) ; `IbanFrDetector` conservé tel quel (API publique).
- `ecluse_redact` : `Ecluse.defaultDetectors` utilise `IbanDetector`.
- Mesure : banc inchangé octet pour octet ; core 212, redact 945, audit 34, ingest 121, reid 134, reference 29, demo 37 tests verts ; coût
  équivalent à la base (≤ +25 % sur 6 entrées d'~1 Mo).
- Aucune dépendance ajoutée.
### P2-61 — Noms en clés de données explicites et tableaux CSV à en-tête (`code`)

Contexte : arbitrage du 27 octobre (question 7) : clés explicites et CSV à en-tête, avec refus explicite si le CSV est ambigu ; la clé nue « nom » reste exclue.

- Tests d'abord (36 rouges : 21 clés, 15 CSV) ; 16 contre-exemples de clés et 7 non-tableaux intacts ; 4 refus explicites ; restauration identique.
- `name_detector.dart` : `_cleDonneeLax` (JSON, XML, paramètres : casse libre, 1 à 4 mots) et `_cleDonneePlain` (`cle: Valeur`, majuscule initiale) ; valeurs vides ou booléennes exclues.
- `tableau_csv.dart` : `cellulesDeNoms` (en-tête reconnu, cellules des colonnes de noms) et `TableauAmbiguException` (ligne et motif, jamais le contenu).
- Mesure : tests rouges → verts ; banc inchangé octet pour octet ; 962 tests ; coût linéaire hors résolution des pseudonymes (100 000 cellules de noms : 29 s, voir P2-64).
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-63 — Tableaux HTML et titres Markdown dans la vue de détection (`code`)

Contexte : arbitrage du 27 octobre (question 9) : tableaux HTML et titres Markdown.

- Mesure d'abord : sur 16 présentations, les titres Markdown (`## Date de naissance⏎12/03/1950`, `### Né le …`) étaient **déjà** traités ;
  `## Nom : Quenelle` reste en clair à cause de la règle « Nom » seul (fiche d'identité requise), non du titre. Les fuites réelles
  sont les balises HTML entre l'étiquette et la valeur et `&nbsp;`.
- Tests d'abord (9 rouges sur 21) ; 6 contre-exemples intacts ; restauration identique.
- `ecluse.dart` : `_vueDeDetection` retire les balises de structure sans attribut libre et pose un séparateur ; `_champNom`, `_champPrenom`,
  date et identifiants lisent U+001F comme `:` ; `tableau_csv.dart` lit U+001E/U+001F comme séparateur de colonnes.
- Vérification de mes propres affirmations : deux défauts trouvés et corrigés (sauts de ligne réels entre `<tr>` qui coupaient le tableau ; première ligne à cellule fusionnée silencieusement non lue, désormais refus explicite).
- Mesure : 9 rouges → verts ; banc inchangé octet pour octet ; 1022 tests ; 10 entrées d'~1 Mo en 0,3 à 1,9 s.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-64 — état des lieux (travail inachevé, branche `claude/p2-64-resolution-lineaire`, sans PR)

- Mesure : 10 000 noms **distincts** (110 Ko) = 43 s ; 10 000 mentions d'un **même** nom = 0,6 s ; 5 000 « Marie X » = 13,5 s. Le coût dépend du nombre
  d'identités distinctes, non du nombre de mentions. La détection ne coûte que 0,5 s : tout est dans la résolution.
- Tentative 1 (faite, insuffisante) : index des identités par segment (`candidats`), au lieu de comparer chaque mention à toutes les identités ;
  10 000 noms distincts : 43 s → 36 s. Ce n'est donc **pas** la cause principale.
- Suspect suivant, non encore mesuré : `_freshToken` compile et applique `tolerantTokenPattern(jeton)` sur **tout le texte** pour chaque nouveau jeton
  (10 000 jetons × 110 Ko). Piste : relever une fois les segments `[...]` du texte (comme `jetonsLitteraux`) et ne tester que ceux-ci.
- Méthode à reprendre : profiler d'abord (une phase à la fois), puis correction, puis fuzz différentiel (script `fuzz` : 300 graines × 2 règles × 3
  documents, sortie de référence calculée sur `main`), puis test de coût (`cout_noms_distincts_test.dart`, déjà écrit, rouge).

### P2-64 — Coût de la résolution des pseudonymes (reprise, `code`)

Suite de l'état des lieux ci-dessus. Cause principale : `_freshToken` appliquait le motif de jeton à tout le texte pour chaque nouveau
jeton ; seconde cause : comparaison de chaque mention à toutes les identités.

- Test de coût d'abord (rouge : 43 s et 13,5 s pour une borne de 10 s), puis deux corrections mesurées séparément.
- `ecluse.dart` : `_zoneCrochets` (segments `[...]` relevés une fois par texte) ; index des identités par segment et par ensemble de segments
  (`candidats`), prédicat exact conservé.
- Équivalence : 3 000 exécutions + 2 000 avec jetons littéraux, identiques à `main` ; banc inchangé octet pour octet ; 1033 tests.
- Mesure : 10 000 noms distincts 37 s → 0,55 s ; « Marie X » ×10 000 14 s → 1,1 s.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-66 — Résolveur de chevauchements linéaire (`code`)

Contexte : en mesurant un tableau de 40 000 rangées (P2-65), `Ecluse.detect` prenait 18 s alors que le détecteur de noms seul en prenait 0,7.
Cause : `resolveOverlaps` comparait chaque candidate à toutes les entités retenues.

- Tests d'abord : équivalence avec l'ancienne implémentation (gardée dans le test) sur 5 000 tirages aléatoires, plus deux tests de coût
  (80 000 entités disjointes, 80 000 entités se chevauchant par paires) rouges avant (14 s et 9,8 s pour une borne de 3 s).
- `ecluse_core` : `resolver.dart` utilise une `SplayTreeMap` triée par début ; seule l'entité retenue qui commence le plus tard avant la fin du
  candidat est examinée. Priorité inchangée. Bibliothèque standard seule.
- Mesure : banc inchangé octet pour octet ; core 215 tests ; tableau CSV de 40 000 rangées 18 s → 2,3 s.
- Aucune dépendance ajoutée.
### P2-65 — Tableaux Word et ODT (`code`)

Contexte : sonde d'ingestion du 1ᵉʳ novembre : les cellules d'un tableau docx ou odt étaient aplaties une par ligne ; les noms d'un tableau
étiquette / valeur ou à en-tête restaient en clair.

- Tests d'abord (11 rouges sur 15, plus 5 rouges sur 9 pour la tabulation) ; contre-exemples (tableau sans colonne de personne, « Nom ⇥ Aspirine »)
  intacts ; restauration identique.
- `ecluse_ingest` : `docx_xml.dart` et `odt_xml.dart` émettent cellules séparées par une tabulation et rangées par un saut de ligne
  (fusion de cellules conservée, tableau imbriqué dans la cellule parente).
- `ecluse_redact` : `name_detector.dart` lit « étiquette ⇥ valeur » comme « étiquette : valeur » pour une rangée de deux champs seulement.
- Mesure : banc inchangé octet pour octet ; ingest 136 tests, redact 1042, core 212, demo 37, audit 34, reid 134.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Constat reporté en P2-66 : le résolveur de chevauchements est quadratique (tableau de 50 000 rangées : 28 s de détection).
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-67 — Formats texte structurés à l'ingestion (`code`)

Contexte : `.csv`, `.tsv`, `.json`, `.html`, `.xml` étaient refusés alors que la détection lit désormais leurs structures (P2-61, P2-63).

- Tests d'abord (compilation rouge, puis 20 tests) ; refus conservés : Windows-1252, UTF-16, binaire déguisé, NUL, `.xlsx`, `.rtf`, `.doc`, `.pptx`.
- `ecluse_ingest` : cinq valeurs de `IngestFormat`, cinq branches du `switch`, motifs de refus mis à jour ; lecture par `ingestPlainText`.
- Mesure : ingest 156 tests, redact 1042, demo 37 ; aucun changement de détection.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Décision de périmètre révocable (retirer la branche du `switch`).
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-68 — Diversité des prénoms du gazetteer (`code`)

Contexte : sonde de 143 prénoms d'origines variées derrière un nom inconnu : 82 manqués.

- Tests d'abord (69 rouges sur 78) ; 8 mots ordinaires écartés testés intacts ; 4 phrases ordinaires intactes.
- `french_first_names.dart` : 68 prénoms ajoutés ; Jan, Jun, Lou, Said, Manuel, Mario, Li, Thi écartés (mots courants).
- Faux positifs : 3 896 textes de corpus synthétiques comparés à `main` ; 32 changent, tous dans « flou adversarial », tous de vrais prénoms.
- Mesure : banc inchangé octet pour octet ; 1120 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : branchement du gazetteer INSEE (sans fréquences, trop de mots courants).
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-69 — Civilités au pluriel, minuscules et majuscules, mots de parenté (`code`)

Contexte : sonde de 26 formules de politesse : 13 laissaient le nom ou le patronyme en clair (dont « Sœur Marie-Pierre Quenelle »), 12 sont traitées (« Capitaine » non).

- Tests d'abord (26 rouges sur 37) ; 13 contre-exemples intacts ; un établissement derrière « famille » reste un établissement ; restauration identique.
- `name_detector.dart` : civilités singulières étendues (`Mdme`, `Melle`, majuscules, minuscules, `docteur`…) ; `_civilitePlurielle` (une entité par nom) ;
  `_cueParente` (`famille`, `époux`, `consorts`, `Sœur`, `Frère`, `Père`).
- Faux positifs : 3 896 textes de corpus comparés à `main`, 0 changement. Banc inchangé octet pour octet ; 1157 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Sur-masquages connus : « Père Noël », « madame Rose », « Famille Aidante ».
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-70 — Prénom entre deux mots capitalisés (`code`)

Contexte : « Bilan Pierre Dupont.docx » → « [NOM_1] Dupont.docx » ; la règle bidirectionnelle prenait le mot qui précède et laissait celui qui suit.

- Tests d'abord (12 rouges sur 17) ; 5 cas à un seul voisin inchangés ; même personne = même jeton.
- `name_detector.dart` : si un voisin libre existe de chaque côté du prénom, l'étendue couvre les deux (3 mots, confiance 0.6).
- Faux positifs / effets : 3 896 textes de corpus comparés à `main`, 32 changent (flou adversarial), tous un patronyme désormais couvert ; banc inchangé
  octet pour octet ; 1174 tests.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Coût assumé : le mot qui précède reste masqué avec le nom. Non traité : noms dans noms de fichiers, URL, logins.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-72 — Restauration d'un chemin Windows (`code`)

Contexte : `C:\Users\[NOM_1]\Documents` se restaurait en `C:\UsersJean Dupont\Documents` (barre oblique consommée, défaut de P2-31).

- Tests d'abord (4 rouges sur 5) ; formes Markdown de P2-31 conservées.
- `tokenizer.dart` : `tolerantTokenPattern` n'accepte la barre oblique devant le crochet ouvrant que si la fermante est échappée aussi.
- Mesure : banc inchangé octet pour octet ; 1179 tests ; demo, ingest, audit verts.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-71 — Noms dans les noms de fichiers, URL, chemins et identifiants (`code`)

Contexte : `Bilan_Pierre_Dupont_2024.pdf`, `/patient/pierre-dupont`, `pierre.dupont`, `@pierre_dupont` restaient en clair (13 formes sur 25).

- Tests d'abord (13 rouges sur 25) ; contre-exemples (`/sous-marin`, `compte_rendu_final.docx`, `user_id=12345`…) intacts ; restauration identique.
- `name_detector.dart` : seconde lecture sur une copie de même longueur (`_` et `.` en espaces) fusionnée avec la première (remplace seulement ce qu'elle
  recouvre entièrement) ; `_slugs` (noms en minuscules dans un contexte d'URL, de chemin, de fichier ou d'identifiant).
- Mesure : 3 896 textes de corpus, 0 changement ; banc inchangé octet pour octet ; 1207 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Découverte en route, traitée à part : restauration d'un chemin Windows (P2-72, fusionnée).
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-73 — Nom coupé par un retour à la ligne (`code`)

Contexte : « Mme⏎Dupont », « Nom :⏎Quenelle » (texte de PDF) laissaient le nom en clair.

- Tests d'abord (8 rouges sur 18) ; 8 contre-exemples intacts (ligne vide, mots d'ouverture de phrase, « Dr Martin⏎Secretaire »).
- `name_detector.dart` : `_blancOuSaut` (blancs ou un seul saut de ligne, jamais devant un mot d'ouverture de phrase) entre civilité et nom, après « née… », et
  après les deux-points d'une étiquette ; fenêtre « Prénom » à proximité portée à trois lignes ; « Prénom : Nom » n'est pas un prénom.
- Essai abandonné : saut de ligne entre les mots du nom (49 textes de corpus changés, faux positifs). Garde-fou « un nom ne traverse pas sa ligne » conservé.
- Mesure : 3 896 textes de corpus, 0 changement ; banc inchangé octet pour octet ; 1225 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Fuite connue : nom coupé entre ses mots.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-74 — Forme « Nom, Prénom » (`code`)

Contexte : relecture manuelle d'un compte rendu synthétique : « Marchetti, Odette » masquait le prénom et laissait le patronyme.

- Tests d'abord (10 rouges sur 18) ; 8 contre-exemples intacts (« Bonjour, Odette », « Rappel, Odette doit venir », « Paris, Pierre est venu »…).
- `name_detector.dart` : `_matchPrevVirgule` (mot capitalisé avant la virgule, hors formules d'adresse, prénom suivi d'une ponctuation / parenthèse / chiffre / fin
  de ligne) ; `ecluse.dart` : les virgules sont ignorées pour l'identité (`_nameSegments`).
- Mesure : 3 896 textes de corpus, 0 changement ; banc inchangé octet pour octet ; 1243 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Non traité : prénom hors gazetteer, initiales isolées, tout en minuscules.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-75 et P2-76 — Initiales après une civilité ; variantes de « date de naissance » (`code`)

Contexte : relecture adverse indépendante (un « sage », 200 sondes) ; deux fuites reproduites avant correction.

- Tests d'abord (21 rouges sur 35) ; contre-exemples intacts (initiale seule, `DN 12`, `Né 3 fois`, dates de rendez-vous).
- `name_detector.dart` : `_initiales` (0 à 3 initiales) dans le groupe de nom de `_civility`, patronyme seul dans la seconde passe.
- `date_naissance_detector.dart` : contextes `DN`, `D.N.`, `Date nais.`, `née`/`né` sans « le », `n. le`, âge puis date entre parenthèses ; mois abrégé suivi d'un point.
- Mesure : 3 896 textes de corpus, 0 changement ; banc inchangé octet pour octet ; 1278 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- Écarté après analyse : nom en minuscules après `mme`/`mr`/`m.` (faux positifs massifs) ; initiales isolées sans civilité.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-77 — Sur-masquages fréquents (`code`)

Contexte : relecture adverse indépendante (un « sage » chargé des faux positifs) : fonctions, statuts, jours, toponymes, éponymes, lots masqués à tort.

- Tests d'abord (32 rouges sur 46) ; 13 témoins : les vrais noms restent masqués (Madame Dupont, Famille Quenelle, Mme Saint-Pierre, Dr Alzheimer, Appeler Pierre Dupont…).
- `name_detector.dart` : fonction après civilité (`le|la|les` minuscules), liste `_statuts` (civilité, parenté, prénom), `_motsVoisinsNeutres` (jours, mois, adverbes, politesse)
  écartés comme voisin d'un prénom, `_estToponymeSaint`, `_precedeParEponyme`. `identifiant_detector.dart` : plaque précédée de lot/série/référence écartée.
- Changement de comportement assumé : les communes « Saint-… » ne sont plus masquées (elles l'étaient par accident, contrairement aux autres communes).
- Mesure : 3 896 textes de corpus, 10 changements (communes Saint-…) ; banc inchangé octet pour octet ; 1324 tests ; tous les paquets verts.
### P2-79 — Coût d'une chaîne de particules et de balises ouvertes (`code`, bloquant)

Contexte : relecture indépendante du code : `Van Der ` × 80 (640 octets) = 15 s dans `_aEcrit` (P2-53) ; cubique dans `_signature` (P2-54) ; `<prenom ` sans `>` et `<[^>]*>` (docx/odt) quadratiques.

- Tests d'abord (mesure sur la base : 640 octets en 14,8 s) ; 7 tests de coût côté détection, 2 côté ingestion ; un nom à particules reste masqué.
- `name_detector.dart` : `_unite` borne les particules à trois ; clé XML `[^>\n]{0,200}`. `docx_xml.dart`, `odt_xml.dart`, `docx_extractor.dart` : `[^<>]`.
- Mesure : 3 896 textes de corpus, 0 changement ; banc inchangé octet pour octet ; redact 1285 tests, ingest 158.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-80 — Identifiants administratifs sans « n° » (`code`)

Contexte : relecture indépendante : « dossier 4900123456 », « N° résident : 000123 », « Plan d'aide n° PA-2026-0042 » restaient en clair.

- Tests d'abord (8 rouges sur 21) ; 12 contre-exemples intacts (année, date, mois d'année, mots, deux chiffres).
- `identifiant_detector.dart` : étiquettes « n° de résident / usager », « Plan d'aide n° » ; `_dossierNu` (« dossier » + valeur d'au moins six chiffres, ni date ni mois d'année).
- Mesure : 3 896 textes de corpus, 0 changement ; banc inchangé octet pour octet ; 1352 tests ; coût linéaire.
### P2-78 — Colonne « Date de naissance » d'un tableau (`code`)

Contexte : relecture indépendante : la date d'une colonne « Né(e) le » / « Date de naissance » restait en clair dans un tableau CSV, Word ou HTML.

- Tests d'abord (11 rouges sur 17) ; 6 contre-exemples (Date de visite, d'entrée, de péremption, cellule non date, cellule vide, pas un tableau) ; refus explicite conservé.
- `tableau_csv.dart` : lecture générique par colonnes (`_cellulesDeColonnes`) ; `cellulesDeNaissance`. `date_naissance_detector.dart` : cellule entière qui est une date ; recherche
  dichotomique du chevauchement.
- Mesure : 3 896 textes de corpus, 0 changement ; banc inchangé octet pour octet ; 1302 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-81 — Signature avec initiale et nom de naissance « (ex-X) » (`code`)

Contexte : relecture indépendante : « Cordialement,⏎N. Haddad » et « Mme Roux (ex-Garnier) » laissaient un nom en clair.

- Tests d'abord (6 rouges sur 11) ; contre-exemples intacts (« N. B. » seul, « ex-patient », « ex-fumeur », « l'ex-Yougoslavie »).
- `name_detector.dart` : `_signature` accepte les initiales ; `_exNomNaissance` (entre parenthèses seulement).
- Mesure : 3 896 textes de corpus, 0 changement ; banc inchangé octet pour octet ; 1359 tests ; coût linéaire.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-82 — Restauration sans coût quadratique (`code`)

Constat (mesuré sur `main`, avant correction) : `Ecluse.restore` faisait un `replaceAll` par jeton,
donc « jetons × taille du texte » : 2 000 mentions 0,6 s ; 10 000 : 12,5 s ; 20 000 : 61,6 s.
La partie « résolution » de P2-64 était déjà fusionnée (#202) ; la partie « restauration » de la PR #201
ne l'était pas.

- `restore` : un seul parcours des segments `[...]` ; repli sur l'ancien algorithme si une valeur
  contient `[`, `]` ou `\` (l'équivalence n'est alors plus garantie).
- Test différentiel `restore_equivalence_test.dart` contre l'ancien algorithme (2 000 textes tirés,
  graines fixes, valeurs piégées).
- Mesure après : 2 000 mentions 65 ms ; 10 000 : 188 ms ; 20 000 : 328 ms.
- `ecluse_core` inchangé. Aucune dépendance ajoutée.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-84 — Valeurs vides derrière « Nom : » / « Prénom : » (`code`)

Source : relecture indépendante du 1er novembre 2026 (sage « faux positifs »), cas reproduits sur `main` : `Prénom : Non renseigné` donnait
`Prénom : [NOM_1] renseigné` (valeur tronquée, phrase illisible).

- Liste fermée de valeurs vides, comparées au mot entier : néant, sans, idem, identique, anonyme, anonymisé(e), confidentiel(le), exemple, test, « à compléter »,
  en plus de non / inconnu / n/a déjà connus des clés de données. Appliquée aux champs `Nom …` et `Prénom …`.
- Contre-exemples testés : `Prénom : Nonna`, `Prénom : Idemar`, `Nom de naissance : Testard`, `Prénom : Test-Marc` restent masqués.
- Mesure : 1 000 textes de corpus, 0 changement ; `format`, `analyze`, 1406 tests verts. `ecluse_core` inchangé.
### P2-83 — Variantes de date de naissance trouvées par relecture (`code`)

Source : relecture indépendante du 1er novembre 2026 (sage « fuites »), cas reproduits sur `main`.

- Mois français abrégés après un contexte de naissance : `12 janv. 1950`, `févr.`, `fév.`, `avr.`, `juil.`, `déc.` restaient en clair
  (seuls `sept.`, `oct.`, `nov.` passaient, par coïncidence avec la liste des mois anglais).
- Libellés `Naiss.`, `Naiss :`, `Naissance le …`, `Naissance du …`.
- Date compacte JJMMAAAA (`DDN : 12031950`), bornes de jour et de mois vérifiées.
- Contexte de naissance toujours obligatoire ; contre-exemples testés (« Rendez-vous le 12 janv. 2027 », « Réf. 12031950 », `DDN : 31132000`).
- Mesure : 1 000 textes de corpus, 0 changement ; `format`, `analyze`, 1410 tests verts. `ecluse_core` inchangé.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

### P2-85 — Quatre coûts quadratiques trouvés par relecture (`code`)

Source : relecture indépendante du 1er novembre 2026 (sage « robustesse »), reproduits avant correction sur `main`.

- `1` + n blancs : `_cleNommee` (deux `[ \t]*` séparés par `\(?`) et le détecteur d'adresse (deux `[ \t]*` séparés par `,?`) : 4 000 blancs 6,7 s, 20 000 blancs 4,8 s même après la seule correction de l'adresse. Écriture non ambiguë `[ \t]*(?:,[ \t]*)?`.
- `'a' * n + '.'` : regard arrière non borné `(?<=[A-ZÀ-Þ][a-zà-ÿ]+)\.` du séparateur « Prénom.Nom » (32 000 : 10 s) : vérification à part, une seule remontée par point.
- `sk-ant-` répété : OpenAI `sk-…T3BlbkFJ…` (40 Ko : 2,5 s, 100 Ko : 44 s) : première partie bornée à 512 caractères.
- `Ecluse.restore` avec un courriel obfusqué `jean[at]example.fr` : repli séquentiel (10 000 jetons : 9,2 s) : le repli ne vaut plus que pour une valeur qui peut recréer un jeton (barre oblique inversée, crochet isolé, segment `[...]` confondu avec un jeton).
- Mesure après : chiffre + 20 000 blancs 77 ms ; 100 000 minuscules + point sous 3 s ; `sk-ant-` ×100 000 sous 3 s ; restore 10 000 jetons sous 3 s. 4 000 textes tirés + 1 000 de corpus : 0 changement. `ecluse_core` : une borne de regex.
- **Fini quand** : `format`, `analyze`, `test` passent et `LIMITES.md` est à jour.

## Fiches archivées le 17 novembre 2026 (P2-86 à P2-215)

Fiches des tâches au statut `fusionnée` à cette date, reprises telles quelles de `agent/QUEUE.md` (contenu inchangé).

- **P2-88** : document seulement, aucune dépendance. Repartir de
  `agent/specs/P2-86.md` § 2.1 pour la correspondance des labels du candidat 1
  vers les types des corpus flous. La commande finale réutilise
  `score_flou.py --pred "NER=…"`. **Fini quand** : un tiers peut lancer la
  mesure sans autre information.

- **P2-91** : ajout au `RiskReport` existant, sans changer `maskedText`. Test
  d'équivalence d'abord : sans `riskReference`, sortie inchangée octet pour
  octet (décision P2-03 n° 2). **Fini quand** : chaque suggestion porte ses
  offsets dans le texte masqué (celui que l'appelant généraliserait, le
  rapport porte sur lui) et le F estimé après généralisation.

- **P2-92** : jamais déclenchée par le moteur ; une proposition périmée est
  refusée comme dans l'aperçu (P2-19). La généralisation n'entre pas dans la
  table de correspondance (irréversible).

- **P2-93** : mesurer, ne rien corriger.

- **P2-96** : attend P2-96a.

- **P2-98** : générer le texte transcrit à partir du corpus v3 (minuscules,
  ponctuation retirée, nombres en lettres), graine 42. Mesurer le rappel par
  type ; ne rien corriger.

- **P2-100** : méthode de la PR #242 (meilleur de trois essais, deux tailles
  dans un rapport 4, seuil 8). Un paquet par commit. **Fini quand** : plus
  aucun test ne compare un temps à une borne absolue.

- **P2-101** : `humain` tant que l'accord pour toucher `.github/` n'est pas
  donné (zone interdite aux agents).

- **P2-102** : défauts mesurés par P2-93 (#262) : « 104 ans » relu dans
  « 100-104 ans », profession généralisée non relue. **Fini quand** : chaque
  palier d'âge et de profession produit par `nextRung` se relit tel quel
  (`qiValueLabel` puis `extractQiSpans`).

- **P2-103** : mesurer, ne rien corriger. Le corpus réaliste de P2-93 ne
  généralisait jamais le lieu ; construire au besoin des cas où la
  suggestion retenue porte sur le lieu, puis comparer F simulé (`fAfter`) et
  F recalculé après `appliquerGeneralisations`.

- **P2-140** : **mesure seulement.** Les détecteurs de casse (P2-119 à
  P2-139) n'ont été mesurés que document par document. Appliquer
  `bench/variantes_casse.py` aux trois corpus de dossiers
  (`generate_corpus_dossiers.py --n 400 --seed 42`), puis
  `run_dossiers_bench.dart --dossier` et `score_dossiers.py` sur chaque
  variante (`_minuscules`, `_phrase`, `_majuscules`). Rapporter dans
  `agent/specs/P2-140.md`, à côté des chiffres en casse ordinaire
  (`bench/ETAT.md`) : cohérence, collisions, fausses fusions, restaurations
  non identiques, mentions non détectées. Signaler en particulier si une
  même personne reçoit deux jetons selon la casse de ses mentions. Aucun
  code de production.

- **P2-129** : **mesure seulement, ne rien corriger.** Ajouter à
  `bench/generate_corpus_pathologies.py` un corpus `formes_libres` (graine
  fixe, préfixe stable, corpus existants inchangés : le vérifier par
  comparaison des sorties) avec des formes que P2-125/126 ne couvrent pas :
  « non diabétique », « DT2 », « diabète : non », « BPCO ? à éliminer »,
  « suspicion de », « ATCD : », fautes courantes (« diabete »,
  « épilépsie »). Annoter ce qui est une pathologie de la personne, ne pas
  annoter les négations. Mesurer avec `bin/run_pathologies_bench.dart`
  (brut et rattachées) et rapporter dans `agent/specs/P2-129.md`, par forme,
  ce qui est trouvé, manqué, ou rattaché à tort. Tests Python du nouveau
  corpus.

- **P2-130** : **mesure seulement.** Rejouer sur `main` tous les corpus
  documentés dans `bench/README.md` et les rapports `agent/specs/P1-36.md`,
  `P2-98.md`, `P2-117.md`, `P2-121.md`, `P2-124.md`, `P2-125.md` (mêmes
  commandes, mêmes graines), et consigner dans un nouveau `bench/ETAT.md` un
  tableau unique : corpus, commit, précision, rappel, fuite au caractère,
  faux positifs du témoin. Signaler tout écart avec les chiffres des
  rapports. Aucun code de production.

- **P2-122** : sur le modèle de `MinusculesRecapitaliseDetector` (P2-120,
  à lire d'abord) : un texte **sans aucune minuscule** reçoit un texte
  d'ombre de même longueur en casse de titre (mots outils, unités et noms de
  comptage en minuscules, sigles d'établissement gardés en capitales),
  passé à `AdresseDetector` et `EtablissementDetector`. Actif seulement sans
  aucune minuscule. Mesure avant/après obligatoire (commandes et chiffres de
  départ : `agent/specs/P2-121.md`) : fuite par type sur les corpus flous
  réaliste et adversarial en majuscules ; **budget : 0 faux positif** sur
  le témoin en majuscules (194 aujourd'hui) ; sorties **identiques** sur les
  corpus d'origine, en minuscules et v3. Les noms ne sont pas dans le
  périmètre. Ne pas modifier les détecteurs existants.

- **P2-120** : sur le modèle de `NomMinusculesDetector` (P2-119) : un
  détecteur actif **seulement** si le texte n'a aucune majuscule, qui
  rattrape les adresses (numéro + type de voie : « 7 impasse des
  charmilles », code postal + commune) et les établissements (mot-clé de
  `etablissement_keywords.dart` suivi de son nom, arrêté par un mot outil).
  Mesure avant/après obligatoire sur `corpus_flou_{realiste,adversarial}`
  mis en minuscules (`text.lower()`, offsets inchangés) : fuite au caractère
  par type (`score_flou.py`) ; **budget : 0 faux positif** sur
  `corpus_flou_temoin` en minuscules, et sorties **identiques** sur les
  corpus d'origine. Commandes et chiffres de départ : `agent/specs/P2-117.md`
  (adresse et établissement : 100 % de fuite). Ne pas toucher aux
  détecteurs existants.

- **P2-115** : lecture seule de l'asset, sur le modèle de
  `first_name_gazetteer.dart` (gzip, chargement paresseux). Ignorer la
  ligne d'en-tête « # ». API minimale : catégorie d'un ORPHAcode, et
  ensemble des mentions normalisées avec leur ORPHAcode. Tests : l'asset
  réel (« Sclérose latérale amyotrophique » → « Maladie neurologique
  rare », « SLA » présent, « ALD » absent), plus un asset synthétique pour
  les cas de refus (fichier vide, colonne manquante). **Pas** d'appariement
  dans du texte ni de branchement dans `ecluse_reid` : ce sera une tâche
  suivante, après P2-110 et P2-112 (corpus pour mesurer). Ne pas modifier
  l'asset ni le script.

- **P1-36** : mesurer, ne rien corriger. Rejouer les commandes [C1], [C2],
  [C4] et [C5] de `bench/ARTICLE.md` sur `main` et rapporter le tableau
  Écluse (précision, rappel, F1 par type, faux positifs par type) et le
  résultat de [C5], à côté des chiffres de l'article. Contexte :
  `agent/specs/P1-12-relecture.md`. Ne pas modifier `bench/ARTICLE.md` ni
  `bench/requirements.txt` : signaler les écarts dans la PR.

- **P2-105** : Python, dans `bench/`, comme les autres générateurs ; aucun
  LLM appelé. Partir de textes passés dans `Ecluse.redact` et annoter dans
  le générateur les indices restants (rôle unique, événement daté, rareté
  locale, coréférence). Voir `agent/specs/P2-104.md` § 3. **Fini quand** :
  trois jeux (indices, témoin, injection) reproductibles à graine égale.

- **P2-106** : comme `agent/specs/P2-86.md`. Si une page n'est pas joignable,
  le dire ; ne jamais supposer une licence.

- **P2-107** : document seulement, aucune dépendance, sur le modèle de
  `bench/ner_predictions.md`. Candidat de départ : SmolLM3-3B
  (`agent/specs/P2-106.md`). Partir du prompt versionné et du parseur de la
  branche `feat/llm-scaffold`, sans fusionner la branche. Dire comment
  obtenir le statut « non vérifié » sur un échec.

- **P2-109** : `humain` parce que le travail se fait sur la branche
  `feat/llm-scaffold`, pas sur une branche partie de `main` (règle 7). Constat
  (P2-107) : sur un échec d'analyse, `LlmRedactVerifier` rend une liste vide
  et `isClean` vaut `true`, contraire à la condition D de P2-104. Le
  prompt `v1` tronque aussi le texte à 4 000 caractères sans changer le
  statut. Le mainteneur décide quand et comment corriger la branche.

- **P2-112** : Python, dans `bench/`, comme `generate_corpus_semantique.py`.
  Mentions tirées de `agent/specs/P2-94-table.md` § 3 avec leur catégorie et
  leur système ; témoin avec des faux amis (« SEP » en dehors de la
  neurologie, « cancer » au sens figuré, « dialyse » d'un appareil).
  **Fini quand** : corpus reproductible à graine égale, offsets exacts,
  tests passés.

- **P2-153** : Python, dans `bench/`, comme les autres générateurs
  (`generate_corpus_mise_en_page.py`), plus ses tests. Entrée : un corpus
  `.jsonl` existant ; sortie : le même, où chaque texte est recoupé aux
  espaces à une largeur donnée (60 puis 90 caractères), sans rien changer
  d'autre, avec les offsets des entités recalculés exactement. Graine 42.
  Ajouter à `bench/etat.sh` et à `bench/ETAT.md` une section « mise en
  page » : fuite par type sur le réaliste, l'adversarial et le témoin flous,
  rappel sur le corpus structurel. **Ne modifier aucun détecteur** : la
  règle « un span ne traverse jamais un saut de ligne » (`LIMITES.md` § 5.2)
  est assumée ; la tâche la chiffre. **Fini quand** : corpus reproductible à
  graine égale, offsets vérifiés par un test, chiffres dans `ETAT.md`.

- **P2-154** : mesurer, ne rien corriger. Partir de `bench/qi/` (corpus
  adversarial, 400 documents, `score_qi.py`). Classer les âges non couverts
  par forme (« bientôt 80 ans », « la soixantaine », âge en lettres…), avec
  le nombre de cas et un exemple synthétique par forme. Rapport dans
  `agent/specs/P2-154.md`, avec pour chaque forme le risque de faux positif
  attendu si on la couvrait.

- **P2-155** : document seulement (`agent/specs/P2-155.md`), aucune ligne de
  code de production. Contexte : `agent/specs/P2-98.md` (rappel 0 % sur le
  corpus transcrit, `bench/generate_corpus_transcrit.py`). Traiter : les
  façons de dicter un NIR, un téléphone, un IBAN, un RPPS (chiffre à
  chiffre, par paires, « quatre-vingt-dix », « soixante et onze », « double
  zéro ») ; où faire la conversion (vue de détection seulement, le texte
  n'est jamais réécrit, offsets conservés) ; les ambiguïtés (« un » article
  ou chiffre, « neuf » adjectif) ; le budget de faux positifs sur les
  témoins ; le plan de mesure avant/après. Finir par les décisions qui
  reviennent au mainteneur.

- **P2-156** : mesurer, ne rien corriger sur `main`. Sur la branche de la
  tâche, monter les trois paquets, lancer `melos run analyze` et `melos run
  test`, rejouer les PDF synthétiques (`bench/generate_pdfs.py`). Rapport
  dans `agent/specs/P2-156.md` : ce qui casse, l'effort estimé, les notes de
  version lues. **Ne pas inclure** le changement de `pubspec` dans la PR :
  seul le rapport est fusionnable ; le mainteneur décide de la montée.

- **P2-157** : mesurer, ne rien corriger. `bench/flou/`, corpus adversarial,
  type adresse. Même forme de rapport que P2-154, dans
  `agent/specs/P2-157.md`.

- **P2-158** : extension étroite de P2-152 (`_coupuresDeLigne`,
  `ecluse_redact/lib/src/ecluse.dart`). Aujourd'hui la fin de ligne n'est
  neutralisée que si ce qui suit est un chiffre ; l'admettre aussi devant
  **une** majuscule suivie d'un chiffre. Test d'abord dans
  `identifiant_coupe_test.dart` (le cas rouge, plus des contre-exemples qui
  doivent rester intacts : « Salle 4⏎A2 fermée », « Vol 12⏎B7 porte », « le
  3⏎C4 du plan »). **Fini quand** : section « mise en page » de
  `bench/ETAT.md` à 778/778 par `Ecluse.redact` à 60 colonnes, tous les
  autres chiffres du tableau de bord inchangés, `LIMITES.md` § 5.2 mis à
  jour (y citer aussi les chiffres de P2-153).

- **P2-159** : `ecluse_reid`, `qi_extraction.dart`. Périmètre décidé par le
  mainteneur le 12 novembre : seulement un nombre en lettres **suivi de
  « ans »** (unités, dizaines, « et un », « soixante-dix », « quatre-vingt »,
  avec trait d'union ou espace). **Hors périmètre** : « la soixantaine »,
  « octogénaire », « dans sa quatre-vingtième année » (choix de produit, ne
  pas y toucher). Réutiliser l'exclusion des durées (`_dureeAvant`, P2-136).
  Test d'abord sur les 15 cas de `agent/specs/P2-154.md` § 2. **Fini
  quand** : âges non couverts du corpus QI adversarial 12,7 % → 0 %, corpus
  témoin QI toujours à 0 extraction à tort, reste du tableau de bord
  inchangé.
  **Second volet (ancienne P2-163)**, dans la même PR : « de 80 à 85 ans »
  ne sort aujourd'hui que la borne 85 (`agent/specs/P2-154.md` § 3). Test
  d'abord (« de 80 à 85 ans », « entre 60 et 65 ans », « 80-85 ans ») et
  contre-exemples (« de 2 à 3 ans de suivi », durée). Décider dans la PR, en
  le justifiant, si l'extraction est une tranche ou deux âges, sans changer
  le format du rapport de risque. **Fini quand**, pour les deux volets : cas
  rouges verts, âges non couverts du QI adversarial à 0 %, corpus QI réaliste
  et témoins inchangés, reste du tableau de bord inchangé.

- **P2-160** : Python, dans `bench/`, avec ses tests, sur le modèle des
  autres générateurs. Au moins 300 phrases synthétiques, graine 42, dont une
  moitié avec au moins 6 mots-nombres consécutifs : montants (« deux cent
  cinquante mille euros »), dates en lettres, quantités, consignes
  (« comptez dix, répétez six fois »). Aucune entité annotée : c'est un
  témoin. Ajouter au tableau de bord une ligne « témoin mots-nombres :
  N prédictions » par `Ecluse.redact`. **Ne modifier aucun détecteur.**
  Voir `agent/specs/P2-155.md` § 5.
  **Second volet (ancienne P2-161)**, dans la même PR :
  `bench/generate_corpus_transcrit.py` et ses tests. Ajouter les variantes de
  `agent/specs/P2-155.md` § 2 absentes du corpus : « double / triple »,
  « septante / huitante / nonante », zéro dit « o », traits d'union et
  virgules perdus. Offsets exacts, graine 42. Mesurer le rappel et la fuite
  de départ par variante et par type, et les écrire dans `bench/ETAT.md`.
  C'est le « défaut d'abord » de la future tâche de code. **Fini quand** :
  les deux corpus sont reproductibles à graine égale, leurs chiffres sont
  dans `bench/ETAT.md`, le reste du tableau de bord est inchangé.

- **P2-162** : document seulement (`agent/specs/P2-162.md`). Constat de
  P2-153 : par `Ecluse.redact`, 777 identifiants sur 778 sont détectés à
  60 colonnes ; par le moteur seul (`EcluseEngine`), 87,7 %. Une
  application qui appelle `ecluse_core` directement manque donc les
  identifiants coupés. Décrire : qui appelle le moteur seul aujourd'hui
  (`ecluse_bench`, `ecluse_demo`, autres ?), les options (descendre la
  neutralisation dans `ecluse_core`, la documenter comme limite du moteur,
  refuser l'appel direct), leurs risques (faux positifs, offsets, coût,
  détecteurs purs), le plan de mesure. Finir par la décision qui revient au
  mainteneur.

- **P2-164** : `ecluse_redact`, `adresse_detector.dart`. Constat de
  `agent/specs/P2-157.md` : les 53 adresses « … CEDEX 9 » du corpus flou
  adversarial laissent « 9 » en clair (1,9 % des caractères d'adresse), et la
  sonde montre « CEDEX 09 », « Cedex 9 », « , CEDEX 9 » et « BP 12 » en clair.
  Test d'abord sur ces cas rouges ; contre-exemples à garder intacts :
  « CEDEX » sans numéro, un nombre après une commune sans CEDEX (« 70000
  VESOUL 3 agents »), « BP » hors adresse (« la BP 12 du moteur », sigle dans
  une phrase). Deux volets dans la même PR : le numéro de CEDEX, puis la
  boîte postale attachée à une adresse. Si la boîte postale exige un nouveau
  type d'entité ou sort du périmètre de `LIMITES.md`, s'arrêter sur ce volet
  et l'expliquer. **Fini quand** : ligne `adresse` de l'adversarial 1,9 % →
  0 % (mesurée par `Ecluse.redact`), corpus réaliste et témoins flous
  inchangés (0 prédiction sur les témoins), reste du tableau de bord
  inchangé, `LIMITES.md` à jour.

- **P2-165** : `ecluse_reid`, `qi_extraction.dart`. Sonde du 13 novembre
  (relecture de P2-159) : « deux ans plus tard », « au bout de cinq ans »,
  « voilà dix ans », « un contrat de trois ans », « trois ans de prison »,
  « les vingt ans du service » sortent comme des âges, en lettres comme en
  chiffres (« 2 ans plus tard »). Un âge à tort grossit le risque calculé et
  peut proposer une généralisation sans objet. Test d'abord : ces cas rouges
  dans les deux écritures ; cas qui doivent rester lus (« âgé de deux ans »,
  « Patiente de quatre-vingts ans », « suivi depuis ses deux ans »,
  « 72 ans »). Étendre `_dureeAvant` et `_dureeApres` par tournures, sans
  liste ajustée aux valeurs d'un corpus. Ajouter ces phrases au corpus témoin
  QI (graine 42) pour que le défaut soit mesuré avant la correction. **Fini
  quand** : cas rouges verts, témoin QI à 0 extraction à tort (nouvelles
  phrases comprises), âge du QI réaliste et adversarial inchangés (rappel
  100 %), reste du tableau de bord inchangé, `LIMITES.md` à jour.

- **P2-166** : mesure seulement, dans `bench/` (script et test Python, ou
  binaire de banc dans `ecluse_bench`) ; aucun fichier de `lib/` modifié.
  Plan de `agent/specs/P2-162.md` § 5. Premier volet : ajouter au tableau de
  bord, section « mise en page », la ligne « détecteur isolé » (`NirDetector`,
  `RppsDetector`, `IbanFrDetector`, `FinessDetector` appelés directement, à
  60 et 90 colonnes), à côté des lignes « moteur seul » et `Ecluse.redact`.
  Second volet : chiffrer ce que coûterait une fin de ligne neutralisée dans
  le cœur, sans la coder : compter dans les corpus existants (v3, flous,
  témoins, prose des `.md`) les endroits « chiffre, fin de ligne, chiffre »
  qui formeraient un identifiant à clé valide une fois recollés, et les
  colonnes de nombres à 9, 11 ou 13 chiffres. **Fini quand** : la ligne est
  dans `bench/ETAT.md` avec son chemin de mesure, le compte de faux positifs
  possibles est écrit dans `agent/specs/P2-166.md`, le reste du tableau de
  bord est inchangé. La décision A1 / A2 / B / C de P2-162 reste au
  mainteneur.

- **P2-167** : `ecluse_redact`, `adresse_detector.dart`. Relevé le
  13 novembre (relecture de P2-164) : par `Ecluse.redact`, « Commande de
  70000 unités, cedex 9 non concerné. » sort avec « 70000 unités » masqué
  comme une adresse. Premier volet, mesurer : écrire un corpus témoin
  « nombres à cinq chiffres » (graine 42, dans `bench/`, à côté des témoins
  flous) : quantités, montants, références, numéros de lot ou de dossier,
  suivis d'un mot en minuscules, d'un mot à majuscule, en début ou en fin de
  phrase ; compter les prédictions par `Ecluse.redact` et dire quelle règle
  les produit (la sonde sera à refaire : ne pas supposer la cause). Second
  volet, corriger, dans la même PR, si la cause est une règle du détecteur
  d'adresse : test rouge d'abord, puis correction par tournure, sans liste
  ajustée aux valeurs du corpus. Si la correction ferait perdre une adresse
  des corpus flous, s'arrêter et rapporter la mesure seule. **Fini quand** :
  le nouveau témoin est au tableau de bord avec son chemin de mesure, son
  compte avant et après ; adresses du réaliste et de l'adversarial inchangées
  (0 % en clair), témoins existants à 0, reste du tableau de bord inchangé,
  `LIMITES.md` à jour.

- **P2-168** : `bench/etat.sh` et les scripts qu'il appelle ; aucun fichier
  de `lib/`. Constat du 13 novembre (P2-165) : la ligne « témoin » des
  quasi-identifiants ne s'imprimait pas, le filtre cherchait « extractions »
  alors que le score écrit « Extractions ». Le tableau de bord a donc pu taire
  un chiffre sans que personne le voie. Relire chaque section : pour chaque
  ligne que `bench/ETAT.md` annonce, vérifier qu'elle sort bien de
  `bench/etat.sh` ; recenser les `|| true`, les `> /dev/null 2>&1` et les
  `grep` qui peuvent rendre une section vide. Corriger pour qu'une commande
  qui échoue ou une section vide s'affiche comme telle (« ÉCHEC : … »,
  « section vide ») et que le script sorte avec un code non nul, sans changer
  aucun chiffre. Ajouter un test Python dans `bench/` qui échoue si une
  section attendue manque dans une sortie d'exemple. **Fini quand** : la
  liste des trous trouvés est dans la PR, `bash bench/etat.sh` rejoué donne
  les mêmes chiffres qu'avant ligne à ligne (lignes ajoutées exceptées), un
  échec provoqué exprès (corpus absent) est visible et fait sortir en erreur.

- **P2-169** : mesure seulement, rapport dans `agent/specs/P2-169.md`.
  Reprendre la méthode des audits précédents (chercher « fuite » et
  « P2-9 » dans `DECISIONS.md` et `LIMITES.md`) sur le code ajouté depuis
  le 1er novembre : option `prenomsInsee`, neutralisation des fins de ligne,
  âges en lettres et tranches, durées, CEDEX, corpus de dictée, bancs. Pour
  chaque paquet : messages d'exception, `toString`, `print` et journaux,
  sérialisation JSON, journal d'audit, serveur de démo. Une valeur tirée du
  texte de l'utilisateur ne doit apparaître dans aucun de ces canaux. Pour
  chaque voie trouvée : fichier, ligne, une entrée synthétique qui la
  déclenche et ce qui sort. **Fini quand** : le rapport liste les voies
  vérifiées (y compris celles qui sont saines), les voies fautives avec leur
  reproduction, et propose une tâche de correction par voie fautive ; aucun
  fichier de `lib/` modifié.

- **P2-170** : `ecluse_reid` et `ecluse_reference`. Rapport
  `agent/specs/P2-169.md` § 2 et § 3 : voies F1 (`Qi.toString`), F3
  (`PathologieMention.toString`, gravité haute), F4 (`ArgumentError` de
  `estimator.dart` et `lieu_population.dart` avec une valeur de QI), F5
  (`GeoHierarchy.populationOfDep`), et les deux « hors décompte »
  (`BirthDate.toString`, `Generalization.toString`). Une seule PR, un volet
  par voie. Pour chaque voie, test d'abord : une entrée synthétique qui
  déclenche la sortie, et l'assertion que la valeur tirée du texte n'y est
  pas (reprendre les reproductions du rapport). Puis la correction :
  `toString` ne rend que le type, le niveau et des longueurs ; les messages
  d'exception ont un motif fixe, sans la valeur reçue. Ne changer aucune API
  publique ni aucun champ : seuls les textes de `toString` et des messages
  changent. Vérifier qu'aucun test, banc ou script ne lit ces textes pour en
  tirer une valeur (sinon s'arrêter sur ce volet et l'expliquer). **F2 n'est
  pas dans cette tâche** (`ReidTrace.toAuditMap`, clé `qisInitiaux`) : le
  mainteneur doit d'abord dire si la preuve AIPD garde ces valeurs. **Fini
  quand** : un test de non-fuite par voie, rouge avant et vert après ; tableau
  de bord rejoué sans aucun chiffre modifié ; `LIMITES.md` et
  `agent/specs/P2-169.md` (état de chaque voie) à jour.

- **P2-171** : décision du 13 novembre (`DECISIONS.md`) : option B de
  `agent/specs/P2-162.md` maintenant, A1 seulement après mesure. Premier
  volet, documenter : dans le README d'`ecluse_core` (près de l'exemple
  d'appel direct des détecteurs) et dans `LIMITES.md`, dire qu'un détecteur
  ou le moteur appelés seuls manquent un identifiant coupé par une fin de
  ligne, avec les chiffres du tableau de bord (682/778 à 60 colonnes,
  751/778 à 90) et le renvoi vers `Ecluse.redact` (778/778). Second volet,
  mesurer, dans `bench/` et `ecluse_bench` seulement (points 2 et 4 du plan
  de P2-162 § 5) : (a) sur tous les corpus sans coupure « chiffre, fin de
  ligne, chiffre », les détections des détecteurs isolés sont identiques
  octet pour octet avec et sans recollage par le banc (`run_collage_fp.dart`) ;
  (b) le coût en temps du recollage sur 1 000, 10 000 et 100 000 lignes,
  et sur un texte adversarial (longues suites de chiffres et de fins de
  ligne), pour vérifier qu'il reste linéaire. Rapport dans
  `agent/specs/P2-171.md`. **Aucun fichier de `lib/` modifié** : A1 n'est
  pas codée ici. **Fini quand** : la limite est écrite aux deux endroits ;
  le rapport donne l'équivalence (nombre de documents comparés, différences)
  et les temps ; tableau de bord rejoué sans chiffre modifié ; le rapport
  dit en une phrase si les mesures lèvent ou non les réserves sur A1, la
  décision restant au mainteneur.

- **P2-172** : `ecluse_reid`. Décision du 13 novembre (`DECISIONS.md`) : la
  trace d'audit ne porte aucune valeur. `ReidTrace.toAuditMap` écrit
  aujourd'hui les valeurs des quasi-identifiants sous la clé `qisInitiaux`
  (voie F2 de `agent/specs/P2-169.md`, avec sa reproduction). Test d'abord :
  sur le JSON complet de `toAuditMap`, aucune valeur tirée du texte (lieu,
  âge, date, profession, pathologie) n'apparaît, pour chaque type de QI.
  Correction : `qisInitiaux` garde le type, le niveau et l'effectif ou la
  tranche de risque ; jamais la valeur. Si un consommateur du dépôt (export
  AIPD, démo, bancs) lit ces valeurs, l'adapter dans la même PR ; si le
  schéma de l'audit porte un numéro de version, l'incrémenter et le dire.
  **Fini quand** : test de non-fuite rouge avant, vert après ; tableau de
  bord rejoué sans chiffre modifié ; `LIMITES.md`, `agent/specs/P2-169.md`
  (F2 traitée) et la documentation de l'audit à jour.

- **P2-173** : `ecluse_redact`, chemin `Ecluse.redact`. Mesure du compte
  rendu de session du 13 novembre (midi), sonde jetable sur le corpus flou
  réaliste recoupé : à 90 colonnes, 44 établissements coupés restent en
  clair (37 en entier, mot-clé coupé ; 7 en partie, 9,2 % des caractères
  d'établissement) ; à 60 colonnes, 13 adresses laissent le dernier mot de
  la commune en clair (1,3 %) et 4 établissements leur fin. Test d'abord :
  versionner la mesure au tableau de bord (corpus recoupés à 60 et 90
  colonnes, graine 42), puis corriger dans la vue de détection de
  `ecluse_redact` (même principe que la neutralisation des fins de ligne
  des identifiants), sans toucher `ecluse_core`. **Fini quand** : fuite
  établissement à 90 colonnes 9,2 % → 0 %, adresse à 60 colonnes 1,3 % → 0 %,
  témoins recoupés à 0 prédiction, reste du tableau de bord inchangé,
  `LIMITES.md` § 5.2 à jour. Si un cas ne peut pas être rattrapé sans faux
  positif sur les témoins, le laisser, le chiffrer et l'écrire.

- **P2-174** : chemin `Ecluse.redact`. Sonde du 13 novembre, non versionnée
  et non remesurée depuis : un FINESS suivi d'une date est masqué comme RPPS
  en avalant le jour, 55 cas sur 500. Mesurer d'abord : témoin versionné
  (identifiant de chaque type suivi d'une date, d'un âge, d'un nombre), avec
  le chiffre de départ. Si la sonde ne se reproduit pas, rapporter et
  s'arrêter. Sinon corriger. **Fini quand** : sur le témoin, type juste et
  date intacte ; aucun identifiant perdu sur les corpus du tableau de bord ;
  P1-19 et ses tests toujours verts.

- **P2-175** : `ecluse_reid` et banc. Constat du 13 novembre : la ligne QI du
  tableau de bord mesure `ecluse_reid` seul, pas le produit. Premier volet :
  ajouter une ligne « QI par `Ecluse.redact` » (mesure de la sonde :
  0 document sur 400 en réaliste, 2 sur 400 en adversarial, nom derrière un
  métier sans civilité resté en clair). Second volet, `ecluse_reid` seul :
  les 43 et 33 lieux à tort (précision 88,2 % et 92,3 %) sont un patronyme
  homonyme d'une commune ; professions manquées de l'adversarial (7 sur 183) :
  « pneumo » 3, « gynéco » 3, « pediatre » sans accent 1. Test d'abord pour
  chaque volet. **Fini quand** : la ligne « par `Ecluse.redact` » est au
  tableau de bord ; précision lieu 100 % sur les deux corpus ; rappel
  profession 100 % sur l'adversarial ; témoins QI à 0 et 53 (inchangés) ;
  aucune commune réelle perdue (le dire si un homonyme reste ambigu).

- **P2-176** : `ecluse_reid`. Sonde du 13 novembre sur `geo_communes.csv.gz`
  (populations légales INSEE) : la population est unique en France pour
  2 964 communes (8,5 %) et unique dans son département pour 24 416 (70,1 %).
  Pour un lieu seul, F est cette population, donc l'effectif exact désigne la
  commune dans `toAuditMap` (`fInitial`, `fAvant`, `fApres`, note de
  plafonnement), `ReidEstimate.toString`, `Generalization.toString` et
  `ReidTrace.toString`. Format retenu (proposé par Claude le 13 novembre, à
  la demande du mainteneur ; le mainteneur peut le changer) : ces canaux
  donnent la **tranche de risque** (`band`) à la place de l'effectif exact ;
  les champs numériques de l'API (`f`) ne changent pas. Test d'abord : pour
  une commune à population unique, le F exact n'apparaît ni dans le JSON de
  `toAuditMap` ni dans un `toString`. Si un consommateur du dépôt (export
  AIPD, démo, bancs, `raisonDuChoix`) lit ces valeurs, l'adapter dans la même
  PR ; s'il en a besoin pour fonctionner, s'arrêter et l'expliquer. **Fini
  quand** : test rouge puis vert ; tableau de bord inchangé ; `LIMITES.md`
  § 7 et `agent/specs/P2-169.md` à jour.

- **P2-177** : adresses. Constat noté le 13 novembre : un nombre de cinq
  chiffres en tête de phrase suivi d'un mot (« 58699 Alpha livrés ») est
  masqué comme adresse, 66 cas sur 200, même forme qu'un code postal en tête
  de ligne. Test d'abord : témoin versionné, avec à côté un jeu d'adresses
  réelles de forme proche (code postal en tête de ligne suivi d'une commune,
  synthétique) pour ne pas en perdre. **Fini quand** : faux positifs du
  témoin chiffrés avant/après ; aucune adresse perdue sur les corpus du
  tableau de bord ; si les deux formes ne se séparent pas sans perte, garder
  le masquage (une adresse perdue est pire) et l'écrire dans `LIMITES.md`.

- **P2-178** : mesure seule. Après P2-164, CEDEX après une commune de plus
  de quatre mots (« Saint-… -sur-… », communes composées) : générer des cas
  synthétiques à partir de `geo_communes.csv.gz`, mesurer ce qui reste en
  clair par `Ecluse.redact`. Rapport dans `agent/specs/P2-178.md`. **Fini
  quand** : chiffre de fuite par longueur de nom de commune, exemples
  synthétiques, proposition de tâche si la fuite n'est pas nulle ; aucun
  fichier de `lib/` modifié.

- **P2-179** : banc seulement. Remarques de la veille de mesure du
  13 novembre : l'en-tête de `bench/ETAT.md` cite encore les commits
  `d85fb84` et `a263a83` ; `etat.sh` finit par « AVERTISSEMENT : types
  d'entité absents de la table de `run_redact_bench.dart`, comptés tels
  quels : identifiant ». Mettre l'en-tête à jour, ajouter `identifiant` à la
  table (ou expliquer pourquoi il doit rester compté tel quel). **Fini
  quand** : `etat.sh` sans avertissement ; chiffres du tableau de bord
  inchangés (ou l'écart expliqué ligne par ligne) ; aucun fichier de `lib/`.

- **P2-180** : adresses, chemin `Ecluse.redact`. Rapport
  `agent/specs/P2-178.md` (§ 3, § 7 tâche A) et banc `bench/generate_corpus_cedex.py`
  `--balayage`. Deux causes indépendantes de la longueur : la lettre « œ »
  (109 communes en libellé officiel ; « 59112 Annœullin » sort
  « [ADRESSE_1]œullin », une commune qui commence par « Œ » n'est pas masquée)
  et un mot en « M », « Me », « Pr », « Dr » suivi d'une lettre accentuée,
  refusé comme une civilité (28 communes en libellé officiel, 151 sans tirets).
  Test d'abord : mettre le balayage au tableau de bord (`bench/etat.sh`, lignes
  `libelle` et `capitales_tirets`), chiffre de départ. Puis corriger sans
  toucher aux civilités réelles devant un nom (« M. Éric », « Pr Émile » doivent
  rester lus comme civilités hors adresse : le vérifier sur les corpus de noms).
  **Fini quand** : `libelle` 163 → 26 ou moins, `capitales_tirets` 143 → 18 ou
  moins ; témoins flous à 0 ; noms derrière une civilité inchangés au tableau
  de bord ; `LIMITES.md` § 5.2 à jour.

- **P2-181** : suite de P2-180, tâche B de `agent/specs/P2-178.md` § 7.
  132 communes en écriture postale (cinquième mot) et 604 en libellé sans
  tirets (mots de liaison « et », « au », « à », « près », « devant »).
  Test d'abord : un témoin de sur-masquage (phrases où une adresse est suivie
  de mots ordinaires en capitales ou de « et », « à » : « 25000 BESANÇON ET
  ENVIRONS », « 70000 Vesoul à 9 h ») mesuré avant tout changement. **Fini
  quand** : `postale` 145 → 13 ou moins sans nouvelle prédiction sur les
  témoins ; sinon s'arrêter et rapporter les deux mesures, la décision revenant
  au mainteneur.

- **P2-182** : spec dans `agent/specs/P2-182.md`, aucun code. Une table des
  communes (`geo_communes.csv.gz`, déjà dans `ecluse_reference`) consultée par
  la détection d'adresses séparerait « 58699 Alpha livrés » de « 70000 Vesoul »
  (66 faux positifs de P2-177) et borne la fin des noms longs (P2-178).
  **Fini quand** : le document chiffre, par sonde sur les corpus existants, le
  gain (faux positifs retirés, fuites comblées) et la perte (commune mal
  orthographiée, sans accent, lieu-dit, ancienne commune fusionnée) ; donne le
  coût en taille et en temps ; dit si `ecluse_reference` devient une dépendance
  d'`ecluse_redact` et ce que cela change pour `ecluse_core` (règle 6 de
  `CLAUDE.md`) ; propose une décision au mainteneur sans la prendre.

- **P2-183** : mesure seule, prolonge P2-178 (§ « non mesuré »). Même
  balayage des 34 875 communes, texte entièrement en capitales et entièrement
  en minuscules, par `Ecluse.redact`. Rapport dans `agent/specs/P2-183.md`.
  **Fini quand** : nombre de communes en partie en clair par écriture et par
  cause, exemples synthétiques, proposition de tâche si la fuite n'est pas
  nulle ; aucun fichier de `lib/` modifié.

- **P2-186** : `ecluse_redact`, chemin `Ecluse.redact` puis `Ecluse.restore`.
  Trouvé le 15 novembre en rejouant la mesure photo (page de planning du lot
  42, texte relu par Tesseract : les barres du tableau disparaissent).
  Reproduction synthétique, sur `main` :
  `LEFÈVRE Olivier ASH 03 53 01 83 08 | RTT` puis, deux lignes plus bas,
  `LEFÈVRE Olivier AS 02 61 91 76 57 | M`. Le nom de la seconde ligne est
  détecté « LEFÈVRE Olivier AS » (la fonction « AS » est prise dans le nom) ;
  la première ligne reçoit le même jeton `[NOM_1]` ; la restauration rend
  « LEFÈVRE Olivier AS ASH » sur la première ligne. C'est une rupture de
  l'invariant de réversibilité (alerte « restauration non byte-exacte » de
  `run_redact_bench.dart`), plus grave qu'un défaut de score. Test d'abord :
  cas ci-dessus, et un témoin de lignes de planning sans séparateurs (nom en
  capitales + prénom + fonction courte en capitales : AS, ASH, IDE, ASD,
  AMP…) avec des homonymes, restauration comparée octet pour octet. **Fini
  quand** : restauration exacte sur le témoin ; la fonction n'est plus dans
  l'étendue du nom ; noms des corpus flous et des plannings inchangés au
  tableau de bord (aucun nom perdu) ; `LIMITES.md` à jour. Si la fonction ne
  se sépare pas du nom sans perdre de nom (prénom composé en capitales),
  s'arrêter et rapporter les deux mesures.

- **P2-187** : `AdresseDetector`, branche « tout en capitales ». Rapport
  `agent/specs/P2-185.md` et essai `agent/specs/P2-185-essai.patch`. Décision
  du 15 novembre, règle commune de `DECISIONS.md` (dans le doute, le côté qui
  protège) : l'essai est livré. Il fait passer la cause « déterminant
  initial » du balayage en capitales de 8 457 à 4 adresses ; en échange,
  « 12345 LE SERVICE DES ADMISSIONS. » est masqué comme une adresse, ce que la
  casse ordinaire fait déjà. Un masquage en trop coûte de la lisibilité, une
  commune en clair est une fuite. Test d'abord : un témoin versionné « nombre
  à cinq chiffres + LE/LA/LES + mots ordinaires », en capitales et en casse
  ordinaire, au tableau de bord, avec son chiffre de départ. Puis l'essai,
  repris tel quel ou resserré s'il retire des faux positifs sans perdre de
  commune. **Fini quand** : cause « déterminant initial » ≤ 10 sur le
  balayage en capitales ; témoin en capitales de P2-122 à 0 ; le nouveau
  témoin chiffré avant/après et écrit dans `LIMITES.md` (le masquage en trop
  y est dit) ; reste du tableau de bord inchangé.

- **P2-188** : `ecluse_redact`, chemin `Ecluse.redact`. Constat du 15 novembre
  (sonde sur `main`) : « NIR 2 33 10 70 482 017 23 » et « Numéro de sécurité
  sociale : 2 33 10 70 482 017 23. », clé fausse, partent en clair, alors que la
  même suite à clé juste est masquée. Une faute de frappe ou une erreur de
  lecture laisse ainsi passer un vrai NIR presque complet. La règle de
  `DECISIONS.md` (« clé validée ou rien ») vaut pour la **détection** d'un
  identifiant sans contexte ; ici, le libellé fait la preuve. Test d'abord : un
  témoin versionné, pour NIR, IBAN FR et RPPS, avec libellé fort devant
  (« NIR », « N° de sécurité sociale », « numéro SS », « IBAN », « RPPS ») et
  clé fausse (un chiffre changé, deux chiffres inversés, O pour 0, l ou I pour
  1), et un témoin négatif : même libellé suivi d'autre chose (« NIR : non
  communiqué », « IBAN : voir pièce jointe », un montant, une date). Correction :
  dans `ecluse_redact`, pas dans `ecluse_core` (le détecteur pur reste strict) ;
  masquer avec le type de l'identifiant, confiance basse, et un avertissement
  dans `RedactResult.warnings` (« identifiant à clé invalide masqué : à
  vérifier »), sans valeur dans le message. **Fini quand** : témoin positif
  100 % masqué ; témoin négatif sans masquage nouveau ; tableau de bord
  inchangé ailleurs (les 42 FP FINESS/SIREN du moteur seul ne bougent pas) ;
  `LIMITES.md` § 1 et `DECISIONS.md` (précision de la règle « clé validée ou
  rien ») proposés dans la PR, la décision restant au mainteneur.

- **P2-189** : spec dans `agent/specs/P2-189.md`, aucun code de production.
  Constat du 15 novembre : `RedactResult.mapping` est un `Map<String, String>`
  ordinaire ; un `print(result.mapping)` d'une application écrit toutes les
  valeurs en clair (vu en sonde). Le récapitulatif du projet promet une table
  « chiffrée » ; le code ne chiffre rien et ne conserve rien. **Fini quand** :
  le document propose un type dédié (`toString` sans valeur, pas de
  sérialisation implicite, `vider()`), mesure ce qu'il casse (API publique,
  démo, sas Claude Code, bancs, tests, README), propose une transition
  (dépréciation de `mapping` ou rupture en version majeure), dit ce que le
  chiffrement apporterait ou non tant que rien n'est conservé, et liste les
  décisions à prendre par le mainteneur.

- **P2-190** : `ecluse_redact`, `Ecluse.restore`. Sonde du 15 novembre sur
  `main` : `NOM_1` sans crochets, `[NOM_3]` inventé et `[NAME_1]` traduit
  restent tels quels sans aucun signal ; `\[NOM_1]` (échappement Markdown
  incomplet) donne `\Élodie Fabrier`. Test d'abord, avec ces quatre cas.
  Correction : une fonction de restauration qui rend aussi la liste des
  jetons de forme connue non restaurés (type et numéro seulement, jamais de
  valeur), sans changer `Ecluse.restore` pour ses appelants actuels ; et la
  barre oblique qui précède un jeton restauré retirée seulement quand elle
  échappe le crochet. Ne jamais restaurer par approximation (`[NOM_1]` ne
  matche pas `[NOM_10]`). **Fini quand** : les quatre cas testés ; aucun
  autre test ni chiffre du tableau de bord modifié ; README d'`ecluse_redact`
  à jour.

- **P2-187** (précision du 15 novembre) : la dépendance à P2-185 est levée.
  P2-185 est « bloquée » volontairement (sa mesure est fusionnée, #394) ;
  la session du 15 novembre a sauté P2-187 parce que sa dépendance n'était
  pas « fusionnée ». La fiche ci-dessus reste valable telle quelle.

- **P2-191** : `ecluse_redact`, `IdentifiantCleInvalideDetector`. Constat du
  15 novembre au rejeu de la mesure photo, sur `main` après P2-188 : les deux
  IBAN des pages EP-001 et EP-008 restent en clair alors qu'ils suivent le
  libellé « IBAN » ; le candidat n'accepte que des chiffres (`FRO2…` lu avec
  la lettre O) et un séparateur simple (ligne vide insérée par l'OCR entre
  deux groupes). La fiche de P2-188 demandait aussi O pour 0 et l ou I pour 1 :
  non couverts. Test d'abord : témoin versionné, synthétique, pour NIR, IBAN
  et RPPS derrière un libellé fort, avec O/o pour 0, l/I pour 1 dans le
  corps ou la clé, et une ligne vide (`\n\n`) entre deux groupes ; témoin
  négatif inchangé (« IBAN : voir pièce jointe », « NIR : non communiqué »,
  un mot ordinaire après le libellé). Ces confusions ne sont acceptées
  **que** derrière un libellé fort, jamais par les détecteurs stricts.
  **Fini quand** : témoin positif 100 % masqué avec l'avertissement « à
  vérifier » ; témoin négatif sans masquage nouveau ; tableau de bord
  inchangé ailleurs ; `LIMITES.md` § 2 à jour.

- **P2-192** : `ecluse_demo` (serveur du sas) et
  `integrations/claude-code/ecluse-sas`. P2-190 a livré
  `Ecluse.restoreAvecRapport` sans le brancher. Test d'abord : une réponse
  de LLM simulée contenant un jeton inventé (`[NOM_3]`) et un jeton sans
  crochets (`NOM_1`). **Fini quand** : la réponse du sas inclut la liste des
  jetons non restaurés (type et numéro, jamais de valeur) dans un champ
  nouveau, sans changer les champs existants pour les clients actuels ; la
  page de démo l'affiche en une ligne (« 2 jetons non restaurés ») ; aucune
  valeur dans les logs ; README de la démo à jour.

- **P2-193** : `ecluse_redact` (et tout appelant du dépôt). Spec
  `agent/specs/P2-189.md`, décisions de `DECISIONS.md` (15 novembre, P2-189).
  Test d'abord : un test qui affiche une table (`'$table'`, `print`,
  interpolation dans une exception) et vérifie qu'aucune valeur n'y figure ;
  il échoue sur `main` avec `Map<String, String>`. Puis le type, la migration
  de tous les appelants (démo, sas Claude Code, bancs, tests, README) et le
  passage des paquets concernés en 0.2.0 avec une entrée de changelog.
  **Fini quand** : aucun `Map<String, String>` de table de correspondance ne
  reste dans l'API publique ; `restore` et `restoreAvecRapport` exigent le
  nouveau type ; `TableDeCorrespondance.depuis(Map)` existe et est documenté ;
  les 5 tests d'égalité sont réécrits sans `==` ; tableau de bord inchangé ;
  aucune valeur dans un `toString`, une exception ou une sortie console ;
  `LIMITES.md` (table non chiffrée, non conservée) à jour.

- **P2-194** : `bench/` (tableau de bord), chemin `Ecluse.redact`. P2-188 et
  P2-191 ne sont mesurés que par des tests : « tableau de bord inchangé » ne
  prouve rien sur cette voie. Test d'abord : générateur synthétique versionné,
  seed explicite, avec pour chaque libellé fort (NIR, N° de sécurité sociale,
  numéro SS, IBAN, RPPS, ADELI) des identifiants à clé fausse, à clé juste
  lus avec O/o pour 0 et l/I pour 1, et coupés par une ligne vide ; plus un
  témoin négatif (« IBAN : voir pièce jointe », « NIR : non communiqué », mot
  ordinaire après le libellé, mêmes nombres sans libellé). **Fini quand** :
  une section d'`etat.sh` donne, par libellé et par variante, le nombre
  d'identifiants en clair et le nombre de masquages nouveaux sur le témoin
  négatif ; chiffres de départ écrits dans `bench/ETAT.md` ; `etat_attendu.py`
  échoue si un identifiant positif repasse en clair ; aucune correction de
  détecteur dans cette tâche.

- **P2-196** : mesure seulement, aucune correction. Sur `main`, balayage des
  communes en capitales (`etat.sh`) : 95 adresses sur 139 500 encore en
  partie en clair (cause « autre » 59, « ponctuation » 30, « déterminant
  initial » 4). **Fini quand** : rapport `agent/specs/P2-196.md` qui classe
  les 95 par forme de commune (ponctuation interne, apostrophe, longueur,
  mot neutre au milieu, etc.), avec 3 exemples synthétiques par classe (pas
  de nom de commune réel au-delà du référentiel déjà versionné), le nombre
  par classe, et pour chaque classe une piste de correction et son risque de
  faux positif ; rien ne change dans `lib/`.

- **P2-197** : `integrations/claude-code/ecluse-sas` (TypeScript). #405 a
  ajouté `nonRestaures` (`{type, numero}`) à la réponse de `POST /v1/restore`
  sans toucher au mod. Test d'abord : dans `tests/ecluse-sas.test.ts`, le
  faux moteur (`faux-moteur.mjs`) rend deux jetons non restaurés ; le mod
  doit le signaler. **Fini quand** : le mod affiche une ligne « N jeton(s)
  non restauré(s) » (nombre seulement, ni type, ni numéro, ni texte) quand
  la liste n'est pas vide, rien sinon ; un moteur ancien sans le champ
  fonctionne comme avant ; tests du mod verts là où ils s'exécutent ; la PR
  dit précisément ce que le mainteneur doit lancer sur son poste
  (`claude plugin test .`) puisque l'agent ne peut pas l'exécuter. Aucune
  dépendance npm ajoutée.

- **P2-198** : spec seulement (`agent/specs/P2-198.md`). Depuis #406,
  `Ecluse.versionMoteur` vaut « ecluse_redact 0.2.0 » ; un journal d'audit
  peut contenir des entrées des deux versions. Questions à trancher, chacune
  avec options, avantages, risques et une recommandation : la chaîne de
  version fait-elle partie de l'empreinte chaînée ; un journal mixte est-il
  valide, signalé ou refusé ; que dit l'export AIPD d'un changement de
  version en cours de période ; faut-il une entrée « changement de moteur ».
  **Fini quand** : la spec répond aux quatre questions en citant le code
  actuel d'`ecluse_audit` (fichiers et lignes), sans changer de code ; les
  décisions restent au mainteneur.

- **P2-199** : `IdentifiantCleInvalideDetector` (`ecluse_redact`), chemin
  `Ecluse.redact`. Constat de #408 : derrière « ADELI », les variantes
  `ocr_zero`, `ocr_un`, `ligne_vide` et `ocr_et_ligne_vide` laissent 50
  identifiants en clair chacune (200 / 300) ; NIR, IBAN et RPPS sont à 0. Test
  d'abord : cas ADELI dans `identifiant_cle_invalide_ocr_test.dart` (rouges
  sur `main`). Les confusions restent acceptées **seulement** derrière un
  libellé fort, jamais par les détecteurs stricts. **Fini quand** : les quatre
  cases ADELI du témoin P2-194 à 0 / 50 ; leur entrée retirée de
  `PLAFOND_LIBELLE_FORT` (plafond 0 partout) ; témoins négatifs inchangés
  (8 / 1 200 au plus) ; reste du tableau de bord inchangé ; `LIMITES.md` § 2
  à jour.

- **P2-200** : `bench/`, chemin `Ecluse.redact`, aucune correction de
  détecteur. Le balayage des communes en capitales écrit toujours
  « CEDEX n » ; le rapport `agent/specs/P2-196.md` note que l'exposition sans
  CEDEX n'est pas chiffrée et qu'aucun témoin ne mesure les faux positifs
  avec CEDEX. **Fini quand** : `etat.sh` donne le balayage en capitales sans
  CEDEX (axe `cedex=sans` du générateur), avec les mêmes causes que la
  version avec CEDEX ; un témoin versionné, seed explicite, de textes
  ordinaires « cinq chiffres + mot neutre (+ parenthèse, tiret) + CEDEX n »
  (« 70000 EUROS CEDEX ») donne son nombre de masquages ; chiffres de départ
  écrits dans `bench/ETAT.md`.

- **P2-201** : `AdresseDetector`, branche « tout en capitales ». Décision du
  15 novembre sur les trois questions de `agent/specs/P2-196.md` : (3) mesurer
  d'abord, c'est P2-200 ; (1) et (2) oui, mais **seulement quand « CEDEX »
  suit sur la même ligne**, conformément à la règle « dans le doute, le côté
  qui protège ». Test d'abord : un cas par classe de la spec (mot neutre en
  tête, parenthèse, tiret isolé ou blancs multiples, déterminant puis mot
  neutre, numéro de CEDEX après un nom), rouge sur `main`. **Fini quand** :
  balayage en capitales avec CEDEX ≤ 4 adresses en partie en clair (95 au
  départ) ; balayage sans CEDEX inchangé ou meilleur ; témoin de faux
  positifs de P2-200 chiffré avant/après et le coût écrit dans `LIMITES.md` ;
  reste du tableau de bord inchangé.

- **P2-202** : `ecluse_audit` (export seulement). Décision du 15 novembre :
  les quatre recommandations de `agent/specs/P2-198.md` sont retenues
  (`engine` reste dans le hash ; journal mixte valide, `verify` inchangé ;
  pas de nouvelle opération ; signalement par l'export). Test d'abord : un
  journal à deux versions avec trois changements, et l'ordre `0.10.0` après
  `0.2.0`. **Fini quand** : `AuditExport.moteurs` est une liste dans l'ordre
  de première apparition, avec rang et horodatage au jour ; l'export dit « le
  moteur a changé N fois pendant la période » quand N ≥ 1 ; aucun compte par
  version (recoupement P2-26) ; la mention d'honnêteté ajoutée ; version du
  format d'export augmentée ; `LIMITES.md` § 8 et `agent/specs/P2-09.md` à
  jour.

- **P2-203** : mesure seulement, rien dans `lib/`. P2-188 et P2-191 masquent
  à confiance 0,3 avec l'avertissement « à vérifier » ; le banc ne lit ni la
  confiance ni l'avertissement. **Fini quand** : `etat.sh` donne, sur le
  témoin P2-194, la répartition des confiances des masquages et le nombre de
  documents avec l'avertissement « à vérifier » (positifs et négatifs) ;
  aucun texte ni valeur dans la sortie ; chiffres de départ dans
  `bench/ETAT.md`.

- **P2-204** : `ecluse_redact`, chemin `Ecluse.redact`. Constat de #417 (témoin
  P2-194, 50 documents) : un ADELI à clé fausse derrière son libellé est
  masqué par `AdeliDetector` à confiance 0,6 sans avertissement « à vérifier »,
  alors que NIR, IBAN et RPPS à clé fausse (confiance 0,3) en portent un ; les
  ADELI lus par OCR (P2-199) en portent un. Rien ne fuit : c'est une
  incohérence d'information donnée à l'utilisateur. Test d'abord : un cas
  « ADELI » + 9 chiffres à clé fausse, sans avertissement sur `main`. Ne pas
  changer la confiance 0,6 (`LIMITES.md` § 2) sans le dire : si l'avertissement
  ne peut pas se donner sans la changer, s'arrêter et poser la question dans la
  PR. **Fini quand** : l'avertissement est donné pour ce cas, sans valeur dans
  le message ; au tableau de bord, « avertissement à vérifier » passe de 0 à
  50 / 300 sur ADELI × `cle_fausse` ; négatifs inchangés (0 / 1 200) ; reste
  du tableau de bord inchangé ; `LIMITES.md` à jour.

- **P2-205** : spec seulement (`agent/specs/P2-205.md`), aucune ligne de
  code. Constat de #415 (chemin `Ecluse.redact`, balayage en capitales sans
  CEDEX) : 338 adresses sur 139 500 gardent une partie du nom de commune en
  clair (longueur 216, autre 60, ponctuation 30, déterminant initial 16). La
  cause « longueur » est la commune de plus de quatre mots, que la suite
  devant « CEDEX » de P2-181 couvrait. **Fini quand** : la spec donne, pour
  chaque cause, le motif du détecteur en cause (fichier et lignes), les
  options avec avantages et risques de faux positifs (sans CEDEX, un texte
  ordinaire peut ressembler à une commune longue), une mesure à faire avant la
  correction, et une recommandation ; les décisions restent au mainteneur.

- **P2-206** : mesure seulement, aucun `lib/` modifié. `agent/specs/P2-205.md`
  classe 338 adresses en cinq formes avec un script jetable non versionné.
  **Fini quand** : la ventilation (axe `cedex=sans`) est reproductible par
  `etat.sh` et donne les cinq formes ; le témoin `generate_corpus_commune_suivie.py`
  est rejoué avec une règle candidate « nom exact du référentiel » écrite
  **hors** de `lib/` (script de mesure), puis avec « fin de ligne », avec le
  coût en caractères masqués en trop pour chacune, plus un témoin « 08061 SON »
  (code postal suivi d'un mot qui est aussi un début de commune) ; chiffres
  de départ dans `bench/ETAT.md`.

- **P2-207** : `EtablissementDetector`, chemin `Ecluse.redact`. Constat de
  `agent/specs/P2-205.md` § E : 29 adresses en défaut viennent de ce
  détecteur (« MAS », « CH » trouvé au milieu de « BUËCH », étendue masquée
  qui dépasse le nom). Test d'abord : « VAL BUËCH MÉOUGE » et un « MAS
  GRENIER » suivi d'une ligne, rouges sur `main`. **Fini quand** : mot-clé
  seulement à une frontière de mot (accents compris), étendue limitée au nom ;
  mesure avant/après du corpus établissements et du balayage en capitales sans
  CEDEX ; aucun établissement réel du corpus perdu ; reste du tableau de bord
  inchangé.

- **P2-208** : détecteur de civilité (`name_detector.dart`). Après P2-201, la
  seule adresse du balayage en capitales avec CEDEX encore en défaut est
  « SAINT M HERVE » (le « M » est lu comme une civilité). **Fini quand** :
  balayage en capitales avec CEDEX à 0 ; témoin de faux titres (P2-180)
  inchangé ; vrais « M » civilité (« M DUPONT ») toujours masqués.

- **P2-209** : refactor sans changement de comportement. `ecluse.dart` (P2-204)
  porte une copie locale de Luhn parce que celle de `ecluse_core` n'est pas
  exportée. Exporter la fonction d'`ecluse_core` si cela ne change pas
  l'interface publique de façon incompatible ; sinon s'arrêter et poser la
  question dans la PR (changement d'API). **Fini quand** : une seule
  implémentation de Luhn dans le dépôt ; tous les tests et le tableau de bord
  inchangés.

- **P2-210** : mesure seulement. Le témoin de P2-200 est un pire cas construit
  (113 / 200 phrases masquées en trop depuis P2-201). **Fini quand** : un
  générateur versionné, graine 42, de courriers synthétiques en capitales
  (en-têtes, références, montants) dont le motif de construction est écrit ;
  `etat.sh` donne le nombre de phrases masquées en trop sur ce corpus ; chiffre
  de départ dans `bench/ETAT.md` ; aucune correction.

- **P2-211** : mesure seulement, rien dans `lib/`. #427 ne couvre que les
  mots de son générateur. **Fini quand** : un générateur versionné, graine
  42, produit 400 phrases par mot de `mots_neutres.dart` (forme accentuée et
  forme sans accent quand elle diffère, capitales et casse ordinaire,
  « nombre à cinq chiffres + mot ») ; `etat.sh` donne, par mot et par casse,
  le nombre de phrases où le nombre est masqué en adresse (chemin
  `Ecluse.redact`) ; chiffres de départ dans `bench/ETAT.md` ; aucune
  correction.

- **P2-213** : `AdresseDetector`, chemin `Ecluse.redact`. Constat de #427,
  vu à la main, fréquence non mesurée : « 52417 GRAFFIGNY CHEMIN CEDEX 7 »
  suivi d'une ligne « 39314 NUMEROS EN ATTENTE » donne « 52417 GRAFFIGNY
  [ADRESSE_1] » : le mot de voie dans le nom de commune fait lire une voie, et
  le code postal et le début du nom restent en clair. C'est une fuite : elle
  passe avant le masquage en trop. Mesurer d'abord : balayage versionné des
  communes du référentiel dont le nom contient un mot de voie (CHEMIN, RUE,
  PLACE, etc.), avec et sans CEDEX, suivies ou non d'une ligne « code postal
  + mot », capitales et casse ordinaire. **Fini quand** : ce balayage est dans
  `etat.sh`, chiffré avant/après ; 0 adresse en partie en clair sur ce
  balayage ; vraies voies (« 12 CHEMIN DES VIGNES ») toujours masquées ;
  reste du tableau de bord inchangé ; `LIMITES.md` à jour.

- **P2-214** : `AdresseDetector`, branche « tout en capitales », sans CEDEX.
  Décision du 16 novembre (`DECISIONS.md`) : la règle « nom exact du
  référentiel » est retenue pour les formes A (plus de quatre mots), C
  (parenthèse, tiret isolé, blancs multiples) et D (déterminant puis mot
  neutre) de `agent/specs/P2-205.md` ; simulation de #423 : 309 → 0 sur A à D,
  coût +0 au témoin « commune suivie », 1 / 200 au témoin déterminant (« LA
  REUNION »). La forme B (mot neutre en tête : « SON », « VERS ») est
  **laissée de côté** : coût simulé +200 / 200 au témoin construit. Le
  détecteur reste pur (référentiel embarqué, pas de réseau). Test d'abord : un
  cas par forme, rouge sur `main`. **Fini quand** : balayage sans CEDEX de 309
  à 57 au plus (la forme B reste) ; balayage avec CEDEX inchangé (0) ; témoins
  P2-167, P2-187, P2-200, P2-206 (commune neutre) et P2-210 chiffrés
  avant/après, aucun ne se dégrade de plus de ce que la simulation annonçait,
  tout écart expliqué ; `LIMITES.md` à jour (dont « LA REUNION » et la forme
  B) ; reste du tableau de bord inchangé.

- **P2-215** : spec seulement (`agent/specs/P2-215.md`), aucune ligne de
  code. Le « 0 » de #423 est vrai par construction : la règle lit les noms du
  référentiel. **Fini quand** : la spec chiffre, sur un balayage d'écritures
  générées depuis le référentiel (« ST » / « STE » pour SAINT / SAINTE,
  apostrophe ou tiret perdus, une lettre fautive, accent perdu), la part que
  le nom exact ne couvre pas (script de mesure hors `lib/`, versionné dans
  `bench/`) ; donne les options (normalisation avant comparaison, distance
  d'édition bornée, rien) avec leur risque de faux positifs, et une
  recommandation ; les décisions restent au mainteneur.
