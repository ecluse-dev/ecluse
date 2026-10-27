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
2. **Non détectés** : le BIC, les IBAN non français, les secrets sans préfixe
   reconnaissable (mots de passe humains, voir § 2), les identifiants ADELI
   **sans le mot « ADELI » accolé** (à clé valide ils sont masqués mais sous
   l'étiquette FINESS ; à clé invalide ou corses, ils ne sont pas détectés),
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
**Coupure de ligne** : un identifiant (NIR, IBAN, téléphone, date de naissance numérique) coupé par
un saut de ligne **entre deux groupes de chiffres** est détecté (P2-38) ; une coupure ailleurs (au milieu
d'un groupe, après une lettre) ne l'est pas.

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
  identifiant coupé par une fin de ligne entre deux groupes de chiffres est
  détecté depuis P2-38 ; une césure au milieu d'un groupe, ou une coupure
  après une lettre, peut encore échapper à la détection.
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

### Intégrité des archives `.docx` et `.odt` (P2-27)

Un `.docx` ou `.odt` dont le contenu ne correspond plus à la somme de contrôle
(CRC-32) de l'archive est **refusé** (« archive corrompue »). Avant P2-27,
`package:archive` 4.x ne vérifiait pas ce CRC (son option `verify` est sans
effet dans la version utilisée) : sur 4 000 `.docx` synthétiques abîmés au hasard
(graine 42 : octets modifiés, tronqués, supprimés ou insérés), 81 étaient lus avec
un texte **altéré** (« JulienGVasseur ») et 34 avec un texte vide, tous comme des
succès. Après : 0 texte altéré, 0 texte vide, 0 exception ; 3 654 refus, 346
fichiers lus à l'identique (octets sans effet sur le contenu). Un fichier fabriqué
avec un CRC volontairement faux pour un contenu modifié passe, bien sûr : le CRC
détecte l'accident, pas l'adversaire. Les PDF (lecteur maison) ne sont pas concernés
par cette vérification.

### PDF abîmés : pages perdues (P2-28)

Sur 1 500 copies de `bench/pdf/texte_multipage.pdf` abîmées au hasard (graine 42,
script jetable), 63 étaient lues comme des succès **sans une page** et sans
avertissement (exemple : la page 3, celle du RPPS et de l'IBAN, disparaissait de
l'arbre des pages). La page perdue n'est pas envoyée au tiers (seul le texte extrait
est masqué puis envoyé), mais l'utilisateur croit avoir traité tout le document.
Depuis P2-28, un PDF qui contient plus d'objets `/Type /Page` en clair que de pages
atteignables est refusé (motif `malforme`). Après : 6 cas restants sur 1 500 (-90 %),
1 080 refus au lieu de 1 020, 0 exception, et les 40 PDF intacts du jeu de bench sont
toujours acceptés ou refusés comme avant. **Limites** : (1) les objets de page rangés
dans un flux compressé ne sont pas comptés (l'écart ne joue que dans un sens) ; (2) un
PDF mis à jour par ajout peut contenir d'anciennes versions d'une page et être refusé à
tort : refus explicite, à mesurer sur de vrais fichiers ; (3) un octet modifié dans le
texte d'une page, sans effet sur la structure, n'est pas détecté (un PDF n'a pas de
somme de contrôle) : 82 sur 1 500 copies sont lues avec un texte différent.

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

Sondage de robustesse (26 octobre 2026, graine 42, script jetable) : 3 000 textes
synthétiques assemblés au hasard à partir de civilités, noms, téléphones, courriels,
adresses, dates, NIR, IBAN, émojis (dont séquences ZWJ et drapeaux), lettres
mathématiques, accents composés, espaces insécables et de largeur nulle, retours à
la ligne et crochets. Sur 2 544 entités détectées : 0 exception, 0 chevauchement,
0 désordre, 0 valeur différente du texte à l'offset indiqué, 0 coupure d'une paire de
substituts UTF-16. 7 textes se restaurent de façon non identique : ce sont les cas
d'harmonisation des re-mentions (§ 5.3) sur des enchaînements absurdes (« Dr Dr »).
Un sondage aléatoire n'est pas une preuve ; il n'a pas cherché les mises en forme
propres aux vrais documents (§ 5.2).

**Caractères invisibles et séparateurs typographiques dans un identifiant (P2-29).**
Un copier-coller depuis le web ou un PDF glisse souvent un espace sans chasse (U+200B),
un trait d'union conditionnel (U+00AD) ou un lien de mots (U+2060) dans un numéro ; un
traitement de texte remplace parfois le trait d'union par un tiret demi-cadratin ou
insécable. Avant P2-29, un NIR, un IBAN ou un téléphone ainsi écrit n'était **pas
détecté** (donc non masqué) : sur 11 séparateurs et 3 types (33 cas), 22 étaient
détectés en entier (tous les cas U+200B, U+2011 et U+2013 manquaient, ainsi que
l'espace fine U+2009 et la tabulation pour le téléphone). Les détecteurs tournent
désormais sur une vue du texte : espaces Unicode ramenés à l'espace, tirets
typographiques à `-` (même longueur), caractères invisibles retirés ; les positions et
la valeur sont ramenées au texte d'origine, qui n'est jamais réécrit. Après : 32 cas sur
33 (reste : tabulation dans un téléphone) ; 47 sur 48 avec cinq séparateurs de plus
(U+200C, U+2060, U+FEFF, U+00AD, U+2212). Sorties inchangées, octet pour octet, sur les
corpus du banc (dossiers et flou), qui ne contiennent aucun de ces caractères. Limite :
un séparateur absent de ces listes, ou un caractère invisible *dans* un mot (nom,
adresse) qui le coupe pour les détecteurs de noms, n'est pas couvert.

Formes d'autres systèmes d'écriture (P2-30) : sur 17 variantes sondées après P2-29 (courriel,
date, noms, téléphone), 4 restaient non détectées : chiffres et lettres pleine chasse
(« ０１ ９９ … »), arobase pleine chasse, barre de fraction dans une date. La vue des
détecteurs ramène aussi les formes pleine chasse (U+FF01 à U+FF5E), les chiffres arabes
orientaux et les barres de fraction et de division à leur équivalent ASCII (une unité pour
une unité : positions et valeur d'origine inchangées). Après : les 4 variantes sont
détectées, ainsi que 2 de plus (NIR et IBAN pleine chasse, téléphone en chiffres arabes
orientaux) ; banc inchangé octet pour octet. Non couverts : les autres jeux de chiffres
(devanagari, etc.), les homoglyphes de lettres (cyrillique, grec) dans un identifiant
alphanumérique comme l'IBAN, et la normalisation NFKC complète (les ligatures changent la
longueur).

**Accents décomposés (NFD) (P2-32).** Un nom dont les accents sont écrits en lettre de base
plus diacritique combinant (« E » + U+0301 pour « É », forme courante des noms de fichiers
macOS et de certains copier-coller de PDF) était coupé au premier diacritique : « Élodie
Lefèvre » devenait `Mme [NOM_1]́lodie Lefèvre`, le reste du nom **restait en clair**. Sur les
397 documents accentués du corpus dossiers (réaliste, graine 42) convertis en NFD par un
script jetable, 371 donnaient autant de jetons qu'en forme composée ; après P2-32 : 397 sur
397. Les diacritiques combinants (U+0300 à U+036F, U+1DC0 à U+1DFF, U+20D0 à U+20FF,
U+FE20 à U+FE2F) sont retirés de la vue des détecteurs et rattachés à leur lettre quand une
entité est ramenée au texte d'origine.

**Lettres hors du jeu français usuel dans un nom (P2-33).** La majuscule initiale d'un mot de
nom ne couvrait que A-Z et quelques lettres françaises : un nom commençant par Á, Ó, Ñ, Œ,
Ł, Ş, Ž… ou contenant des lettres vietnamiennes n'était masqué qu'en partie (« François Œil »
donnait `[NOM_1] Œil`). Sur 20 formes de noms sondées, 15 étaient détectées en entier ;
après P2-33, 11 noms de test sur 11 (espagnols, portugais, polonais, tchèque, turc,
vietnamien, scandinave) sont masqués en entier avec une restauration identique, sans mot
capitalisé isolé pris pour un nom (« Œuvre », « Ångström » seuls). Les prédictions du banc
(dossiers, flou, patronymes y compris les leurres de faux positifs) sont inchangées octet pour
octet : les corpus ne contiennent pas ces lettres. Reste non détecté : un nom écrit sans
majuscule. La détection de noms reste une heuristique sans liste exhaustive (§ 1) ; aucune
mesure de faux positifs n'a été faite sur de vrais textes espagnols, polonais ou vietnamiens.

**Dates de naissance aux séparateurs espacés (P2-34).** Sonde de 23 formulations d'une date
de naissance : 16 détectées. Parmi les 7 manquées, deux sont des formes numériques courantes :
des blancs autour des séparateurs (« né le 12 / 03 / 1950 ») et des blancs pour tout
séparateur (« née le 12 03 1950 »). Elles sont désormais détectées (11 tests, contexte « né
le », « DDN »… toujours obligatoire ; les négatifs restent non détectés : année sur 5 chiffres,
jour sur 3 chiffres, date sans contexte) ; banc inchangé octet pour octet. **Restent non
détectées, par choix de périmètre** (le détecteur exige un contexte de naissance et une date
complète) : une année ou un mois et une année seuls (« née en 1950 », « né en mars 1950 »), une
date suivie d'un âge sans mot de naissance (« 12/03/1950 (73 ans) »), un âge seul (« âgé de
73 ans »). Ce sont des quasi-identifiants que le masquage ne retire pas ; le rapport de risque
(`Ecluse.redact(riskReference: …)`) repère l'âge en chiffres, mais pas une année de naissance
seule (rappel limité, § 7).

**Civilités abrégées avec point (P2-35).** « Mme. » et « Mlle. » (avec point) ne déclenchaient
pas la règle de civilité, seules les formes sans point étaient reconnues : un prénom inconnu ou
un patronyme de deux mots restait en clair (« Mme. Sophie Mac Donald » laissait « Donald »).
Tests d'abord (3 rouges), puis correction d'une expression régulière ; banc inchangé octet pour
octet. Le patronyme seul dans un champ étiqueté, relevé par la même sonde, est traité en P2-36.

**Patronyme derrière une étiquette de champ (P2-36).** « Nom : Dupont ; Prénom : Jean » masquait
« Jean » (gazetteer) mais laissait « Dupont » : un patronyme n'a pas d'autre indice que
l'étiquette. Sont maintenant masqués le ou les deux mots capitalisés qui suivent « Nom de
naissance », « Nom d'usage », « Nom de famille », « Nom patronymique », « Nom marital » (toujours),
et « Nom » seul **à condition que « Prénom » apparaisse dans les 300 caractères suivants, sur la
même ligne ou la suivante** (« Nom : Aspirine » reste intact : l'étiquette seule est ambiguë).
Tests d'abord (6 rouges) ; banc inchangé (aucun corpus ne contient cette étiquette : la mesure
ne couvre donc pas cette règle, elle repose sur les tests). **Limites** : « NOM DE NAISSANCE »
tout en majuscules, « Nom et prénom : Jean Dupont » (ordre mixte, déjà couvert par le prénom),
un patronyme en minuscules (« Nom : dupont ») et une fiche où « Prénom » est plus loin ne sont pas
reconnus ; un médicament ou un produit nommé dans une fiche qui contient aussi « Prénom » dans la
fenêtre serait masqué à tort (sur-masquage, jamais de fuite). Un premier essai avec une
anticipation d'expression régulière était **cubique** (1000 « Nom » répétés : 40 s ; 2000 :
126 s) : remplacé par un contrôle en code sur une fenêtre bornée, avec un test de non-régression.

**Numéro de voie suivi d'une lettre (P2-37).** « 12 B rue des Lilas » laissait « 12 B » en clair
devant l'adresse masquée : seuls « bis », « ter »… étaient admis après le numéro. Une lettre
majuscule A à F isolée est maintenant acceptée (« 12 B rue », « 12B rue », « 3 A avenue »). Le type
de voie reste obligatoire, donc « Annexe 12 B : voir page 3 » n'est pas une adresse (3 tests de
non-détection). Tests d'abord (4 rouges) ; banc inchangé octet pour octet ; coût linéaire
(« 1 B rue » × 4000 : ~0,2 s). **Restent non traités** : lettre minuscule (« 12 b rue »), lettres
au-delà de F, « Lieu-dit », boîte postale, adresse sans code postal.

**Identifiant coupé par une fin de ligne (P2-38).** Sonde de 14 formes : un téléphone, un NIR, un
IBAN ou une date coupés entre deux groupes (« 01 99 00⏎12 34 », « FR76 3000 6000⏎0112 … ») n'étaient
pas détectés, alors que l'extraction d'un PDF ou le retour automatique d'un traitement de texte les
produisent souvent. La coupure est neutralisée **dans la vue de détection seulement** (le texte n'est
jamais réécrit) : entre deux chiffres elle devient une espace, après `/ . -` elle disparaît ; les
blancs et un `\r` autour sont absorbés. Tests d'abord (11 rouges) ; banc inchangé octet pour octet ;
coût linéaire (40 000 fins de ligne : < 1 s). Garde-fous testés : « Total : 150⏎Page 12 », « Chambre
12⏎Lit 3 » et « Tableau⏎12⏎34⏎56 » restent intacts, deux numéros sur deux lignes restent deux
numéros. La règle générale du § 5.2 (« un span ne traverse jamais un saut de ligne ») demeure pour les
noms, adresses et établissements ; **seuls les identifiants à chiffres sont concernés**, car leur
validation (clé NIR, clé IBAN) ou leur forme étroite limite le risque de fusionner deux lignes sans
rapport. **Restent non détectés** : l'adresse e-mail coupée après le `@`, une date écrite avec le
mois en lettres sur deux lignes (« 12 mars⏎1950 »), un identifiant coupé au milieu d'un groupe.

**Date de naissance séparée de son étiquette (P2-39).** Sonde de formats de formulaire : « Date de
naissance :⏎12/03/1950 » (étiquette sur sa ligne, valeur sur la suivante), « Date de naissance |
12/03/1950 » (tableau) et « Date de naissance;12/03/1950 » (CSV) n'étaient pas détectées : seules des
espaces étaient admises entre l'étiquette et la date. Sont maintenant admis des blancs, un `|` ou un
`;`, ou **un seul** saut de ligne. Tests d'abord (10 rouges) ; banc inchangé octet pour octet ; coût
linéaire (16 000 répétitions < 1 s). Restent intacts, testés : une ligne vide entre les deux, une ligne
étrangère entre les deux, une virgule, « La naissance du projet⏎12/03/1950 », une date sans étiquette.
**Non couverts** : la date d'une colonne dont l'en-tête est sur une autre ligne (CSV à en-tête :
« Date de naissance;Tél⏎Quenelle;Zorglub;12/03/1950 »), et une étiquette nue sans « : » ni « date de »
(« Naissance⏎12/03/1950 »). La sonde a aussi confirmé qu'un nom **absent du gazetteer**, sans civilité,
dans un tableau, un CSV ou un JSON (« Quenelle ; Zorglub ») n'est pas détecté : limite connue des
noms (§ 5.4), pas traitée ici.

**Prénom derrière une étiquette de champ, fiche « Prénom » avant « Nom » (P2-40).** Contrôle de P2-36 :
dans « Nom : Quenelle⏎Prénom : Zorglub », le patronyme était masqué mais un prénom **hors gazetteer**
(« Zorglub ») restait en clair, et « Prénom : Zorglub⏎Nom : Quenelle » (prénom avant nom) laissait le
patronyme, la fiche n'étant cherchée que *après* « Nom ». Sont maintenant masqués les un à trois mots
capitalisés derrière « Prénom », « Prénoms », « Prénom usuel », « Prénom de naissance », « Prénom
d'usage », « Prénom à l'état civil » (jamais l'étiquette suivante : « Prénom : Zorglub Nom : Quenelle »
sur une ligne donne deux noms distincts), et « Nom : » seul est retenu si « Prénom » figure **avant** (ligne
courante ou précédente) comme après (ligne courante ou suivante), dans une fenêtre de 300 caractères.
Tests d'abord (8 rouges) ; banc inchangé octet pour octet (aucun corpus ne contient ces étiquettes :
règle couverte par les tests seulement) ; 563 tests. Intacts, testés : « Prénom du chat : Zorglub »,
« Prénom : inconnu » (minuscules), « Prénom : » vide, « Nom : Aspirine » sans « Prénom » proche.
**Coût** : la recherche de la fenêtre est bornée (un premier calcul remontait toute la ligne, quadratique
sur une longue ligne de « Nom » répétés). Les 32 000 mentions successives d'un même type (« Mme Anne
Quenelle », « Prénom : Zorglub ») coûtent plusieurs secondes, croissance **déjà présente** pour les
règles de civilité existantes et non propre à cette règle.

