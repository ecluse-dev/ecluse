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
2. **Non détectés** : le BIC, les clés d'API et autres secrets, les IBAN
   non français, les identifiants ADELI (un ADELI à clé valide est masqué
   mais **sous l'étiquette FINESS** ; à clé invalide il n'est pas détecté),
   les lieux isolés sans structure d'adresse (« reçu à Nantes »).
3. **Fichiers** : `.txt`, `.md`, `.docx` et `.odt`. Le PDF, les images, les
   scans et le manuscrit sont **refusés explicitement** — jamais lus à
   moitié. Les en-têtes, pieds de page, notes et commentaires de
   `.docx`/`.odt` ne sont pas lus (avertissement `ignored_parts`).
4. **Sur-masquage possible** : en cas de doute, Écluse masque. Un mot
   capitalisé adjacent à un prénom connu, ou un SIREN pris pour un FINESS,
   peuvent être masqués à tort. C'est un choix, pas un défaut. À l'inverse,
   le titre professionnel (Dr, Pr, Me) est masqué avec le nom ; la civilité
   de genre (Monsieur, Mme) reste en clair, donc le genre reste visible.
5. **Une seule entorse à la fidélité** : quand une même personne est nommée
   de deux façons, la re-mention est harmonisée sur la forme la plus
   complète à la restauration. Aucun caractère n'est perdu.
6. **Hors périmètre v0** : dictée vocale, journal d'audit chaîné (voir
   `ROADMAP.md`). L'estimation de ré-identification et la généralisation
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
- **Secrets** (clés d'API, jetons, clés privées, chaînes de connexion) : non
  détectés. Spécifié (`agent/specs/P1-07-secrets.md`), pas implémenté.
- **ADELI.** Pas de détecteur dédié (spécifié, non implémenté). Sur le
  corpus étendu du benchmark (`bench/README.md`), un ADELI à clé Luhn valide
  est masqué par `FinessDetector` — donc étiqueté « FINESS » — et un ADELI à
  clé invalide, même précédé du mot « ADELI », **n'est pas détecté**.
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

## 4. Fichiers pris en charge (`ecluse_ingest`)

Seuls `.txt`, `.md`, `.docx` et `.odt` sont ingérés en v1.

**Le PDF est refusé explicitement, systématiquement** — y compris un PDF
avec une couche de texte lisible : ce n'est pas encore implémenté, et un
fichier refusé vaut mieux qu'un fichier mal lu.

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
identique à l'original. Choix assumé : cohérence d'identité pour le LLM >
fidélité mot-à-mot d'une re-mention.

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

## 6. Hors périmètre v0

- Branchement de l'estimation de ré-identification et de la généralisation
  dans `Ecluse.redact` (la bibliothèque `ecluse_reid` existe, voir § 7).
- Dictée vocale.
- Journal d'audit chaîné et horodaté.
- Le mode par défaut est automatique et invisible ; l'aperçu avec validation
  manuelle avant envoi est une option de confort, pas une garantie de
  contrôle a priori sur chaque détection.

Voir `ROADMAP.md` pour le calendrier de ces briques.

## 7. Estimation de ré-identification (`ecluse_reid`, `ecluse_reference`)

Bibliothèque seule, **non utilisée** par `Ecluse.redact` : elle estime la
taille F de la classe d'équivalence d'une combinaison de quasi-identifiants
(profession de santé, lieu, âge) et suggère une généralisation. Ce n'est
pas une garantie d'anonymat. Limites connues :

- **Hypothèse d'indépendance lieu × âge** (population du lieu × part d'âge) ;
  pas de facteur sexe.
- **Cas profession** : F est l'effectif du département (borne haute, plafonnée
  à la population du lieu) ; l'âge fourni est ignoré. Le palier
  « professionnel de santé » ne somme que les médecins et quatre professions
  (pharmacien, chirurgien-dentiste, sage-femme, pédicure-podologue) :
  infirmiers, kinésithérapeutes et autres sont absents.
- **Lieux** : les niveaux région et grande zone ne sont pas calculables ;
  Paris, Lyon, Marseille (agrégés) et Mayotte n'ont pas de population
  complète dans les données, leur département est **refusé** (`ArgumentError`).
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
  2023→2026, pyramide 2026 France entière) ; **provenance et licence des jeux
  de données non déclarées dans le dépôt** — à documenter avant toute
  diffusion.

---

**Écluse réduit le risque, il ne l'annule pas.**
