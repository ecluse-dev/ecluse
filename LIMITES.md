# Limites connues d'Écluse (v0)

**Écluse réduit le risque, il ne l'annule pas.**

Ce document complète le `README.md` : il ne décrit pas ce qu'Écluse protège,
mais **ce qu'il ne protège pas encore**. Afficher une limite est une mesure
de sécurité à part entière — un faux sentiment de protection est pire qu'une
absence de protection connue.

---

## L'essentiel en dix lignes

1. **Deux niveaux de confiance.** Un `[NIR_1]` masqué est une quasi-certitude
   (clé de contrôle vérifiée) ; un `[NOM_1]` masqué est une estimation
   (heuristique v0).
2. **Non détectés** : le BIC, les secrets sans forme reconnaissable (voir §7), les IBAN
   non français, les identifiants ADELI (un ADELI à clé valide est masqué
   mais **sous l'étiquette FINESS** ; à clé invalide il n'est pas détecté),
2. **Non détectés** : le BIC, les clés d'API et autres secrets, les IBAN
   non français, les identifiants ADELI **sans le mot « ADELI » accolé** (à clé
   valide ils sont masqués mais sous l'étiquette FINESS ; à clé invalide ou
   corses, ils ne sont pas détectés),
   les lieux isolés sans structure d'adresse (« reçu à Nantes »).
3. **Fichiers** : `.txt`, `.md`, `.docx`, `.odt` et `.pdf` **à texte
   natif** (voir § 4). Les images, les scans, les PDF-image et le manuscrit
   sont **refusés explicitement** — jamais lus à moitié. Les en-têtes, pieds de page, notes et commentaires de
   `.docx`/`.odt` ne sont pas lus (avertissement `ignored_parts`).
4. **Sur-masquage possible** : en cas de doute, Écluse masque. Un mot
   capitalisé adjacent à un prénom connu, ou un SIREN pris pour un FINESS,
   peuvent être masqués à tort. C'est un choix, pas un défaut. À l'inverse,
   le titre professionnel (Dr, Pr, Me) est masqué avec le nom ; la civilité
   de genre (Monsieur, Mme) reste en clair, donc le genre reste visible.
5. **Une seule entorse à la fidélité** : quand une même personne est nommée
   de deux façons, la re-mention est harmonisée sur la forme la plus
   complète à la restauration. Aucun caractère n'est perdu.
6. **Hors périmètre v0** : dictée vocale. Le journal d'audit existe comme
   bibliothèque (`ecluse_audit`, voir § 8) mais **n'est pas branché** dans
   `Ecluse.redact`. L'estimation de ré-identification et la généralisation
   existent comme bibliothèque (`ecluse_reid`) mais **ne sont pas branchées**
   dans `Ecluse.redact` ; leurs limites sont au § 7.

Le détail de chaque point suit.

---

## 1. Deux familles de détecteurs, deux niveaux de confiance

**Validation structurelle** (NIR, RPPS, IBAN, FINESS) : chaque candidat est
vérifié par sa clé de contrôle (mod 97, Luhn, ISO 7064). Un candidat
syntaxiquement plausible mais à clé invalide est rejeté. Le taux de faux
positifs est proche de zéro, et un identifiant détecté est presque toujours
réel.