**Étiquettes « Nom du patient », « Nom de l'assuré »… (P2-41).** Sonde d'étiquettes courantes
(26 octobre 2026) : « Nom du patient : Quenelle » restait en clair. Comme « Nom de naissance » (P2-36),
ces étiquettes désignent sans ambiguïté une personne : sont ajoutées « Nom du patient / bénéficiaire /
demandeur / salarié / résident », « Nom de la patiente », « Nom de l'assuré(e) / de l'employé(e) »
(minuscules ou tout en majuscules), sans exiger « Prénom » à proximité. Tests d'abord (10 rouges) ;
banc inchangé octet pour octet (aucun corpus ne contient ces étiquettes) ; intacts, testés : « Nom du
médicament / du fichier / du projet », valeur en minuscules, valeur vide. **Non traité, par choix** :
les étiquettes génériques (« Contact : », « Destinataire : », « Personne à prévenir : », « Représentant
légal : », « Patient : ») suivies d'un nom **hors gazetteer sans civilité** (« Hector Quenelle ») ne sont
pas détectées. C'est la limite connue des noms (§ 5.4) ; l'étendre à ces étiquettes est une décision de
périmètre (ces mots précèdent aussi des noms de service ou d'organisme) laissée au mainteneur.

**Clé du NIR nommée à part (P2-42).** Sonde de variantes de NIR (métropole, Corse 2A/2B, DOM, naissance
à l'étranger) : toutes les écritures à clé collée ou séparée par une espace étaient détectées, mais
« 2550814168025 clé 38 » (le mot « clé » entre le numéro et sa clé) ne l'était pas et laissait les 13
chiffres en clair dans les quatre familles. Le mot (« clé », « cle », « clef », avec `(` et `:`
facultatifs) est neutralisé **dans la vue de détection seulement** quand il suit un chiffre et précède
deux chiffres : le détecteur de NIR de `ecluse_core` reste inchangé et valide toujours la clé, donc
une clé fausse (« clé 39 ») ou un nombre quelconque suivi de « clé 99 » n'est pas masqué (4
contre-exemples testés). Tests d'abord (10 rouges) ; banc inchangé octet pour octet ; coût linéaire
(32 000 occurrences : < 1 s). Effet de bord assumé : « 01 99 00 12 clé 34 » peut être lu comme un
téléphone (sur-masquage possible, jamais de fuite). **Non couvert** : la clé sur une autre ligne ou dans
une autre colonne que le numéro.

**Variantes du contexte et de la date de naissance (P2-43).** Sonde de 23 écritures : 12 manquées.
Sont maintenant détectées : le département entre parenthèses après le lieu (« né(e) à Lyon (69) le … »),
les abréviations « Date de naiss. », « Date naiss. » et « D.D.N. », un jour de semaine devant la date
(« né le mardi 12 mars 1950 »), l'année à deux chiffres avec le mois en lettres (« née le 12 mars 50 »),
et, derrière un contexte anglais (« DOB », « Date of birth », « Birth date », « born on »), les mois
anglais. Tests d'abord (18 rouges) ; banc inchangé octet pour octet ; 617 tests ; coût linéaire.
Le contexte de naissance reste obligatoire : « Rendez-vous le mardi 12 mars 1950 », « le 12 mars 50 » et
« on 12 March 1950 the board met » ne sont pas des dates de naissance (7 contre-exemples testés).
**Restent non détectées** : « 12-mars-1950 », les mois en chiffres romains (« 12.III.1950 »), une date
écrite en toutes lettres (« douze mars mille neuf cent cinquante »), et une année seule.

**Téléphone : préfixe entre parenthèses, outre-mer, numéros étrangers (P2-44).** Sonde de 22 numéros :
« (+33) 6 12 34 56 78 » laissait « (+33) » et classait le reste en FINESS (masqué, mais sous un mauvais
type), et les numéros d'outre-mer écrits avec leur indicatif (« +262 692 12 34 56 » à La Réunion et à
Mayotte, « +590 » Guadeloupe, « +594 » Guyane, « +596 » Martinique) n'étaient pas détectés alors que leur
forme nationale (« 0692 12 34 56 ») l'est. Sont maintenant détectés « (+33) » (avec ou sans « (0) ») et ces
quatre indicatifs (10 tests, 4 contre-exemples intacts : trop peu de chiffres ou un chiffre de trop) ;
banc inchangé octet pour octet ; 631 tests ; coût linéaire (32 000 répétitions : 1,3 s au plus).
**Limite jusqu'ici non écrite, désormais documentée : les numéros étrangers ne sont pas détectés**
(« +32 2 123 45 67 », « +41 21 123 45 67 », « +44 20 7946 0958 », « +1 (555) 123-4567 », « +352 621 123 456 »),
le détecteur étant celui des numéros français. Autres collectivités d'outre-mer (« +687 », « +689 »,
numéros à 6 chiffres) et numéros courts (« 3949 », « 15 ») non détectés non plus.

**Nom de naissance ou d'épouse (P2-45).** Sonde de 24 civilités et titres : « Mme Quenelle née Dupont »
masquait le nom d'usage mais laissait le **nom de naissance** en clair ; « épouse Dupont », « ép. »,
« veuve », « divorcée » et « nom de jeune fille » de même. Seul un nom figurant aussi au gazetteer des
prénoms (« épouse Martin ») était masqué, par hasard. Sont maintenant masqués les un ou deux mots à
majuscule initiale qui suivent « née », « épouse », « ép. », « veuve », « divorcée » ou « nom de jeune fille
(:) » (le marqueur peut ouvrir une phrase). Tests d'abord (17 rouges) ; banc inchangé octet pour octet
(aucun corpus ne contient ces marqueurs) ; 657 tests. Intacts, testés : « née le 12/03/1950 », « née à Lyon »,
« née en France », « Elle est née Lundi / Janvier » (mois et jours exclus), « épouse de l'intéressé », « sa
veuve est présente ». **Sur-masquage assumé** : « La veuve Clicquot est une marque » masque « Clicquot ».
**Coût** : 32 000 « née Dupont » successifs : ~5 s, même ordre de grandeur que les civilités existantes.
**Titres et fonctions encore non reconnus** (relevés par la même sonde) : « Père », les grades
(« Capitaine »), et les fonctions suivies d'un nom (« Infirmière Zorglub Quenelle », « IDE », « Pharmacien »)
sans civilité ni prénom connu : même limite que § 5.4. Les titres « Professeure », « Docteure », « Dre »,
« Ms », « Mgr » et « Abbé » sont traités en P2-46.