> **Exception FINESS.** Contrairement au NIR, au RPPS et à l'IBAN dont la
> structure est unique, le FINESS partage la sienne avec le SIREN
> (identifiant d'entreprise : 9 chiffres, même clé Luhn). La validation
> structurelle **ne peut pas** les distinguer. En l'absence du mot-clé
> « FINESS » à proximité, un SIREN peut donc être masqué par précaution —
> sur-masquage d'un identifiant d'organisation, jamais une fuite.

**Heuristiques v0** (nom, adresse, date de naissance, téléphone, email,
établissement) : aucune structure vérifiable n'existe pour ces types. La
détection repose sur des motifs et du contexte (civilité, prénom connu,
mot-clé de voie ou d'établissement), pas sur une clé de contrôle. Ce sont
des approximations volontairement prudentes (« en cas de doute, on masque »),
pas des preuves. Elles seront remplacées par un modèle NER local en phase 2
(voir `ROADMAP.md`).

**Email.** Détectés : adresse standard, sous-adressage (`+tag`),
sous-domaines, TLD longs, majuscules, et les obfuscations entre crochets ou
parenthèses `[at]`, `(at)`, `[arobase]`, `(arobase)` suivies d'un domaine.
**Non détectés** : `jean at example.fr` et `jean arobase example.fr` en
clair (trop proche du texte courant), `[dot]`/`(point)` à la place du point,
adresses avec caractères accentués dans la partie locale (`é@…`),
domaines internationalisés (IDN), et toute adresse coupée par un saut de
ligne ou un trait d'union de césure.

**Fichiers : contenus non lus.** `.docx` et `.odt` ne sont lus que dans leur
corps (`word/document.xml`, `content.xml`). Les **en-têtes, pieds de page,
notes de bas de page et de fin, commentaires** (docx) et les **en-têtes et
pieds de page** (odt) ne sont ni extraits ni masqués ; quand ils contiennent
du texte, l'ingestion le signale par l'avertissement `ignored_parts`. Un
document dont l'espace de noms XML utilise un autre préfixe que `w:` /
`text:`, une section CDATA, une entité XML illisible ou un fichier texte avec
des caractères NUL (UTF-16 sans BOM) sont **refusés avec un motif**. Un
document sans aucun texte reçoit l'avertissement `empty`.
**Identifiant collé à un nombre.** Un NIR, un RPPS, un IBAN ou un FINESS
suivi ou précédé d'un nombre séparé par un simple blanc est détecté
(`NIR 1 85 05 78 006 084 91 12 ans`). **Reste non détecté** : un
identifiant à espacement *irrégulier* (espaces multiples, tabulation,
espace insécable) **et** collé à un nombre voisin, et un FINESS écrit avec
des espaces suivi d'un nombre.

**NIR et IBAN : variantes de forme.** Le NIR est reconnu avec un mois de
naissance fictif (`00`, `20` à `42`, `50` à `99`, d'après la nomenclature
DGFiP citée par le mainteneur ; l'instruction INSEE n'a pas été lue) dès que
la clé de contrôle est valide, et avec les séparateurs espace, point, tiret,
barre oblique, tabulation, espace insécable et espaces typographiques (dont
l'espace fine U+2009). Les mois 13 à 19 et 43 à 49 restent rejetés. L'IBAN
accepte espace, tiret, point et barre oblique.
**Non détecté** : un identifiant coupé par un **saut de ligne**.

**Ne pas confondre les deux.**

## 2. Identifiants non couverts

- **BIC** : non détecté (seul l'IBAN l'est).
- **IBAN non français** (DE, BE, ES…) : seul l'IBAN `FR` est détecté.
- **FINESS de Corse** (préfixes 2A/2B) : le détecteur n'accepte que des
  chiffres.
- **Secrets.** `SecretDetector` reconnaît des formats à préfixe (jetons
  GitHub, identifiants d'accès AWS, clés Google `AIza`, Stripe *live*, Slack,
  Anthropic, OpenAI), les blocs PEM de clé privée et le
  `utilisateur:motdepasse` des chaînes de connexion. **Non détectés** : un
  mot de passe choisi par un humain, la clé secrète AWS seule (40 caractères
  sans préfixe), les clés Stripe de test, tout jeton propriétaire sans
  préfixe connu, et tout ce que seule l'entropie révélerait (pas de détection
  par entropie : hachages, UUID et identifiants de commit auraient le même
  aspect). Les préfixes viennent de sources secondaires et évoluent
  (OpenAI, GitHub) : la liste exige un entretien. Un PEM dont les sauts de
  ligne sont remplacés par `\n` littéraux est reconnu ; un PEM sans ligne
  `END` est masqué jusqu'à la fin de son corps (confiance 0,8). Masquer ne
  rend pas inoffensif un secret déjà envoyé ailleurs : l'avertissement
  (`RedactResult.warnings`) demande de le révoquer. Les secrets ne sont
  **pas restaurés** par défaut (`restoreSecrets: false`) ; le mode strict
  (`refuseSecrets: true`) refuse le texte au lieu de le masquer.
  Mesure : 0 détection sur 5 000 documents synthétiques sans secret
  (corpus v3, étendu et trois corpus flous, seed 42).
- **ADELI.** Pas de détecteur dédié (spécifié, non implémenté). Sur le
  corpus étendu du benchmark (`bench/README.md`), un ADELI à clé Luhn valide
  est masqué par `FinessDetector` — donc étiqueté « FINESS » — et un ADELI à
  clé invalide, même précédé du mot « ADELI », **n'est pas détecté**.
- **Secrets** (clés d'API, jetons, clés privées, chaînes de connexion) : non
  détectés. Spécifié (`agent/specs/P1-07-secrets.md`), pas implémenté.
- **ADELI.** `AdeliDetector` n'émet qu'avec le mot « ADELI » à moins de
  30 caractères avant le nombre, sans point ni chiffre entre les deux. Avec
  ce mot : clé Luhn valide → confiance 0,95 ; clé invalide ou numéro corse
  (`2A`/`2B`, aucune clé vérifiée) → 0,6, masqué quand même. L'algorithme de
  clé (Luhn) est une hypothèse : la fiche officielle n'a pas été lue. Sans le
  mot « ADELI », le nombre reste traité comme un FINESS/SIREN (étiquette
  `finess`, ou rien si la clé est invalide) ; un autre nombre de 9 chiffres
  placé dans les 30 caractères après « ADELI » (un SIREN voisin) est
  étiqueté ADELI : sur-masquage assumé. Un mot ADELI placé *après* le nombre
  n'est pas reconnu.
- **INS** (Identité Nationale de Santé) : `InsDetector` masque les marqueurs
  textuels et OID (« Matricule INS »), pas le numéro qui suit ; celui-ci n'est
  masqué que si c'est un NIR à clé valide.
- Les identifiants professionnels autres que RPPS et FINESS, et les
  identifiants d'établissement autres que FINESS.

## 3. Lieux et quasi-identifiants

Une adresse postale complète (numéro + type de voie + code postal + commune)
est masquée. Un simple nom de ville ou de lieu, mentionné sans cette
structure (« reçu à Nantes »), ne l'est pas.

Ce n'est pas un oubli : la généralisation géographique — remplacer un lieu
trop précis par une zone plus large — est un traitement **différent** du
masquage, prévu en phase 2. En attendant, un lieu isolé reste un
quasi-identifiant en clair dans le texte envoyé au LLM.

Depuis P2-04, `Ecluse.redact(texte, riskReference: référence)` ajoute un
**rapport de risque** (`RedactResult.risque`) qui repère le lieu, l'âge et la
profession de santé restés dans le texte masqué et estime la ré-identification.
Il **ne change pas le texte envoyé** : le lieu reste en clair tant que
l'application n'agit pas (la généralisation appliquée est prévue ensuite, à la
demande de l'appelant). Sans référence, rien n'est évalué et `risque` est nul.

## 4. Fichiers pris en charge (`ecluse_ingest`)

Sont ingérés : `.txt`, `.md`, `.docx`, `.odt` et `.pdf` à texte natif.

**PDF.** Un PDF n'est accepté que si Écluse peut affirmer que **tout son
contenu informatif est du texte lu** ; sinon le document entier est refusé,
avec un motif stable (`IngestRefused.code`) :

| Motif | Cas |
|---|---|
| `sans_texte` | scan pur, image avec quelques caractères, document sans page lue |
| `partiellement_numerise` | pages de texte et pages image mêlées (pages listées) |
| `numerise_couche_ocr` | texte invisible (`3 Tr`) laissé par un OCR sur un scan |
| `texte_illisible` | police sans table `ToUnicode`, caractères de zone privée / U+FFFD, bruit hors du jeu de caractères d'un texte français |
| `chiffre` | PDF chiffré, **même ouvrable sans mot de passe** |
| `malforme` | pas d'en-tête, pas de `%%EOF`, `startxref` qui ne pointe pas sur une table de références, bibliothèque en échec |
| `plafond_taille`, `plafond_pages`, `plafond_duree` | plus de 50 Mo, plus de 200 pages, plus de 30 s |

Le refus d'un PDF tronqué, à table `xref` cassée ou chiffré sans mot de passe
est une **politique** d'Écluse, pas la conséquence d'un échec de lecture : la
bibliothèque (`pdf_graphics`, version fixée) reconstruit sans erreur ces
fichiers ; un contrôle de structure préalable les refuse.

Avertissements (`IngestedText.warnings`) pour ce qui n'est **pas lu** :
`images_non_traitees:<pages>` (image sur une page de texte : tampon,
signature), `metadonnees_non_extraites`, `annotations_non_extraites`,
`formulaires_non_extraits`, `javascript_ignore` (jamais exécuté),
`pages_blanches:<n>`. **Le contenu des métadonnées, annotations et champs de
formulaire n'est pas détecté** : il peut contenir un identifiant.

Limites propres au PDF :

- **Ordre de lecture** (colonnes, tableaux) et **coupures de ligne** : un
  identifiant coupé par une fin de ligne ou une césure peut échapper à la
  détection (cas `texte_iban_coupe` du jeu synthétique).
- Une image atteinte seulement par un XObject de formulaire n'est pas vue
  (pas d'avertissement `images_non_traitees`). Une page de texte avec une
  image qui porte du texte (texte incrusté dans une image) est acceptée avec
  avertissement ; le texte de l'image n'est pas lu.
- Le plafond de durée est vérifié **entre** les pages ; une seule page
  pathologique ne peut pas être interrompue.
- Seuils de départ non calibrés sur des documents réels (aucun n'est
  utilisé) : 20 caractères alphanumériques pour qu'une page « ait du texte »,
  5 % de caractères parasites, 50 % de lettres/chiffres. Mesure sur le jeu
  synthétique : 18 fichiers, tous conformes à `bench/pdf/expected.json` ;
  200 pages de 30 lignes en ~0,3 s.
- `pdf_graphics` est récent (dix versions majeures en trois semaines au moment
  du choix), à mainteneur unique, et exige Dart ≥ 3.5. Ses dépendances
  transitives (dont `bidi`) n'ont pas été auditées par nous. La version est
  fixée exactement.

**Aucune image, aucun scan, aucun manuscrit n'est traité.** Un OCR ou une
reconnaissance manuscrite introduirait des erreurs de lecture qui feraient
échouer silencieusement la validation structurelle : un chiffre mal reconnu
dans un NIR le fait rejeter comme invalide — et donc **fuir en clair**.
C'est une posture assumée, pas une limite technique temporaire.

## 5. Limites résiduelles des heuristiques nom / adresse

### 5.1 Faux positifs assumés

Le détecteur de noms applique une règle symétrique (nom avant ou après le
prénom reconnu, quelle que soit la casse) : un mot capitalisé non nominal
mais adjacent à un prénom connu — une salutation ou un connecteur en début
de phrase — peut être masqué à tort. Compromis délibéré : mieux vaut un
faux positif qu'une fuite.

Les exclusions (unités de mesure dans le détecteur d'adresse, pour ne pas
confondre « 10000 UI » avec un code postal ; sigles cliniques et
administratifs dans le détecteur de noms, pour ne pas masquer une échelle
comme « EVA ») reposent sur des **listes finies et documentées**, pas sur
une détection générale. Un sigle ou une unité absents de ces listes
pourraient encore être mal classés.

Le détecteur d'établissement peut, lui, absorber un mot capitalisé isolé
qui suit immédiatement un nom d'établissement, sans ponctuation ni mot
minuscule pour l'arrêter (« Hôpital Saint-Louis Réunion » où « Réunion »
introduit une phrase). C'est du sur-masquage, jamais une fuite : le nom de
l'établissement, lui, est bien protégé. Distinguer un mot appartenant au
nom d'un mot qui le suit relève du NER de la phase 2.

### 5.2 Entités coupées par la mise en forme

**Règle générale : un span ne traverse jamais un saut de ligne.** Ce choix
évite qu'un span engloutisse par erreur le début d'une ligne sans rapport —
c'était un bug réel, corrigé une première fois de façon absolue, puis affiné
par l'exception ci-dessous.

**Exception unique : voie → code postal + commune.** Un span d'adresse peut
traverser exactement un séparateur de ligne, à condition stricte que la
ligne suivante soit une ligne « code postal (5 chiffres) + commune » au sens
strict — la commune devant commencer par une majuscule. Deux séparateurs
consécutifs (ligne vide) interrompent le span, tout comme une ligne suivante
qui ne correspond pas à ce motif. Cette exception ferme une fuite réelle :
le format très courant « voie sur une ligne, code postal + commune sur la
suivante » laissait jusqu'ici le numéro et l'odonyme en clair.

**Ce que l'exception ne couvre pas (hors périmètre v0, assumé) :**

- **Le complément d'adresse intercalé** entre la voie et le code postal
  (`Bâtiment C`, `Résidence les Tilleuls`, `BP 42`, `Chez M. Dupont`…) coupe
  le span comme n'importe quelle ligne étrangère : ce n'est pas un motif
  `CP_COMMUNE`, donc la détection s'interrompt au même titre que du texte
  sans rapport. Élargir la règle pour l'absorber romprait la garantie qui
  protège justement contre le bug d'origine (span qui avale une ligne
  quelconque). Résolution correcte prévue en phase 2 (NER local).
- **Le destinataire** placé au-dessus de la voie (nom de personne ou de
  société sur la ligne précédente) n'est jamais absorbé dans le span
  d'adresse : il relève exclusivement du détecteur de noms.
- Toute autre entité coupée par une mise en forme multiligne (un nom
  d'établissement qui continue sur la ligne suivante, par exemple) reste
  soumise à la règle générale absolue : aucun span ne traverse la ligne.
  Seule l'adresse bénéficie de cette exception, et seulement dans la forme
  voie → CP + commune.

Dans tous les autres cas, le coût reste symétrique : entre « fusionner deux
lignes à tort » et « rater une entité coupée par la mise en forme », le
second risque est jugé préférable — mais les deux méritent une vigilance
humaine sur des documents à la mise en page inhabituelle.

**Patronyme sans civilité : hors périmètre v0.** Le correctif qui absorbe le
patronyme en casse de titre (« Nathalie Loyer », « Sophie Dupont-Martin »,
« Jean de La Fontaine ») ne s'arme qu'après une civilité reconnue (`Madame`,
`Mademoiselle`, `Monsieur`, `Dr`, `Docteur`, `Pr`, `Professeur`, `Me`…)
suivie d'un prénom. Un patronyme mentionné sans civilité (« Camille Verdier
a signé le devis. », sans « Mademoiselle » devant) suit le comportement v0
inchangé : seul le prénom du gazetteer est détecté par la règle
bidirectionnelle générique : le nom de famille adjacent n'est absorbé que
s'il est en MAJUSCULES, ou s'il a déjà été établi ailleurs dans le document
(voir § 5.4). Élargir l'ancrage à « tout mot capitalisé après un prénom,
civilité ou non » ferait exploser les faux positifs sur les débuts de
phrase — cet arbitrage n'est pas tranché ici, il attend le NER local de la
phase 2.

*Mise à jour (P2-14).* Le patronyme seul établi dans un document précédent du
même `Dossier` est désormais masqué ; le patronyme seul en première mention
reste non couvert. Mesures et coût : voir § 5.4.

**Titres professionnels masqués, civilités de genre en clair.** Le
détecteur distingue désormais deux familles. Les **titres professionnels**
(`Dr`, `Docteur`, `Pr`, `Professeur`, `Me`) sont masqués AVEC le nom qu'ils
introduisent : « Dr Martin » devient « [NOM_1] », le titre ne fuit plus.
La profession, quasi-identifiant de premier ordre en contexte hospitalier,
est donc protégée. Les **civilités de genre** (`M.`, `Mme`, `Mademoiselle`,
`Monsieur`, `Madame`) restent, elles, en clair : « Monsieur Martin »
devient « Monsieur [NOM_1] ». Le genre reste donc visible dans le texte
envoyé au LLM. Ce choix est délibéré : en français, le genre porte
l'accord grammatical, et le masquer dégraderait la réponse du modèle
(« [NOM_1] est venue » deviendrait irrécupérable). Un DPO doit savoir que
le genre, lui, n'est pas retenu par l'écluse en v0. Son masquage optionnel
est un arbitrage prévu en phase 2.

### 5.3 Cohérence des pseudonymes et fidélité de la restauration

Deux mentions reconnues comme la même personne reçoivent le **même jeton**,
pour que le LLM ne croie pas à deux personnes distinctes. Cas couverts :

- ordre nom/prénom inversé (« Dubreuil Thomas » / « Thomas Dubreuil ») ;
- nom de famille seul après une présentation complète (« Dr Costa » après
  « Dr Nadia Costa ») ;
- initiale + nom (« S. Reynaud » après « Mme Sandra Reynaud ») ;
- prénom seul après une mention complète.

**Conséquence sur la restauration.** Un jeton ne peut restituer qu'une seule
graphie (remplacement global dans la réponse du LLM, sans notion de
position) : la re-mention partielle est donc harmonisée sur la forme la plus
complète déjà rencontrée. Aucun caractère n'est perdu ni déplacé ailleurs
dans le document — seul le libellé de cette re-mention change, parfois de
façon un peu artificielle (ex. « S. » suivi du prénom complet restauré).

**Deux personnes, un patronyme.** Deux civilités de sexe différent
(« M. Jean Dupont », « Mme Dupont ») ne sont jamais fusionnées : un couple
garde deux jetons. Deux personnes **de même sexe** (ou sans civilité) qui
partagent un patronyme sont en revanche fusionnées (« M. Jean Dupont » et
« M. Dupont » peuvent désigner deux frères) : mieux vaut un jeton partagé
qu'un patronyme en clair.

C'est le **seul cas connu** où le texte restauré n'est pas octet-pour-octet
identique à l'original, **hors dossier** (voir ci-dessous pour les dossiers).
Choix assumé : cohérence d'identité pour le LLM > fidélité mot-à-mot d'une
re-mention.

**Entre plusieurs documents (dossier).** Sans `Dossier`, chaque appel repart de
`[NOM_1]` : la même personne reçoit des jetons différents d'un document à
l'autre et deux personnes peuvent recevoir le même jeton. Avec
`Ecluse.redact(texte, dossier: d)`, l'état est conservé **en mémoire
seulement** (jamais sérialisé ; perdu au redémarrage ; un dossier fermé refuse
de masquer et de restaurer). Règle de noms entre documents (décision N1) :
seule une identité **complète** identique (au moins deux segments) garde son
jeton ; une mention partielle (« Mme Verdier » après « Mme Sophie Verdier »)
reçoit un **nouveau** jeton, car la fusion par patronyme entre documents
exposerait à de fausses fusions sans qu'on puisse les mesurer. Conséquence
assumée mais coûteuse : le LLM voit deux personnes là où il n'y en a qu'une.
Mesure sur les corpus synthétiques de dossiers (P2-06) : les collisions
disparaissent (réaliste 16–17 % → 0 %), mais la cohérence des noms baisse
(réaliste 63 % → 44–46 %) car l'ancienne valeur tenait en partie à la
coïncidence de la numérotation.
**N2 à la demande.** `Dossier(regle: RegleNoms.inclusion)` applique entre
documents la règle d'inclusion d'un document : une mention partielle rejoint
l'unique identité qu'elle recoupe, avec les mêmes garde-fous (civilités de sexe
différent, plusieurs identités possibles → nouveau jeton). Mesure sur les
corpus synthétiques de dossiers (P2-13, 400 documents, graines 42 et 7) :
cohérence des noms 100 % (réaliste, témoin) et 83–88 % (adversarial) contre
44–46 %, 0 % et 28–34 % avec N1 ; aucune collision ni fausse fusion mesurée ;
mais **restaurations non identiques** 25 % (réaliste), 40–42 % (adversarial) et
78 % (témoin) contre 0 %, 9–13 % et 0 % avec N1, car un jeton ne restitue
qu'une graphie : « Mme Verdier » est restaurée « Mme Sophie Verdier ». Le corpus
ne contient pas de vrais homonymes inconnus du dossier ; le risque de fausse
fusion entre documents, non mesuré hors ce corpus, reste entier.
Un **jeton littéral** déjà attribué dans le dossier et retrouvé en clair dans
un texte ultérieur est signalé par un avertissement, le texte n'est pas
modifié, mais sa restauration n'est alors **pas identique** : c'est un
deuxième cas connu de restauration non octet-pour-octet. Le dossier ne protège
pas du contenu en clair, des quasi-identifiants ni des métadonnées de requête,
et la menace de recoupement entre dossiers (T1) reste une hypothèse non
confirmée : le cloisonnement retenu (C0) ne rend pas les numérotations
indistinguables.

### 5.4 Portée du rattrapage des mentions partielles

Les mentions partielles sont rattrapées **uniquement via un patronyme établi
dans le document courant** — jamais de liste externe, jamais
d'apprentissage. Limites de cette approche :

- Le patronyme n'est extrait que de mentions **certaines** (civilité, ou
  couple prénom + nom d'au plus deux mots) ; jamais d'une mention déjà
  incertaine.
- Le rattrapage n'apparie un patronyme qu'avec le mot capitalisé qui le
  **suit**, jamais celui qui le précède — pour limiter le risque de faux
  positif en début de phrase. Un prénom hors gazetteer précédant un
  patronyme connu n'est donc pas rattrapé.
- **Homonymie non résolue** : si le même patronyme a été établi pour deux
  personnes distinctes dans le document, une mention partielle ultérieure
  ne fusionne avec aucune des deux. Elle est masquée, mais reçoit un jeton
  à part — pas de fuite, pas de rattachement non plus.
- Un patronyme coïncidant avec un mot du quotidien (au-delà des sigles et
  médicaments déjà exclus) pourrait, en théorie, déclencher un rattrapage à
  tort. Aucune liste ne peut garantir une couverture exhaustive.

**Patronyme seul : ce qui est couvert (P2-14).** Mesure sur les corpus
synthétiques de `bench/` (400 documents, graines 42 et 7) :

- *Après une mention complète du même document* : 100 % détecté (inchangé).
- *Dans un document ultérieur d'un dossier* : **2 à 6 % avant, 100 % après**.
  Les patronymes établis par une mention certaine (civilité ou titre, ou couple
  prénom + nom dont un seul mot est un prénom connu) des documents précédents
  d'un `Dossier` amorcent la deuxième passe de `NameDetector`. Jamais de liste
  externe : seul ce que l'application a déjà fait établir par le dossier. Sans
  `Dossier`, rien ne change. Des détecteurs fournis par l'appelant ne sont pas
  modifiés.
- *En première mention, sans ancrage* : **non couvert** (2 à 5 %, et seulement
  des patronymes qui sont aussi des prénoms du gazetteer). La seule règle sans
  liste ni NER testée, « tout mot capitalisé hors début de phrase est un nom »,
  touche 76 à 78 % des documents du témoin flou (budget : 1 %) : impossible
  sans NER ni liste.
- *Coût du rattrapage par le dossier* : un mot courant égal au patronyme établi
  est masqué (« Petit déjeuner » avec un patient nommé Petit : 100 % des 265 et 266
  documents de leurre des deux graines, par construction). Sur les corpus de
  dossiers dont toutes les personnes sont annotées, aucune détection hors
  annotation, avant comme après (0 sur environ 480 à 620 détections par corpus). La
  fréquence réelle de ce cas n'est pas mesurée.
- Le jeton d'un patronyme seul d'un autre document est séparé en N1 (nouvelle
  mention partielle) et fusionné en N2 (voir § 5.3).

## 6. Hors périmètre v0

- Généralisation appliquée au texte envoyé (le rapport de risque de
  `Ecluse.redact(riskReference: …)` existe depuis P2-04, voir § 7 ; la
  réécriture du texte est irréversible et reste à la charge de l'appelant).
- Dictée vocale.
- Branchement du journal d'audit (`ecluse_audit`) dans les applications.
- Le mode par défaut est automatique et invisible ; l'aperçu avec validation
  manuelle avant envoi est une option de confort, pas une garantie de
  contrôle a priori sur chaque détection.
- Aperçu avec validation (`Apercu`, P2-18) : composant de bibliothèque, sans
  interface ni test avec des utilisateurs. **Refuser une détection envoie la
  valeur en clair au tiers** : c'est un acte de l'utilisateur, pas une
  protection d'Écluse. Les refus ne sont pas journalisés. Un secret ne peut ni
  être refusé ni ajouté à la main ; refuser une entité à validation
  structurelle exige une option explicite. La proposition est liée au texte
  analysé et au dossier qui l'a produite : si le dossier a masqué un autre
  document entre l'aperçu et l'application, elle est refusée comme périmée
  (P2-19). Le rapport de risque est calculé à
  l'application, sur le texte réellement masqué.

Voir `ROADMAP.md` pour le calendrier de ces briques.

## 7. Estimation de ré-identification (`ecluse_reid`, `ecluse_reference`)

Bibliothèque, **utilisée par `Ecluse.redact` seulement si l'appelant fournit
`riskReference`** (rapport seul, désactivé par défaut) : elle estime la
taille F de la classe d'équivalence d'une combinaison de quasi-identifiants
(profession de santé, lieu, âge) et suggère une généralisation. Ce n'est
pas une garantie d'anonymat. Limites connues :

- **Rappel limité, sans NER.** Les quasi-identifiants ne sont repérés que par
  des règles (13 spécialités et 4 professions par mot-clé, communes par nom
  capitalisé, âge en chiffres). « Aucun quasi-identifiant détecté » n'est pas
  un risque faible. Le rapport porte sur le **texte masqué** : un lieu déjà
  masqué par un autre détecteur n'y est pas évalué.
- **Plusieurs personnes dans un document.** Le dépôt ne sait pas attribuer un
  quasi-identifiant à une personne : plusieurs QI du même type donnent « non
  évaluable » ; des QI de types différents (un lieu d'une personne, un âge
  d'une autre) s'évaluent ensemble, ce qui peut surestimer ou sous-estimer F.
- **Statut changé par le masquage.** Sur les corpus synthétiques de QI, le
  rapport sur le texte masqué diffère de l'évaluation du texte d'origine pour
  0 à 36 documents sur 400 selon le corpus et la graine (0 sur le témoin ;
  mesure de la PR P2-04).

- **Hypothèse d'indépendance lieu × âge** (population du lieu × part d'âge) ;
  pas de facteur sexe.
- **Cas profession** : F est l'effectif du département (borne haute, plafonnée
  à la population du lieu) ; l'âge fourni est ignoré. Le palier
  « professionnel de santé » ne somme que les médecins et quatre professions
  (pharmacien, chirurgien-dentiste, sage-femme, pédicure-podologue) :
  infirmiers, kinésithérapeutes et autres sont absents.
- **Lieux** : les niveaux région et grande zone ne sont pas calculables ;
  Paris, Lyon, Marseille (agrégés) et Mayotte n'ont pas de population
  complète dans les données, leur département est **refusé** (`ArgumentError` de
  `estimate` ; le rapport de `Ecluse.redact` le restitue en « non évaluable »).
  Les arrondissements ne sont pas modélisés.
- **Communes homonymes** (« Saint-Denis », ~3 700 communes concernées) :
  `extractLieu` retient la **plus petite** commune de ce nom (cas le plus
  prudent : F le plus bas, donc le risque le plus élevé) et
  `extractQisDetailed` / `extractLieuAmbigu` signalent l'ambiguïté. Un mot
  capitalisé qui coïncide avec un nom de commune ambigu (« La Chapelle »)
  produit désormais un QI de lieu prudent, parfois à tort.
- **Âges** : la pyramide couvre 0 à 104 ans ; une tranche de 10 ans qui
  chevauche 65 ans passe directement au retrait.
- **Données embarquées** : millésimes mélangés (populations communales
  2023→2026, pyramide 2026 France entière) ; provenance et licence documentées
  dans `DATA_SOURCES.md` et `NOTICE`. Les données restent sous la Licence Ouverte
  v2.0 de leurs producteurs (non relicenciées sous Apache 2.0) ; la redistribution
  d'extraits transformés a été décidée par le mainteneur le 25 octobre 2026, sans
  avis juridique extérieur. La date de téléchargement d'origine des assets n'a pas
  été enregistrée.

## 8. Journal d'audit (`ecluse_audit` v0)

Le paquet fabrique et vérifie des entrées chaînées par SHA-256 ; il **n'écrit
nulle part** (l'application fournit un `AuditSink`). Une entrée contient :
version de schéma, numéro d'ordre, horodatage UTC **à la minute**, version du
moteur et détecteurs actifs, opération, comptes par type d'entité, code de
motif d'un refus, hash précédent, hash. Elle ne contient **jamais** le
texte, une valeur détectée, un jeton, une position ou une longueur, une
empreinte du texte, l'identité de l'utilisateur ni un nom de fichier.

Ce que la vérification **détecte** : modification d'une entrée,
suppression ou insertion au milieu, réordonnancement. Ce qu'elle **ne
détecte pas** (un test l'affirme) :

- la **troncature en fin de journal** : la chaîne restante reste valide. Il
  faut ancrer régulièrement le dernier `hash` hors du journal ;
- la **réécriture complète** par qui contrôle tout le fichier et recalcule la
  chaîne : un hash chaîné n'est **pas une signature** (signature et ancrage
  externe sont hors v0) ;
- la **justesse de l'horloge** : l'horodatage vient de l'appareil. Ce n'est
  pas un horodatage qualifié (RFC 3161 / eIDAS).

`AuditExporter.agrege` (P2-15) produit un agrégat de ce journal pour alimenter un
registre ou une analyse d'impact : matière première factuelle, comptes de faible
effectif remplacés par « moins de 5 » (seuil provisoire), mentions d'honnêteté
dans la sortie ; **ce n'est ni un registre ni une attestation de conformité**.

Le journal prouve la cohérence interne de la chaîne, pas la vérité des
événements. Les comptes révèlent la nature d'un document (deux NIR et un IBAN
évoquent un dossier de paie) et un horodatage rapproché des journaux d'une
application peut relier une entrée à une personne : **l'affirmation « ce
journal n'est pas une donnée personnelle » n'est pas validée** (avis d'un DPO
attendu ; ceci n'est pas un avis juridique). Le README parle d'un journal
« signé » : ce n'est pas le cas en v0.

---

**Écluse réduit le risque, il ne l'annule pas.**