**Titres supplémentaires (P2-46).** « Professeure », « Docteure », « Dre » (avec ou sans point), « Ms »,
« Mgr » et « Abbé » / « abbé » déclenchent maintenant la règle de civilité : le nom qui suit est masqué
même sans prénom connu. Les titres professionnels (Professeure, Docteure, Dre) sont masqués avec le nom,
comme « Dr » et « Professeur » ; « Ms », « Mgr » et « Abbé » restent visibles comme « M. » ou « Mme ». Tests
d'abord (10 rouges) ; banc inchangé octet pour octet ; 672 tests ; coût du même ordre que les civilités
existantes. Intacts, testés : « Les msg arrivent », « Un abbé est venu », « Le mgr de la boîte », « La
professeure est venue » (le titre est suivi d'un mot en minuscule : aucun nom). **Sur-masquage possible** :
un mot capitalisé après « Ms » ou « Abbé » qui n'est pas un nom (« Abbé Pierre » est bien une personne).

**Particules de noms d'origine étrangère (P2-47).** Sonde de 27 noms à particules : « M. Pedro dos Santos »,
« M. Luis da Silva », « M. Ahmed ben Ali » et « Mme Fatima bint Ali » étaient masqués à moitié
(« M. [NOM_1] dos Santos », « M. [NOM_1] ben [NOM_2] ») : la particule et le nom, ou le nom seul, restaient en
clair. Sont ajoutées aux particules reconnues : « da », « das », « do », « dos », « di », « del », « della » (portugais,
italien, espagnol), « ben », « bin », « bint », « ibn » (arabe), « ter », « ten » (néerlandais), « zu » (allemand) et
« af » (suédois), en minuscules ou capitalisées, devant un mot à majuscule initiale. Tests d'abord (15 rouges) ;
banc inchangé octet pour octet ; 691 tests. Intacts, testés : « Le dossier dos Santos est clos », « Une salade da
Vinci », « le ben oui du jour » (aucune civilité ni prénom connu). **Sur-masquage possible** : un mot courant
de la liste suivi d'un mot capitalisé après une civilité et un nom (« Mme Dupont do Something »). **Coût** : un
texte de 4 000 « Mme Dupont ben Ali ter ten » prend ~5 s ; le coût quadratique sur des mentions identiques est
**antérieur** à P2-47 (10,9 s sur la base avant la modification) et reste à traiter.

**Coût de la détection de noms sur un texte à milliers de mentions (P2-48).** Mesure : 4 000 mentions
(« Mme Dupont ben Ali ter ten » répétées) prenaient **11 s** et 32 000 plus de 100 s. Cause trouvée en
chronométrant les passes (le détecteur de noms seul : 6 s, les autres : moins de 20 ms) : à chaque prénom
candidat, le mot capitalisé qui le précède était cherché dans une **copie de tout le texte précédent**, donc
un coût proportionnel à la position. La recherche est bornée à une fenêtre de 400 caractères, et les plages
déjà réservées sont tenues dans un masque par caractère plutôt qu'une liste parcourue à chaque mot. Mesure
après : 4 000 mentions en 0,5 s (22 fois plus vite), 32 000 en 13 s. Un test de non-régression est ajouté.
Équivalence vérifiée : 1 500 textes aléatoires (graine 42) donnent exactement les mêmes sorties avant et
après, le banc est inchangé octet pour octet et tous les tests passent. **Limites** : un mot de plus de 400
caractères n'est plus reconnu en entier derrière un prénom ; un coût superlinéaire résiduel subsiste au-delà
de ~10 000 mentions identiques d'un même texte (hors du détecteur de noms : la résolution des jetons), à
traiter si un cas réel l'exige.

**Types de voie et abréviations (P2-49).** Sonde de 26 adresses : « 25 R. de la Paix, 75002 Paris »,
« 3 pl. de la Bastille, 75004 Paris » et « 14 sentier des Roses, 44000 Nantes » ne masquaient que « code postal
+ commune » et laissaient le **numéro et le nom de rue en clair** (les types « r », « pl », « sentier » n'étaient
pas reconnus). Sont ajoutés : « sentier », « ruelle », « traverse », « venelle », « parvis », « promenade »,
« montée », « clos » et les abréviations « r », « pl », « ch », « imp », « all », « sq », « crs » (point facultatif).
Tests d'abord (17 rouges) ; banc inchangé octet pour octet ; 715 tests ; coût linéaire. Le code postal + commune
reste obligatoire en fin de motif : « Le 25 R de la table », « Chapitre 3 pl. de la liste », « Il a fait 6 clos de la
saison », « Page 6 ch. 3 » restent intacts (5 contre-exemples testés). **Restent non couverts** : « Rond-point »,
« Cour », « Mail », « Domaine », « Résidence » (complément d'adresse), « Cedex 03 » (le suffixe reste en clair, sans
valeur identifiante), une adresse sans code postal (« 12 rue des Lilas »), « Paris 11e ». Les abréviations d'une
lettre (« R ») ne sont reconnues que suivies d'un nom puis d'un code postal et d'une commune.

**Recherche de la fiche « Prénom » bornée (P2-50).** Sonde de robustesse sur 16 textes pathologiques d'environ
1 Mo : un seul sortait nettement du lot, **« Nom : » répété 160 000 fois sans saut de ligne : 43,6 s**. Cause trouvée
en chronométrant le détecteur seul (0 entité détectée, coût quadratique) : le contrôle de P2-36 cherchait la fin de
ligne avec `indexOf('\n', …)` dans **tout le reste du texte** à chaque occurrence. La recherche se fait maintenant
dans une fenêtre de 300 caractères extraite d'abord. Mesure après : 1,8 s (24 fois plus vite). Équivalence vérifiée :
2 000 textes aléatoires (graine 99, étiquettes Nom/Prénom, sauts de ligne, ponctuation) donnent exactement les mêmes
sorties avant et après ; banc inchangé octet pour octet ; 718 tests. Tests de non-régression ajoutés (160 000 « Nom : »
et 64 000 « Nom : Aspirine », moins de 15 s : 43 s et plus avant la correction ; une première borne de 4 s,
posée sur 60 000 répétitions, était trop serrée pour l'exécuteur d'intégration continue — 4,09 s — et a été
remplacée). **Reste mesuré, non traité** : le coût superlinéaire de la résolution
des jetons au-delà de ~50 000 mentions de noms dans un même texte (« née Dupont » ×90 000 : 18 s pour 990 Ko ;
« Prénom : » ×110 000 : 9 s), hors de la détection ; irréaliste pour un document ordinaire, noté pour mémoire.

**Étiquettes décorées en Markdown ou en HTML (P2-51).** Sonde de 16 présentations : « **Date de naissance :**
12/03/1950 », « **Né le** 12/03/1950 », « **Nom :** Quenelle », « *Nom* : Quenelle », « `Nom` : … » et
« <b>Nom :</b> … » laissaient la date, le nom et le prénom **en clair**, les marques de gras, d'italique ou de
code séparant l'étiquette de sa valeur (les formats `.md` sont pris en charge à l'ingestion). Les marques sont
neutralisées **dans la vue de détection seulement** : le texte n'est jamais réécrit et le masquage laisse les
marques en place (« **Nom :** [NOM_1] »). Une suite de `*`, `_` ou `` ` `` d'ouverture n'est retirée que devant un
mot et hors d'un mot, une suite de fermeture que derrière un mot ou une ponctuation et hors d'un mot, de sorte que
`jean_dupont`, `[NOM_1]`, `3 * 4`, `__init__` et « une **phrase** en gras » restent intacts (5 contre-exemples
testés), ainsi que les balises `<b>`, `<i>`, `<u>`, `<em>`, `<strong>`. Tests d'abord (17 rouges) ; banc inchangé
octet pour octet ; 747 tests. **Incident de conception, corrigé avant fusion** : la première expression
utilisait des alternatives qui se recouvrent (`\*\*|\*` répétées) et avait un retour arrière exponentiel : 50 000
étoiles prenaient 51 s (0,1 s sans la règle). Une batterie de stress sur 10 textes d'1 Mo l'a révélé ; remplacée
par une classe de caractères (1 Mo d'étoiles : 1,6 s), avec 6 tests de non-régression. Contrôle d'intégrité : sur
3 000 textes aléatoires riches en marques, la restauration redonne exactement l'original dans tous les cas où
aucun nom n'est masqué, avant comme après la modification ; les écarts restants (141 sur la base, 159 avec la
règle) concernent exclusivement des textes contenant un nom, dont les mentions partielles sont restaurées sous
leur première écriture (fusion d'alias, voulue). **Non couvert** : un titre Markdown (« ## **Nom**… »), une
étiquette entre crochets ou en tableau HTML, un lien (« [Nom](url) »).

**Date de naissance derrière une clé de données (P2-52).** Sonde d'exports structurés : `{"date_naissance":
"12/03/1950"}`, `dateNaissance = …`, `<dateNaissance>…</dateNaissance>`, `birth_date`, `dob`, `ddn` laissaient la
date **en clair**, alors que `telephone`, `nir`, `iban` et `adresse` sont masqués par leur structure même.
Le contexte de naissance accepte maintenant les clés `date_naissance`, `date-naissance`, `dateNaissance`,
`date_de_naissance`, `birth_date`, `birthDate`, `date_of_birth`, `dob`, `ddn` et `naissance` (suivie de `:`, `=`
ou `>`), avec des guillemets, des `=`, des `:` ou des `>` entre la clé et la valeur (JSON, YAML, XML, paramètres
d'URL). Tests d'abord (18 rouges) ; banc inchangé octet pour octet ; 774 tests ; coût linéaire et identique à la
base (≈ 4 µs par caractère pour une suite de « date_ »). Le contexte reste obligatoire et testé : `date_creation`,
`date_naissance_projet`, `naissance_projet`, `dobby`, `update`, `date`, `ddns`, « la naissance du projet: … » et
`"date_naissance": "inconnue"` ne sont pas des dates de naissance (9 contre-exemples). **Non traité (nom et
prénom en clé de données)** : `{"nom": "Quenelle", "prenom": "Zorglub"}`, `nom: …`, `<nom>…</nom>`,
`nom=…&prenom=…` ne sont pas détectés — un nom n'a pas de structure vérifiable et la clé « nom » est ambiguë
(`"nom": "Aspirine"`) ; la règle P2-36 (« Nom : » + « Prénom » proche) ne couvre que la prose. Les en-têtes d'un
CSV (« Nom;Prénom;Date de naissance⏎Quenelle;Zorglub;12/03/1950 ») ne sont pas non plus associés à leurs colonnes.


**Nom d'un correspondant dans un en-tête de courriel (P2-53).** Sonde : « From: Zorglub Quenelle <z@exemple.fr> »,
« De : Quenelle, Zorglub <…> », « Le 12 mars, Zorglub Quenelle <…> a écrit : » ne masquaient que l'adresse quand
le prénom n'est pas au gazetteer (11 cas rouges). Deux structures sont maintenant reconnues : une étiquette
d'en-tête en début de ligne (`De`, `From`, `À`, `To`, `Cc`, `Cci`, `Bcc`, `Expéditeur`, `Destinataire`, `Reply-To`,
citée ou non par `>`) suivie d'un nom de 1 à 3 mots puis de `<` (« Nom, Prénom » et guillemets tolérés) ; ou un nom
devant `<adresse>` suivi de « a écrit », « wrote », « ha scritto » ou « schrieb ». Banc inchangé octet pour octet ;
coût identique à la base sur 7 entrées pathologiques de 0,5 à 1 Mo. Contre-exemples intacts (5) : « Service
Qualité <…> » (mot-clé d'établissement), « De : <…> », « Voir la note <…> » (pas d'étiquette), minuscules.
**Non traité** : nom seul sur une ligne de signature (« Cordialement,⏎Zorglub Quenelle »), second destinataire d'une
liste (« À : A <a@…>, B <b@…> » : seul le premier est reconnu), nom d'affichage sans chevrons (« De : Zorglub
Quenelle ») ; un nom de service hors liste des mots-clés devant `<…>` après « De : » est masqué à tort.

**Nom de signature sous une formule de clôture (P2-54).** Sonde : « Cordialement,⏎Zorglub Quenelle⏎Infirmier » laissait
le nom en clair quand le prénom n'est pas au gazetteer (10 cas rouges). Une formule de clôture seule sur sa ligne
(`Cordialement`, `Bien à vous`, `Bonne journée`, `Respectueusement`, `Cdt`, `Best regards`, `Sincerely`… ; 20
formules) suivie, sur la ligne suivante (une ligne vide tolérée), d'un nom seul de 1 à 3 mots en majuscule
initiale, est masquée. Exclus : articles élidés (« L'équipe »), mots-clés d'établissement, débuts de ligne désignant
une structure (« Service », « Direction », « Équipe », « Pôle », « Pour »…) et une ligne de trois mots tout en
majuscules (« POUR LE SERVICE »). Banc inchangé octet pour octet ; 810 tests ; 50 000 signatures : 6,9 s
(coût de résolution des pseudonymes, déjà documenté au-delà de ~50 000 mentions), sans signature : linéaire.
**Non traité** : signature sans formule (nom seul en fin de message), nom suivi d'une fonction sur la même ligne
(« Zorglub Quenelle, infirmier »), formule hors liste ; une structure hors liste sur la ligne suivante (« Cabinet
Médical Dupont » est exclu, « Maison Bleue » ne l'est pas) est masquée à tort.

**Nom derrière une étiquette de rôle sans ambiguïté (P2-55).** Sonde : « Patient : Zorglub Quenelle », « Résident : … »,
« Bénéficiaire : … », « Usager : … », « Personne de confiance : … », « Médecin traitant : … » laissaient le nom en
clair quand le prénom n'est pas au gazetteer (15 cas rouges). Ce point était laissé au mainteneur en P2-41 (« par choix ») ;
il est repris sous une forme **bornée et révocable** : seules les étiquettes qui désignent une personne
(`Patient(e)`, `Résident(e)`, `Bénéficiaire`, `Usager(ère)`, `Personne accompagnée / de confiance / à prévenir`,
`Médecin traitant`, en minuscules, capitale ou majuscules) sont retenues, et la valeur doit compter **2 à 3 mots** en
majuscule initiale (une valeur d'un seul mot, « Patient : Oui », est trop souvent un état). Exclus : mots-clés
d'établissement (ces valeurs restent des `ETABLISSEMENT`, jamais des `NOM`), `Cabinet`, `Association`, `Service`,
`Pôle`, `Direction`, `Équipe`…, `Non`, `Oui`, `Aucun`, `Sans`, `Inconnu`, `Voir`, articles élidés. Les étiquettes
qui précèdent aussi des organismes (« Contact », « Tuteur », « Représentant légal », « Destinataire ») restent
**hors périmètre**. Banc inchangé octet pour octet ; 838 tests ; un seul mot après l'étiquette (« Patient :
Quenelle ») n'est toujours pas détecté ; 100 000 étiquettes consécutives : 28 s (coût de résolution des pseudonymes
déjà documenté au-delà de ~50 000 mentions ; 2 s sans cette règle). Pour revenir en arrière : retirer
`_etiquetteRole` de la boucle de `detect`.

**Adresse sans code postal (P2-56).** Sonde de 18 formulations d'adresse : « 12 rue des Lilas », « 27 boulevard
Haussmann », « Adresse : 12 cours Victor Hugo », « 8, Av. Jean Jaurès à Lyon » restaient **en clair** (ou, pour les
deux dernières, le nom de la voie était pris pour un nom de personne et « 12 cours » fuyait), la détection exigeant un
code postal. Une adresse = numéro (suffixe `bis`/`ter`/lettre A-F toléré) + type de voie + nom de voie de 1 à 5
mots en majuscule initiale (ou nombre : « rue du 8 Mai 1945 ») est maintenant masquée, confiance 0.55. Types de voie :
ceux de la forme avec code postal, **sauf** les abréviations ambiguës (`r`, `pl`, `ch`, `all`, `sq`, `crs`, `imp`).
Tests d'abord (11 rouges) ; 9 contre-exemples intacts (« 3 places libres », « 2 cours à suivre », « 3 chemin de fer »,
« 12 place disponible », « Annexe 12 B », « Chapitre 3 Cours de biologie »…). Un test existant a changé d'attendu :
`adresse_multiligne` cas 4 (voie, ligne vide, code postal) donne maintenant **deux** adresses séparées (la voie, la
commune) au lieu d'une ; l'intention (aucun span ne traverse la ligne vide) est conservée. Banc inchangé octet pour
octet ; 861 tests ; coût : ×1,2 à ×1,5 sur des entrées pathologiques (le motif existant avec code postal est déjà
superlinéaire sur « 12 rue » répété : 8 s pour 1 Mo, avant comme après). **Non traité** : nom de voie en minuscules
(« 12 rue des lilas »), ville seule (« Paris 11e »), numéro en toutes lettres, lieu-dit sans numéro, type de voie
tronqué ; un nom d'œuvre ou de produit « 12 Place Value » sera masqué à tort.

**Identifiants étiquetés (P2-57).** Sonde de 20 identifiants (27 octobre 2026) : 17 restaient **en clair** — IPP,
numéro de dossier, de patient, d'adhérent, d'allocataire, de contrat, passeport, CNI, permis de conduire, plaque
d'immatriculation, adresse IP, dossier MDPH. Ils n'ont aucune clé de contrôle ni type d'entité. **Nouveau type
`identifiant`** (jeton `[IDENTIFIANT_n]`), qui ajoute une valeur à `EntityType` dans `ecluse_core` (changement
d'API publique : `ecluse_audit` liste les types connus depuis l'énumération, donc sans autre modification). Le
détecteur `IdentifiantDetector` (`ecluse_redact`, niveau « motif », confiance 0.7) exige une **étiquette** (`IPP`, `IEP`,
« N° de dossier / patient / adhérent / allocataire / contrat / police / client », « Dossier MDPH n° », `Passeport`,
`CNI`, « Carte (nationale) d'identité », « Permis de conduire », `Immatriculation`, `Plaque`, `IP`, « adresse IP ») **et**
une valeur qui ressemble à un identifiant (au moins 5 chiffres, ou 3 chiffres + une lettre sur 6 caractères au
moins) : « Dossier n° 12 », « Passeport 2024 », « IPP : à renseigner » restent intacts. Seule la plaque au format SIV
(`AB-123-CD`, sans les lettres I, O, U) est masquée sans étiquette ; une adresse IPv4 exige l'étiquette `IP` et des
octets ≤ 255. Tests d'abord (22 rouges) ; 14 contre-exemples intacts ; banc inchangé octet pour octet ; 898 tests
(`ecluse_redact`), tous les paquets verts. **Non traité** : ancienne plaque (`1234 AB 56`), IPv6, identifiants sans
étiquette (une suite de chiffres isolée), SIREN/SIRET (entreprise, hors personne), numéro d'étiquette en minuscules
sans « n° ». **À arbitrer par le mainteneur** : le choix d'un type dédié (plutôt que des types par catégorie) et le
libellé du jeton ; retour arrière : retirer `IdentifiantDetector` de `Ecluse.defaultDetectors`.

**Coût d'un mot composé très long (P2-58).** Défaut **introduit par P2-53** (« nom devant `<adresse>` a écrit »),
trouvé en mesurant P2-57 : un mot en majuscule initiale fait de segments reliés par des tirets (« Aa-Aa-Aa-… »,
« AB-123-AB-123-… ») était traité en temps cubique, le motif repartant de chaque segment du mot : 12 000 segments
(36 Ko) prenaient 16 s, 140 Ko plus de 45 s, et le coût croît encore plus vite au-delà. Le motif exige maintenant un
début de mot strict (le tiret et l'apostrophe ne comptent pas comme une frontière). Mesuré : 36 Ko en 16 s → moins
de 5 s (test de coût, trois formes de mots composés) ; 0,9 à 1,05 Mo de mots composés en 1,3 à 5,7 s ; version avant
P2-53 : 5 ms (le défaut venait bien de cette règle). Banc inchangé octet pour octet ; 865 tests. Les autres motifs
de P2-53, P2-54 et P2-55 ont été mesurés sur les mêmes entrées : linéaires. Leçon de méthode : la batterie de coût
de P2-53 ne contenait aucun mot composé ; elle en contient maintenant.

**Téléphones étrangers : voisins et Maghreb (P2-60).** Arbitrage du 27 octobre (question 5). Un correspondant à
l'étranger (`+32 475 12 34 56`, `0032…`, `+41 (0)79 123 45 67`) restait en clair. Sont maintenant masqués les numéros de
Belgique (+32), Suisse (+41), Luxembourg (+352), Allemagne (+49), Espagne (+34), Italie (+39), Royaume-Uni (+44),
Maroc (+212), Algérie (+213) et Tunisie (+216), avec l'indicatif **obligatoire** (`+cc`, `(+cc)` ou `00cc`), le `(0)`
facultatif, tous les séparateurs déjà admis, et un **nombre de chiffres propre au pays** (par exemple 9 pour la
Suisse, 8 pour la Tunisie, 8 à 13 pour l'Allemagne). Tests d'abord (25 rouges) ; 10 contre-exemples intacts (numéro
trop court ou trop long, pays non couvert, `+1 202 555 0143`, indicatif sans `+`). Un test existant a changé
d'attendu : « 0044 20 7946 0958 » était rejeté comme « préfixe 00 non FR » ; il est maintenant détecté, et le
rejet porte sur « 001 202 555 0143 » (États-Unis). Banc inchangé octet pour octet ; 937 tests ; coût linéaire sur
7 entrées pathologiques de 0,8 à 0,9 Mo (2,2 à 6,1 s). **Non traité** : les autres pays (États-Unis, Canada, reste de
l'Afrique, Asie, Europe de l'Est…), les numéros sans indicatif écrits à la locale du pays, les extensions. Un numéro
suivi d'un espace et de chiffres (« +32 475 12 34 56 78 ») est masqué sur sa partie valide, le reste restant en clair
(choix prudent : masquer la partie reconnue plutôt que rien). Les longueurs par pays sont des plages usuelles, non
une validation d'un plan de numérotation : un numéro réel hors plage serait manqué.

**Un type par catégorie d'identifiant (P2-59).** Arbitrage du 27 octobre (question 1) : `identifiant` est scindé en
quatre types, avec des jetons distincts — `identifiant` (`[IDENTIFIANT_n]` : dossier, patient, adhérent, allocataire,
contrat, IPP/IEP), `pieceIdentite` (`[PIECE_IDENTITE_n]` : passeport, CNI, permis de conduire), `vehicule`
(`[VEHICULE_n]` : plaque) et `reseau` (`[RESEAU_n]` : adresse IP). Le type `identifiant` est **conservé** pour la
catégorie administrative : il existe depuis P2-57 et `ecluse_audit` refuse les types inconnus de son énumération,
donc un journal déjà écrit avec ce nom reste lisible. Ajout de trois valeurs à `EntityType` (`ecluse_core`) : changement
d'API publique, pas de retrait. Test d'abord (11 rouges), détections identiques à P2-57 (mêmes 22 + 14 cas) ; banc
inchangé octet pour octet ; 902 tests (`ecluse_redact`), tous les paquets verts. Un même numéro n'a qu'un type : un
passeport étiqueté et un n° de dossier identique en chiffres restent deux jetons, de types différents. **Non traité** :
la pondération du risque ou le refus à l'aperçu par catégorie — la scission le permet, aucune règle n'est définie.

**IBAN de l'espace SEPA (P2-62).** Arbitrage du 27 octobre (question 8). Seul l'IBAN français était détecté : un IBAN
belge, suisse, allemand ou espagnol (RIB d'un résident frontalier) restait en clair. `IbanDetector` (`ecluse_core`)
couvre 38 pays — AD, AT, BE, BG, CH, CY, CZ, DE, DK, EE, ES, FI, FO, FR, GB, GI, GR, HR, HU, IE, IS, IT, LI, LT, LU,
LV, MC, MT, NL, NO, PL, PT, RO, SE, SI, SK, SM, VA — avec la **longueur propre au pays** et la même clé ISO 7064 mod
97-10 que le détecteur français (confiance 1.0, séparateurs espace, tiret, point, barre oblique, minuscules admis).
`Ecluse.defaultDetectors` l'utilise à la place de `IbanFrDetector`, qui reste exporté et inchangé. Tests d'abord (IBAN
**générés**, jamais copiés : 38 pays en forme compacte et groupée, 5 rejets, 6 rouges d'intégration) ; banc inchangé octet
pour octet ; core 212 et redact 945 tests, tous les paquets verts ; coût équivalent à la base (≤ +25 %, 6 entrées d'~1 Mo).
**Vérification des longueurs** : 24 des 38 ont été recoupées avec des documents bancaires publics (liste consultée par
recherche, 27 octobre 2026) ; CH, ES et SE, FO, GI, LI, LT, LV, MC, MT, RO, SI, SK, SM, VA n'ont pas pu l'être, le registre
SWIFT (ISO 13616) n'étant pas joignable depuis l'environnement d'exécution ; elles sont reprises du registre de mémoire. Une
longueur fausse entraînerait un IBAN **manqué**, jamais un faux positif (la clé reste exigée) : à confirmer par le
mainteneur contre le registre. Luxembourg : 20 (trois sources) contre 19 dans une quatrième. **Non traité** : BIC/SWIFT,
IBAN hors espace SEPA (Maroc, Algérie, Tunisie, Royaume-Uni hors SEPA…), IBAN coupé par un saut de ligne au milieu d'un groupe.

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

**Jeton déformé par le LLM à la restauration (P2-31).** Sonde de 17 déformations d'un jeton
(`[NOM_1]`) dans une réponse : 8 étaient restaurées avant P2-31 (jeton exact, casse, espaces,
sans soulignement, gras, point final, possessif, code en ligne). Non restaurées, donc laissées
telles quelles dans la réponse : l'échappement Markdown (`\[NOM\_1\]`, très courant quand
le LLM répond en Markdown), les crochets échappés seuls, les jetons sans crochets, entre
parenthèses, accolades, chevrons ou guillemets, le tiret à la place du soulignement et les
crochets pleine chasse. Depuis P2-31, l'échappement Markdown (barre oblique inversée devant un
crochet ou un soulignement) est restauré : 2 formes de plus de la sonde (l'échappement
complet et les crochets échappés seuls), soit 10 sur 17 (mesuré). Le reste
n'est **volontairement pas** restauré : changer les délimiteurs ou deviner un jeton sans
crochets exposerait à restaurer la mauvaise valeur ; un jeton non restauré reste visible dans
la réponse plutôt que remplacé à tort. Le numéro reste exact : `\[NOM\_10\]` ne restaure
jamais `[NOM_1]`. Effet de bord assumé : une barre oblique inversée placée juste devant un
jeton exact est consommée avec lui.

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

### 5.5 Coût d'un dossier volumineux

Mesure du 26 octobre 2026 (machine de développement, textes synthétiques courts,
environ trois jetons par document ; mesure unique, sans répétition ni intervalle de
confiance). Avant P2-25, le temps d'un appel `Ecluse.redact` dans un même `Dossier`
croissait plus vite que linéairement avec le nombre de documents déjà masqués :
environ 1 ms après 100 documents, 3 ms après 500, 9 ms après 1 000 et 53 ms après
2 000. Cause isolée par un sondage : la recherche des jetons déjà attribués écrits en
clair dans le texte compilait un motif par jeton et par appel (environ 38 ms sur 53
à 2 000 documents).

P2-25 ne cherche ces jetons que dans les segments `[...]` du texte (un motif de jeton
ne peut pas se trouver ailleurs) et garde les motifs compilés. Résultat identique
(test d'équivalence à l'ancienne définition, 13 variantes et 300 textes aléatoires,
graine 42 ; prédictions du banc dossiers inchangées octet pour octet). Après : 0,3 ms
par appel à 2 000 documents pour un texte sans crochet, 3,3 ms pour un texte qui en
contient un. `Apercu.risque`, qui copie l'état du dossier, coûte environ 3 ms à
100 documents, 6 ms à 1 000 et 105 ms à 5 000 (copie de l'état, non optimisée).

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
  l'application, sur le texte réellement masqué ; avant elle, `Apercu.risque`
  (ou `Proposition.risque`, tout accepté, si l'appelant fournit une référence)
  le calcule sur une copie de l'état, sans rien modifier (P2-23). Mesuré sur
  2 191 documents synthétiques avec refus aléatoires (graine 42), dans un
  dossier : 0 différence de statut, d'estimation ou de positions avec le
  rapport de l'application (259 documents évalués).
  Pour un fichier (`ecluse_ingest`), l'aperçu porte sur le **texte extrait**
  (P2-24) : ce qui n'est pas lu (en-têtes, pieds de page, notes, images,
  scans) n'apparaît pas dans la proposition ; l'application doit afficher les
  avertissements d'ingestion (`ignored_parts`) avec l'aperçu, sans quoi
  l'utilisateur croira avoir validé tout le document. Mesure (26 octobre 2026,
  3 391 documents synthétiques des corpus dossiers, flou et étendu, 6 163
  entités) : « tout accepté » donne un texte masqué, une carte et des
  avertissements identiques à `Ecluse.redact` (0 différence) ; des refus
  aléatoires (graine 42, hors entités structurelles et secrets) n'ajoutent
  aucune restauration non identique à celles que `redact` produit déjà (60
  documents sur 3 391 : harmonisation des re-mentions, point 5 de l'essentiel).
  En dossier (530 dossiers, 2 382 documents, règles N1 et N2, 26 octobre 2026),
  la séquence propose puis applique « tout accepté » reste identique à la
  séquence d'`Ecluse.redact` : 0 différence de texte masqué, de carte ou
  d'avertissement.
  Les blancs en bordure d'un ajout manuel ne sont pas masqués (P2-20) : deux
  mentions qui ne différaient que par eux partageaient un jeton et la
  restauration ajoutait des espaces. Un ajout de type `nom` reste soumis à
  l'harmonisation des re-mentions (point 5) : sur 2 431 ajouts aléatoires de
  texte quelconque, 2 documents sur 2 191 y gagnent une restauration non
  identique (un ajout « le » inclus dans un ajout « le mardi »).
  Un ajout dont une borne coupe une paire de substituts UTF-16 (un émoji, par
  exemple) est refusé (P2-21) : accepté, il laissait une moitié de caractère
  isolée dans le texte envoyé, non encodable. Les détecteurs n'ont produit
  aucune coupure de ce genre sur 7 entités d'un échantillon d'émojis et de
  lettres mathématiques : sondage étroit, pas une garantie.

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
Un compte masqué ne doit pas se retrouver par soustraction (P2-26) : le nombre
d'entrées de la chaîne, qui publiait le total exact même sous « moins de 5 », suit
le masquage du total ; le total n'est communiqué que si aucune opération n'est
masquée ; et si un seul code de refus est masqué alors que le nombre de refus est
exact, le plus petit autre code est retenu aussi (« non communiqué (recoupement) »).
Ces règles couvrent les sommes que l'export publie lui-même ; elles ne protègent pas
contre un attaquant qui connaît d'autres comptes (autres exports, journaux de
l'application) : le seuil reste provisoire.

Falsification de la chaîne (26 octobre 2026, 2 000 journaux synthétiques de 3 à 12
entrées, graine 42, script jetable) : toute modification d'un champ (comptes,
moteur, horodatage, rang), suppression au milieu ou de la première entrée, échange
de deux entrées ou duplication est détectée (0 non détecté sur 10 000 essais
environ) ; la troncature en fin de journal n'est **jamais** détectée (2 000 sur
2 000), comme annoncé. Une réécriture complète par qui contrôle le fichier n'a pas
été essayée : elle reste hors de portée d'un hash chaîné.

Le journal prouve la cohérence interne de la chaîne, pas la vérité des
événements. Les comptes révèlent la nature d'un document (deux NIR et un IBAN
évoquent un dossier de paie) et un horodatage rapproché des journaux d'une
application peut relier une entrée à une personne : **l'affirmation « ce
journal n'est pas une donnée personnelle » n'est pas validée** (avis d'un DPO
attendu ; ceci n'est pas un avis juridique). Le README parle d'un journal
« signé » : ce n'est pas le cas en v0 (le README a été corrigé en ce sens).

---

**Écluse réduit le risque, il ne l'annule pas.**
