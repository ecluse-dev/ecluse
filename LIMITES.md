# Limites connues d'Écluse (v0)

**Écluse réduit le risque, il ne l'annule pas.**

Ce document complète le `README.md` : il ne décrit pas ce qu'Écluse protège,
mais **ce qu'il ne protège pas encore**. Afficher une limite est une mesure
de sécurité à part entière — un faux sentiment de protection est pire qu'une
absence de protection connue.

---

## Résumé : ce qu'Écluse ne fait pas

Deux pages au plus, pour un DPO, un client ou un agent. Chaque ligne renvoie au
paragraphe détaillé plus bas. Le détail fait foi ; ce résumé ne le remplace pas.
En une phrase : **Écluse réduit le risque, il ne l'annule pas.**

### Ce qu'Écluse ne lit pas (formats)

- **Images, scans, PDF-image, manuscrit** : refusés avec un motif, jamais lus
  à moitié. Voir [§ 4](#4-fichiers-pris-en-charge-ecluse_ingest).
- **PDF abîmé** : une page perdue peut passer sans avertissement (6 cas sur
  1 500 copies abîmées, mesure P2-28) ; un octet altéré dans le texte d'une
  page n'est pas détecté. Voir [PDF abîmés](#pdf-abîmés--pages-perdues-p2-28) et
  [archives](#intégrité-des-archives-docx-et-odt-p2-27).
- **En-têtes, pieds de page, notes et commentaires** de `.docx` et `.odt` :
  non lus, signalés par `ignored_parts`. Voir [§ 1](#1-deux-familles-de-détecteurs-deux-niveaux-de-confiance) et
  [§ 4](#4-fichiers-pris-en-charge-ecluse_ingest).
- **Dictée vocale** : absente. Voir [§ 6](#6-hors-périmètre-v0).

### Ce qu'Écluse ne détecte pas (limites de détection)

- **Noms et adresses** : des heuristiques, pas des preuves. Un modèle local
  a été mesuré et écarté. Voir [§ 1](#1-deux-familles-de-détecteurs-deux-niveaux-de-confiance).
- **Nom de famille seul, sans civilité** : peut rester en clair à sa première
  mention, sauf derrière « le dossier de », « à la demande de », « l'entretien
  avec » ou devant « a confirmé » (P2-220, au prix de noms communs capitalisés
  et, sauf après « à la demande de », de noms de grandes villes masqués à tort,
  P2-228 ; après « à la demande de », seules les communes de 100 000 habitants et
  plus sont écartées, donc une ville plus petite y est masquée, P2-239). Voir [5.2.2](#522-noms-sans-civilité-et-titres) et [§ 5.4](#54-portée-du-rattrapage-des-mentions-partielles).
- **Identifiants hors liste** : BIC, IBAN non français, secrets sans préfixe
  connu, autres identifiants professionnels, numéro INS lui-même. Voir
  [§ 2](#2-identifiants-non-couverts).
- **Lieux isolés, professions, pathologies fréquentes** : en clair ; seules
  les maladies rares d'un catalogue fourni sont masquées. Voir
  [§ 3](#3-lieux-et-quasi-identifiants).
- **Textes en minuscules ou en capitales** : fiabilité moindre. Voir
  [5.2.4](#524-casse--minuscules-capitales-casse-de-phrase).
- **Numéros étrangers, adresses sans code postal, courriels obfusqués** :
  couverture partielle. Voir [5.2.7](#527-téléphones-noms-de-naissance-titres-et-particules), [5.2.9](#529-adresses-sans-code-postal-identifiants-étiquetés-iban-téléphones-étrangers) et
  [§ 1](#1-deux-familles-de-détecteurs-deux-niveaux-de-confiance).
- **Valeur coupée par la mise en forme** (fin de ligne, tableau) : couverte
  seulement dans les cas listés. Voir [5.2.1](#521-coupures-de-ligne--adresses-et-établissements) et
  [5.2.6](#526-identifiants-coupés-dates-et-étiquettes-de-champ).
- **Sur-masquage** : en cas de doute, Écluse masque. C'est un choix. Voir
  [§ 5.1](#51-faux-positifs-assumés).

### Fuites résiduelles

- **Pas de garantie d'anonymat.** L'estimation de ré-identification est un
  rapport ; son rappel est limité ; « aucun quasi-identifiant détecté » n'est
  pas « risque faible ». Voir [§ 7](#7-estimation-de-ré-identification-ecluse_reid-ecluse_reference).
- **Refuser une détection dans l'aperçu envoie la valeur en clair.** Voir
  [§ 6](#6-hors-périmètre-v0).
- **Un secret déjà envoyé ailleurs** n'est pas rendu inoffensif : il faut le
  révoquer. Voir [§ 2](#2-identifiants-non-couverts).
- **Ce qui sort à côté du texte** (`toString`, erreurs, trace d'audit) :
  neutralisé pour les objets listés. Voir [§ 7](#ce-qui-sort-à-côté-du-texte--tostring-messages-derreur-et-trace-daudit-p2-169-p2-170-p2-172).
- **Généralisation** : jamais automatique, irréversible quand l'application
  l'applique. Voir [§ 7](#généralisation-appliquée-p2-91-p2-92).
- **Journal d'audit** : pas une signature ; une troncature en fin de journal
  n'est pas détectée. Voir [§ 8](#8-journal-daudit-ecluse_audit-v0).

### Restauration

- **Une graphie par jeton** : une re-mention partielle est restaurée sous la
  forme la plus complète. Voir [§ 5.3](#53-cohérence-des-pseudonymes-et-fidélité-de-la-restauration).
- **Deux personnes de même patronyme** : peuvent partager un jeton. Voir
  [§ 5.3](#53-cohérence-des-pseudonymes-et-fidélité-de-la-restauration).
- **Jeton déformé par le LLM** : seules certaines déformations sont restaurées.
  Voir [§ 5.3](#53-cohérence-des-pseudonymes-et-fidélité-de-la-restauration).
- **Table de correspondance** : en mémoire, non chiffrée, non conservée. Voir
  [§ 5.3](#53-cohérence-des-pseudonymes-et-fidélité-de-la-restauration).
- **Dossier** : sans lui, les jetons changent d'un document à l'autre ; avec
  lui, une mention partielle peut recevoir un nouveau jeton. Voir
  [§ 5.3](#53-cohérence-des-pseudonymes-et-fidélité-de-la-restauration) et [§ 5.5](#55-coût-dun-dossier-volumineux).

### Carte du § 5.2 (entités coupées ou mal formées)

Chaque sous-section du détail est citée ici ; les paragraphes qu'elle
contient sont couverts par ce renvoi.

- [5.2.1](#521-coupures-de-ligne--adresses-et-établissements) coupures de ligne ; [5.2.2](#522-noms-sans-civilité-et-titres) noms sans civilité ;
  [5.2.3](#523-caractères-invisibles-et-accents-décomposés) caractères invisibles ; [5.2.4](#524-casse--minuscules-capitales-casse-de-phrase) casse.
- [5.2.5](#525-variantes-décriture--noms-dates-civilités-voies-cedex) variantes d'écriture ; [5.2.6](#526-identifiants-coupés-dates-et-étiquettes-de-champ) identifiants coupés ;
  [5.2.7](#527-téléphones-noms-de-naissance-titres-et-particules) téléphones et titres ; [5.2.8](#528-types-de-voie-balisage-courriels-signatures-rôles) voies, signatures.
- [5.2.9](#529-adresses-sans-code-postal-identifiants-étiquetés-iban-téléphones-étrangers) adresses sans code postal, IBAN ;
  [5.2.10](#5210-tableaux-formats-structurés-et-coût-de-calcul) tableaux et coût ; [5.2.11](#5211-prénoms-civilités-au-pluriel-chemins-noms-coupés) prénoms et chemins ;
  [5.2.12](#5212-relecture-indépendante--sur-masquages-coûts-et-fuites) relecture indépendante.
- Les sections [5.1](#51-faux-positifs-assumés) à [5.5](#55-coût-dun-dossier-volumineux), [§ 6](#6-hors-périmètre-v0) à
  [§ 8](#8-journal-daudit-ecluse_audit-v0) sont citées plus haut.
- Les dix lignes qui suivent (« L'essentiel ») restent telles quelles : elles
  font partie du détail.

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
6. **Hors périmètre v0** : dictée vocale. Le journal d'audit (`ecluse_audit`,
   § 8) se branche **en option** sur `Ecluse.redact` (`journal:`, P2-96) ;
   sans journal, rien n'est tracé. L'estimation de ré-identification produit
   un rapport **en option** (`riskReference:`, P2-04) avec des suggestions de
   généralisation (P2-91) ; la généralisation n'est appliquée que si
   l'application appelle `appliquerGeneralisations` (P2-92). Limites au § 7.
7. **Pathologies : seules les maladies rares sont masquées, aucune n'est
   comptée.** Avec le catalogue Orphanet passé en `maladiesRares:` (P2-143),
   une maladie rare rattachée à une personne (« atteinte de la maladie de
   Huntington ») devient `[MALADIE_RARE_1]`, restaurable. Sans ce catalogue,
   rien n'est masqué. Les pathologies fréquentes **restent en clair** :
   le rapport de risque les liste, elles n'entrent pas dans l'estimation
   (§ 3), et une généralisation est proposée, appliquée seulement sur
   demande. Une maladie rare citée sous un nom très long ou absent du
   catalogue part en clair, comme une maladie rare non rattachée dans un
   texte où aucun nom de personne n'est détecté. La table des pathologies fréquentes a été
   validée cliniquement par le mainteneur (P2-110).
8. **Textes tout en minuscules, tout en capitales ou en casse de phrase**
   (majuscule en début de phrase seulement) : des détecteurs
   dédiés rattrapent noms, adresses et établissements, avec une fiabilité
   moindre qu'en casse ordinaire ; un texte sans majuscule produit un
   avertissement (§ 5).

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
> **SIREN nommé (P2-248).** Quand le texte appelle le nombre « SIREN » ou
> « SIRET » (fenêtre de 40 caractères avant ou après), l'entité est de type
> `siren` (jeton `[SIREN_n]`), toujours masquée : le SIREN d'un entrepreneur
> individuel désigne une personne. Si le mot « FINESS » est aussi dans la
> fenêtre, le FINESS l'emporte. Un SIREN écrit sans ce mot (« RCS », « Kbis »,
> « numéro d'entreprise ») reste lu comme FINESS à confiance 0,5, et un
> vrai FINESS voisin du mot « SIREN » sans le mot « FINESS » serait typé `siren` :
> dans les deux cas le nombre est masqué, seule l'étiquette change.

**Heuristiques v0** (nom, adresse, date de naissance, téléphone, email,
établissement) : aucune structure vérifiable n'existe pour ces types. La
détection repose sur des motifs et du contexte (civilité, prénom connu,
mot-clé de voie ou d'établissement), pas sur une clé de contrôle. Ce sont
des approximations volontairement prudentes (« en cas de doute, on masque »),
pas des preuves. Un modèle NER local a été mesuré et **écarté** (P2-89,
P2-90 : gain insuffisant, 46,5 % de faux positifs sur le témoin) : ces
heuristiques restent la seule détection des noms et adresses. Les mentions
« NER de la phase 2 » plus bas désignent des angles morts sans solution
prévue.

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
(`NIR 1 85 05 78 006 084 91 12 ans`).

**Identifiant suivi d'une date, d'un âge ou d'un nombre (P2-174).** Témoin
`bench/generate_corpus_identifiant_suivi.py` : 4 800 documents synthétiques
(NIR, RPPS, IBAN, FINESS × date en chiffres, date en lettres, âge, quantité ×
espace, virgule, retour à la ligne), chemin **`Ecluse.redact`**. Avant P2-174,
**804 identifiants sur 4 800 n'étaient pas couverts** (17 %, une fuite) : un
identifiant à espacement irrégulier (espaces multiples, tabulation, espace
insécable) collé à un nombre voisin (NIR 202, IBAN 290), et un FINESS écrit
« 12 345 678 9 » suivi d'un nombre (312) ; c'était le reste laissé par
P1-19. S'y ajoutaient 55 FINESS masqués **comme RPPS** en avalant le jour de
la date ou l'âge (neuf chiffres et deux font onze, la clé de Luhn passe une
fois sur dix) : rien en clair, mais un type faux et une date abîmée. Après :
**1 identifiant non couvert, 2 documents en défaut** sur 4 800. Trois
changements, dans `ecluse_core` :

- un troisième passage de `DigitCompaction.candidates` sur un texte
  **régularisé** (chaque suite de blancs entre deux chiffres devient une
  espace au lieu de disparaître) : il lit un identifiant à blancs irréguliers
  comme s'il était écrit avec des espaces simples, sans souder le voisin ;
- un motif groupé « 12 345 678 9 » pour le FINESS (groupement strict 2-3-3-1,
  espace seule) ;
- un candidat qui finit au milieu d'une date en chiffres (« … 12/03/2024 »)
  est écarté ; un RPPS formé de neuf chiffres à clé de Luhn valide puis de
  deux chiffres l'était aussi **si la suite le prouvait** (nom de mois, « ans »),
  mais cette seconde garde est **retirée par P2-306** (voir ci-dessous).

**P2-306 (27 novembre 2026) : neuf chiffres de Luhn juste + deux chiffres + un
mois ou « ans » sont masqués en entier, sous le type RPPS.** La garde
`rpps_finess_date` écartait ce passage (il se lit comme un FINESS suivi du jour
d'une date) : mais la même forme est un RPPS écrit en deux groupes, et ses deux
derniers chiffres partaient en clair (mesure P2-303, sonde de 39 cas :
117 caractères sur 468 en clair ; **0 après**, 39 / 39 couverts, chemin
`Ecluse.redact`). Décision du mainteneur, « dans le doute, masquer ». **Coût**
(témoin « identifiant suivi », 4 800 documents, `Ecluse.redact`) : 40 FINESS de
plus sont masqués **comme RPPS** en avalant le jour de la date ou l'âge (2 → 42
types faux sur 4 800 ; 27 suivis d'un âge, 13 d'un nom de mois) ; rien en clair
de plus, la date est abîmée. Les autres témoins ne changent pas : prédictions
identiques octet pour octet sur 76 fichiers de prédictions du tableau de bord sur
77, 58 / 5 000 documents masqués à tort sur le témoin durci élargi avant comme
après, 0 / 5 600 (mots-nombres), 0 / 200 000 phrases sans personne. **Ce qui était
silencieux est signalé par P2-309** (ci-dessous) : un candidat dont les deux
derniers chiffres ouvrent une date complète en chiffres (« … 12/03/2024 ») est
écarté par `DigitCompaction` pour tous les détecteurs.

**Ce qui reste :**

- **Sans preuve, le RPPS garde tout.** « 123456789 12 séances » : rien ne dit
  que « 12 » n'est pas la fin d'un RPPS écrit en deux groupes. Les onze
  chiffres restent masqués sous le type RPPS (sur-masquage et type faux,
  jamais une fuite). Aucun des 400 FINESS suivis d'une quantité du témoin n'y
  tombe ; le cas est tenu par un test unitaire.
- **Deux candidats qui se chevauchent en partie.** « 12 785 847 0 1250
  jours » : un bloc de onze chiffres à cheval sur la fin du FINESS et le
  nombre voisin passe Luhn, le résolveur de chevauchements garde le RPPS et
  les deux premiers chiffres du FINESS restent en clair (1 cas sur 4 800 ;
  c'était déjà le cas avant, quand le FINESS n'était pas détecté du tout).
  Masquer l'union de deux candidats qui se chevauchent serait la réponse ;
  ce n'est pas fait.
- **Un RPPS suivi d'un nombre peut passer pour un NIR** (onze chiffres et
  quatre font quinze ; clé valide par hasard) : 1 cas sur 4 800, tout masqué.
- Le motif groupé du FINESS ne connaît que « 12 345 678 9 ». Un autre
  groupement (« 123 456 789 ») suivi d'un nombre n'est pas détecté. Non
  mesuré : le corpus n'écrit pas cette forme.
- **Moteur seul** (`ecluse_core` sans `ecluse_redact`) : la fin d'un IBAN à
  blancs irréguliers coupé par un retour à la ligne peut être lue comme un
  RPPS (1 faux positif de plus sur le corpus structurel à 90 colonnes : 2 →
  3). Par `Ecluse.redact`, qui recolle la ligne, l'IBAN est lu en entier
  (778 / 778 ; 826 / 826 depuis l'annotation des IBAN à clé fausse le
  22 novembre).

**NIR et IBAN : variantes de forme.** Le NIR est reconnu avec un mois de
naissance fictif (`00`, `20` à `42`, `50` à `99`, d'après la nomenclature
DGFiP citée par le mainteneur ; l'instruction INSEE n'a pas été lue) dès que
la clé de contrôle est valide, et avec les séparateurs espace, point, tiret,
barre oblique, tabulation, espace insécable et espaces typographiques (dont
l'espace fine U+2009). Les mois 13 à 19 et 43 à 49 restent rejetés. L'IBAN
accepte espace, tiret, point et barre oblique.
**Coupure de ligne** : un identifiant (NIR, IBAN, téléphone, date de naissance numérique) coupé par
un saut de ligne **entre deux groupes de chiffres** est détecté (P2-38), y compris après la lettre d'un
groupe (« 461K⏎4056 », « 2A⏎073 ») et quand la fin de ligne est bordée d'espaces insécables (P2-152) ;
une coupure au milieu d'un groupe ne l'est pas.

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
  Mesure (P2-255, `Ecluse.redact`, corpus étendu, graine 42) : 32 ADELI
  valides sans mot-clé sur 32 masqués en entier **sous le type `finess`**,
  aucun caractère en clair. Le corpus garde l'annotation `adeli`, qui dit ce
  qu'est le numéro ; c'est le type prédit qui est faux (décision du
  23 novembre, Q7). Un scoreur strict au type compte donc un faux négatif
  `adeli` et un faux positif `finess` par document de ce gabarit.
- **RPPS à clé de Luhn fausse, sans libellé : en clair (décision du
  23 novembre, Q2).** Hors libellé (« RPPS », « n° RPPS »…), un nombre de
  onze chiffres dont la clé de Luhn est fausse n'est pas masqué : 39 sur 39 en
  clair au corpus v3, 24 sur 24 au corpus étendu (P2-255). C'est un choix :
  onze chiffres, c'est aussi la longueur de beaucoup de numéros ordinaires
  (références, téléphones avec indicatif), le risque de masquer à tort serait
  élevé, et un RPPS désigne un professionnel inscrit dans un annuaire public.
  Derrière son libellé, un RPPS à clé fausse est masqué (P2-188).
- **Type faux, sans fuite (décision du 23 novembre, Q6).** Deux gabarits
  synthétiques sont masqués en entier mais sous un type trompeur : un SIREN
  après « immatriculation » est pris pour une plaque (`vehicule`, 17 sur 27 au
  corpus étendu), et « réf. » suivi de dix chiffres pour un téléphone (3 sur 34
  en v3). Rien ne part en clair ; le LLM reçoit seulement une étiquette fausse.
  Toléré pour l'instant.
- **NIR à clé fausse, sans libellé : masqué en entier (P2-258).** Un NIR mal
  recopié reste celui d'un patient (décision du 23 novembre). `NirCleInvalideDetector`,
  appelé par `Ecluse.redact` sur le texte d'origine, masque quinze caractères de
  la forme d'un NIR (sexe 1 ou 2, mois et département plausibles, ordre non nul,
  « 2A »/« 2B » admis, lettre « O » ou « o » admise à la place d'un zéro) dont la
  clé est fausse : type `nir`, **confiance 0,3**, avertissement « identifiant à clé
  invalide masqué : à vérifier » (sans valeur). Mesure (`Ecluse.redact`, graine 42) :
  NIR pièges 45 / 45 en clair → 0 (v3), 29 / 29 → 0 (extended), « libellé fort »
  `sans libellé` 0 / 200 en clair ; rappel des vrais NIR inchangé ; aucun témoin
  négatif du tableau de bord ne gagne un masquage. **Limites** : (1) les coupures
  du numéro doivent tomber entre les groupes d'un NIR (1-2-2-2-3-3-2), former
  cinq groupes de trois (3-3-3-3-3, P2-263) ou n'exister nulle part, faute de quoi
  un RPPS suivi d'un nombre de quatre chiffres serait avalé ; un NIR à clé fausse
  écrit en groupes d'une autre taille n'est pas masqué, mais il est **signalé** « à
  vérifier » depuis P2-305 (voir plus bas) ; (2) un NIR à clé **juste**
  avec des lettres « O » et sans libellé reste en clair (P2-191, inchangé) ; (3)
  **P2-263** : le NIR à clé fausse coupé par une fin de ligne (n'importe où dans le
  numéro) ou écrit en chiffres pleine chasse est lu sur la vue de détection (P2-29),
  masqué en entier à 0,3 comme les autres ; une coupure de ligne juste après neuf
  ou onze chiffres de Luhn juste (RPPS ou FINESS suivi d'un nombre sur la ligne
  suivante) n'est pas lue comme un NIR, et un NIR coupé exactement là par hasard
  reste en clair ; les formes mêlant d'autres altérations de la vue (blancs
  invisibles, tirets typographiques) ne sont pas reprises ; (4) la clé nommée à part fausse (« 2550814168025 clé 39 »,
  P2-42) reste intacte ; (5) une suite de quinze chiffres de cette forme qui n'est
  pas un NIR (référence, numéro de lot) est masquée à tort, jamais une fuite.
- **SIRET nommé : masqué en entier (P2-259).** Quatorze chiffres (collés, ou
  groupés 3-3-3-5 avec une espace) à moins de 40 caractères du mot « SIRET »
  (casse indifférente, avant ou après) : type `siren`, jeton `[SIREN_n]`.
  Clé de Luhn sur les quatorze chiffres juste : confiance 0,9 ; fausse :
  confiance 0,3 avec l'avertissement « identifiant à clé invalide masqué : à
  vérifier ». Mesure (`Ecluse.redact`, graine 42) : SIRET pièges 30 / 30 en
  clair → 0 (v3), 19 / 19 → 0 (extended). **Limites** : sans le mot « SIRET »,
  quatorze chiffres ne sont pas masqués ; le motif groupé n'accepte que 3-3-3-5
  (un autre groupement est lu seulement s'il se compacte en quatorze chiffres) ;
  le SIRET est annoté `siren` au banc depuis le 23 novembre (P2-261, décision
  du 23 novembre, point 8) : les 30 SIRET du corpus v3 ne comptent plus comme
  faux positifs (moteur seul, v3 : 72 faux positifs `siren` → 0, précision
  92,4 % → 100 % sur 943 entités ; sur les types communs seuls, 100 % / 100 %).
  La ligne « SIRET … TVA … » du témoin flou, qui produisait 108 masquages
  `siren` par corpus témoin, a été retirée du témoin (remplacée par une ligne
  sans donnée personnelle) : le témoin « rien à masquer » redonne 0.
- **Numéro de TVA intracommunautaire : masqué en entier (P2-260).** « FR » + clé
  de deux caractères + SIREN de neuf chiffres, avec au plus un blanc simple entre
  « FR », la clé et chaque groupe de trois chiffres : type `siren`, jeton
  `[SIREN_n]`. Clé vérifiée par `(12 + 3 × (SIREN mod 97)) mod 97` : clé juste
  (deux chiffres) → confiance 0,9, sans libellé exigé ; clé fausse ou à lettre →
  seulement si « TVA » (mot entier) ou « intracommunautaire » est à moins de 40
  caractères, confiance 0,3 et avertissement « à vérifier ». Mesure
  (`Ecluse.redact`, corpus étendu, graine 42) : 29 / 35 en clair et 6 / 35 masqués
  en partie comme RPPS → **35 / 35 en entier**, type `siren` ; RPPS du corpus : 117 / 117
  inchangés, les 6 faux positifs RPPS du moteur seul disparaissent (95,1 % → 100 %).
  **Limites** : une TVA à clé fausse sans libellé reste en clair ; « FR » + onze
  chiffres de clé juste qui n'est pas une TVA (1 chance sur 97) est masqué à tort ;
  les autres pays de l'Union (« DE », « BE »…) ne sont pas traités ; la TVA est
  annotée `siren` au banc depuis le 23 novembre (P2-261), en entier (« FR », la
  clé et le SIREN) : ses 35 masquages du corpus étendu ne comptent plus comme
  faux positifs. Le témoin flou ne porte plus la ligne « TVA … » (216 masquages
  par corpus témoin avec celle du SIRET, 0 depuis P2-261).
- **INS** (Identité Nationale de Santé) : `InsDetector` masque les marqueurs
  textuels et OID (« Matricule INS »), pas le numéro qui suit ; celui-ci n'est
  masqué que si c'est un NIR à clé valide.
- Les identifiants professionnels autres que RPPS et FINESS, et les
  identifiants d'établissement autres que FINESS.
- **ADELI à clé fausse derrière son libellé : avertissement (P2-204).** Un
  ADELI de neuf chiffres à clé Luhn fausse, masqué à confiance 0,6 (inchangée,
  voir ADELI plus haut), porte désormais l'avertissement « identifiant à clé
  invalide masqué : à vérifier », comme NIR, IBAN et RPPS. Le message ne
  contient jamais la valeur. Un numéro corse (« 2A… ») n'a pas de règle de clé
  établie : il n'est pas jugé faux et n'avertit pas. Chemin `Ecluse.redact` :
  ADELI × clé fausse 0 → 50 / 300 avec avertissement, négatifs 0 / 1 200.
- **IBAN de forme française à clé fausse, sans libellé : masqué en entier (P2-252).**
  Un IBAN mal recopié reste celui de quelqu'un (décision du 22 novembre).
  `IbanCleInvalideDetector` (et l'option `cleInvalideFr` d'`IbanDetector`, activée
  dans `Ecluse.defaultDetectors`) masque en entier toute suite `FR` + 2 chiffres +
  23 caractères alphanumériques (mêmes séparateurs et blancs que le détecteur
  strict) dont la clé ISO 7064 est fausse : type `iban`, **confiance 0,3**,
  avertissement « identifiant à clé invalide masqué : à vérifier » (sans valeur).
  Avant, une fenêtre de neuf chiffres Luhn-valide à l'intérieur était masquée
  comme FINESS et le reste du numéro partait en clair. Corpus d'identifiants,
  graine 42, 200 000 documents, 8 362 IBAN « pièges » à clé invalide : **moteur
  seul** (`run_ecluse.dart`) 10 masqués en partie → **0**, tous masqués en entier ;
  **`Ecluse.redact`** 43 masqués en partie (FINESS ou téléphone) et 2 762 laissés
  en clair (blancs insécables ou multiples, hors du champ de P2-188) → **0** et
  **0**. Rappel NIR, RPPS, IBAN et FINESS inchangé (100 %), fuite au caractère
  0 %. Ces IBAN étaient des témoins négatifs du banc, donc comptés comme faux
  positifs (précision IBAN du moteur seul 100 % → 83,3 %) ; depuis le
  22 novembre, le corpus les annote comme données personnelles (`iban`) et la
  précision IBAN est revenue à 100 % (corpus v3 : 826 entités, précision
  totale 95,2 %, les 42 faux positifs restants sont les SIREN). C'est un
  masquage voulu ; il ne vaut que pour une suite de la forme exacte
  d'un IBAN français. Les IBAN d'autres pays à clé fausse ne sont pas traités.
  **Lettre « o » dans la clé (P2-254).** La clé peut porter la lettre « o » ou
  « O » à la place d'un chiffre (confusion zéro / lettre d'OCR ou de frappe :
  « FR8o52… », « FRo6… ») : l'IBAN est masqué en entier à la même confiance 0,3.
  Avant, 4 des 50 IBAN à clé fausse sans libellé du corpus « libellé fort »
  partaient en clair par `Ecluse.redact` (tous avec cette lettre) ; après, 0 / 50
  (même chemin, graine 42). Coût : une suite `FR` + `o` + 24 caractères
  alphanumériques qui n'est pas un IBAN (référence, code article) est masquée à
  tort ; aucun des témoins négatifs du tableau de bord n'en gagne (voir la PR).
  Seule la clé est élargie : les lettres autres que « o » (« FRa4… ») et un « o »
  hors de la clé restent traités comme avant.
- **NIR, IBAN FR ou RPPS à clé fausse, annoncé par un libellé fort (P2-188).**
  `Ecluse.redact` masque quand même, à confiance 0,3, avec l'avertissement
  « identifiant à clé invalide masqué : à vérifier », un NIR précédé de
  « NIR », « N° de sécurité sociale », « numéro de sécurité sociale » ou
  « numéro SS », un IBAN précédé de « IBAN » ou un RPPS précédé de « RPPS »,
  même si la clé de contrôle est fausse (chiffre changé, typo de recopie) —
  déroge à « clé validée ou rien » (`DECISIONS.md`) comme ADELI ci-dessus, et
  pour la même raison : un champ explicitement étiqueté qui fuit est pire
  qu'un sur-masquage. Fonctionne sur le texte d'origine, jamais sur la vue
  de détection : un NIR à clé nommée à part (P2-42, « 2550814168025 clé 38 »)
  et **fausse** reste intact, conformément à P2-42 (« une clé fausse n'est
  jamais acceptée », pour ne pas masquer « Chambre 12 clé 38 »). Un libellé
  sans forme d'identifiant à sa suite (« NIR : non communiqué », « IBAN :
  voir pièce jointe », un montant, une date) n'est jamais masqué. Limite
  assumée : le candidat n'est reconnu qu'avec un séparateur simple (espace,
  point, tiret) entre groupes de chiffres, sans passer par
  `DigitCompaction` — un identifiant aux espaces internes insécables ou
  multiples n'est pas couvert par cette exception (il reste couvert si sa
  clé est valide, par le détecteur strict correspondant).
  **Lecture par OCR (P2-191).** Derrière le même libellé fort, et là
  seulement, sont aussi acceptés : la lettre O ou o pour 0 et l ou I pour 1
  (corps d'un NIR ou d'un RPPS, clé d'un IBAN : « FRO2… » ; le corps d'un IBAN
  admet déjà des lettres, il n'est pas « corrigé »), et **une ligne vide**
  insérée entre deux groupes. Un tel identifiant est masqué **même si sa clé
  est juste après correction** (le détecteur strict ne le voit pas), avec le
  même avertissement « à vérifier ». Les détecteurs stricts de `ecluse_core`
  ne changent pas ; sans libellé fort, « 1 85 05 78 OO6 084 91 » restait en
  clair avant P2-268 (voir « Identifiants lus avec des lettres d'OCR »). De même, un IBAN français à clé fausse **sans libellé** dont la clé
  porte une lettre d'OCR (« FR8o52… ») part en clair : mesuré au corpus
  « libellé fort », 4 sur 50 IBAN à clé fausse sans libellé (les 46 autres
  sont masqués, P2-252) ; correction inscrite (P2-254). **ADELI (P2-199)** : le libellé « ADELI » reçoit les mêmes
  tolérances (neuf chiffres, O/o/l/I, ligne vide) ; un numéro ADELI lu par OCR
  derrière son libellé est masqué à confiance 0,3 avec le même avertissement
  (le numéro corse `2A`/`2B` reste l'affaire d'`AdeliDetector`). Sans le mot
  « ADELI », un nombre de neuf chiffres lu par OCR reste en clair.
  **Pas couvert** : une confusion autre que O/o/l/I (« S » pour 5, « B »
  pour 8, « | » pour 1), plusieurs lignes vides ou une seule fin de ligne
  (sans ligne vide) au milieu, un libellé lui-même mal lu (« lBAN »), un O dans
  le premier chiffre d'un NIR (qui ne peut être que 1 à 8). Un libellé fort
  suivi d'un début d'IBAN tronqué puis d'une ligne vide peut faire avaler les
  lettres de la ligne suivante : sur-masquage, jamais une fuite. Non mesuré sur
  de vrais textes OCR : seul le témoin synthétique de
  `identifiant_cle_invalide_ocr_test.dart` (13 cas positifs, 12 négatifs)
  est chiffré.

### Identifiants lus avec des lettres d'OCR (P2-268)

`Ecluse.redact` relit les lettres d'OCR (« O » ou « o » pour 0, « l » ou « I »
pour 1) d'une suite candidate et la masque en entier, **sans réécrire le texte**,
si elle devient un identifiant valide une fois relue (`IdentifiantOcrDetector`,
confiance 0,3, avertissement « identifiant lu avec des lettres d'OCR masqué : à
vérifier », aperçu « à vérifier »). Ce n'est pas le moteur seul (`ecluse_core`),
dont les détecteurs restent stricts.

- **Clé forte, avec ou sans libellé** : NIR (mod 97) et IBAN français (mod 97).
  Sans libellé, la suite entière doit avoir la longueur de l'identifiant (15
  caractères, ou « FR » + 25) ; le sexe du NIR est 1 ou 2 (1 à 8 derrière un
  libellé). Avec 1 à 8 sans libellé, le témoin durci donnait 1 faux accord sur 450.
- **Clé faible (Luhn seul), derrière un libellé seulement** : RPPS, FINESS, SIREN,
  ADELI. Sans libellé ils restent en clair, par décision : 7 faux accords sur
  450 documents sans identifiant au prototype (5 de neuf chiffres, 2 de onze).
  Les mots-clés sont les seuls libellés explicites ; le mot « code » des nombres
  dictés (P2-267) n'en fait pas partie.
- Séparateurs : un à quatre blancs (espace, tabulation, espaces insécables) ou un
  point, tiret ou barre entre deux groupes. Pas de fin de ligne.

**Mesuré** (graine 42, synthétique, par `Ecluse.redact`, 120 documents par
type et par présentation) : fuite au caractère de 0,0 % pour les cinq types avec
libellé ; sans libellé, NIR 0,0 % depuis P2-275 (3,3 % avant : les 4 documents
non couverts étaient des NIR corses, « 2A »/« 2B » désormais relus, clé calculée
comme `NirDetector`), IBAN 0,0 %, RPPS 98,8 %, FINESS 100 %, SIREN 99,1 %
(inchangés, voulu). **Clé fausse derrière un libellé (P2-275)** : un NIR, un RPPS
ou un IBAN lu avec des lettres d'OCR, dont la clé reste fausse une fois relu, écrit
avec des séparateurs multiples (360 documents synthétiques, graine 42, par
`Ecluse.redact`) : couverts NIR 20 → 120 / 120, RPPS 0 → 120 / 120, IBAN 63 →
120 / 120, avec l'avertissement « identifiant à clé invalide masqué : à vérifier »
(confiance 0,3). FINESS et SIREN gardent « clé juste ou rien » ; ADELI suit la règle
du NIR et du RPPS. Aucun masquage à tort nouveau : témoin d'origine 0 / 400, témoin
durci 14 / 450 (les mêmes 14).

**Pas couvert** : un NIR corse relu derrière un libellé avec une clé fausse n'est
pas mesuré à part (un cas du banc, couvert) ; un libellé derrière lequel l'identifiant
est de longueur fausse après relecture ; toute autre confusion que O/o/l/I ; un identifiant faible
sans libellé ; un IBAN dont une lettre légitime du corps est elle-même un « O »
ou un « I » et dont une autre lettre est mal lue. **Faux accords** : le témoin
durci (450 documents de suites ordinaires denses en O/l/I, dont 24 % de longueur
9, 11 ou 15 et 6 % « FR » + 25 caractères) n'en donne **aucun pour la règle
nouvelle** ; il garde **14 masquages à tort déjà présents sur `main`**, dus à
d'autres détecteurs (IBAN de forme française à clé fausse, P2-252 : 10 ; NIR à
clé fausse avec « o », P2-258 : 1 ; adresse « cinq chiffres + mot » : 2 ; FINESS
à neuf chiffres Luhn-valides : 1). Une suite de 15 caractères ou « FR » + 25 qui
se trouve valide par hasard (≈ 0,5 % et 1 % par suite de cette longueur) sera
masquée à tort ; non mesuré sur de vrais textes OCR ni sur des références réelles.

### Identifiants dictés en toutes lettres (P2-267)

Un identifiant dicté puis transcrit en toutes lettres (« un neuf trois zéro
huit… ») est lu par `Ecluse.redact` seulement (pas par le moteur seul
`ecluse_core`), dans une seconde vue qui ne remplace jamais la première : sur un
texte sans suite de mots-nombres, le résultat est celui d'avant, octet pour
octet. **Couvert** : NIR, RPPS, IBAN FR, FINESS, SIREN et SIRET nommés, dictés
chiffre par chiffre, par paires ou par groupes, avec « double » et « triple »,
« septante », « huitante », « nonante », le zéro dit « o », les traits d'union
perdus, « fr » collé aux chiffres, les lettres d'un compte d'IBAN et la lettre
d'un NIR corse. Mesuré sur le banc synthétique (graine 42, 943 identifiants, cinq
variantes) : fuite au caractère de 97,4 à 98,0 % avant, de 0,0 à 0,1 % après ; au
pire 1,1 % par type (FINESS). Voir `bench/ETAT.md`.

**Ce qui reste hors périmètre**, à ne pas promettre :

- **Lettres épelées hors de ces cas** (« F R » dit lettre à lettre, « effe erre »),
  corrections du locuteur (« non, pardon, … »), erreur de transcription d'un
  chiffre, nombres dits dans une autre langue que le français, vrai audio (la
  qualité du transcripteur n'est pas mesurée : le banc part d'un texte déjà
  transcrit).
- **Pas de mot-nombre isolé** : une suite d'au moins 6 mots-nombres consécutifs (3
  derrière un mot-clé d'identifiant) est nécessaire. Un identifiant dicté en moins
  de mots, ou coupé par un mot ordinaire (« un deux trois euh quatre cinq… »), n'est
  pas lu.
- **Validation par la clé** : une lecture n'est retenue que si un détecteur la
  valide (clé mod 97 du NIR et de l'IBAN, Luhn, longueur). Un chiffre mal dicté
  donne une clé fausse : le NIR et l'IBAN à clé fausse restent masqués par leurs
  règles propres (P2-188, P2-252, P2-258), mais un RPPS, un FINESS ou un SIREN
  mal dicté n'est pas masqué.
- **Mot-clé obligatoire pour RPPS, FINESS, SIREN, ADELI et téléphone** (Luhn seul :
  un faux accord sur dix) : « rpps », « praticien », « finess », « siren »,
  « siret », « adeli », « téléphone », « structure », « établissement »… dans
  les 60 caractères qui précèdent (« code » n'en fait plus partie depuis P2-273 : 3 masquages
  à tort sur 630 phrases ordinaires du témoin durci → 0, mesuré par `Ecluse.redact` ; un code
  d'accès dit de neuf chiffres ou plus reste signalé « non reconnu », 46 → 49 signalements).
  Sans mot-clé, un RPPS dicté n'est pas masqué.
- **Au plus 64 lectures** sont essayées par suite (la plus composée d'abord) ; une
  suite très ambiguë peut dépasser la borne.
- **Signalement** : une suite d'au moins 9 mots-nombres qu'aucune lecture ne valide
  est signalée « nombre dicté non reconnu, relire avant envoi » (positions et compte,
  jamais de valeur) ; ce n'est pas un masquage. Une phrase ordinaire dense en
  nombres (dates, montants) peut déclencher ce signalement : voir le témoin.
- **Mot voisin qui coupe le signalement (P2-282)** : si « code », « digicode »,
  « mot de passe », « mdp » ou « pin » figure dans les 100 caractères qui précèdent
  la suite, sans libellé d'identifiant (nir, sécu, iban, rib, compte, banque,
  virement, rpps, finess, siren, adeli, identifiant…) dans la même fenêtre, la suite
  n'est pas signalée « non reconnu ». Mesuré par `Ecluse.redact` : signalements à tort
  sur le témoin durci 49 → 0 (graine 42, critère choisi après lecture de ce témoin) et
  41 → 0 sur un témoin neuf (graine 43) ; 0 → 0 sur le témoin d'origine (300).
  **Avertissement distinct (P2-299, décision du 26 novembre, point 3)** : la suite
  n'est pas masquée pour autant, et sans mot de plus elle partait sans aucun
  message (P2-292 : 6 214 identifiants dictés abîmés sur 6 580, soit 94,4 %, sans
  libellé, à au plus 100 caractères d'un mot voisin). Elle reçoit maintenant
  « suite de nombres dictés précédée d'un mot comme « code » : non masquée, à
  vérifier » (positions et compte, jamais la valeur), moins pressant que le
  signalement ordinaire. Sur les témoins de phrases ordinaires, cela fait 49
  (durci), 41 (neuf) et 0 (d'origine) avertissements distincts : ce sont les phrases
  que le signalement ordinaire signalait à tort avant P2-282 ; le prix de la garde
  est donc un message moins pressant sur des codes d'accès, au lieu de rien sur des
  identifiants. **Réserve** : un code d'accès dicté chiffre par chiffre reçoit ce
  message sans être une donnée personnelle ; le texte ne dit pas lequel des deux
  c'est.
- **FINESS dicté derrière un nom d'établissement (P2-271)** : le nom d'établissement
  qui chevauche un identifiant dicté validé est rogné autour de lui, les deux
  étendues sont gardées (avant P2-271, 6 à 9 FINESS sur 129 restaient en partie en
  clair, jusqu'à 17 caractères). Mesuré par `Ecluse.redact` : 129 / 129 couverts en
  entier sur chacune des cinq variantes dictées. Seul le nom d'établissement est
  rogné ; un autre type qui chevaucherait un identifiant dicté (adresse, nom)
  garde la règle du plus long.
- **Coût** : linéaire ; pour des centaines de milliers de caractères de mots-nombres
  sans identifiant, compter quelques secondes (la suite est lue par fenêtres de 240
  mots et un budget de lectures borné).

#### Âge en lettres (décision du 26 novembre)

Un âge dit ou écrit en toutes lettres (« quarante-cinq ans ») n'est ni masqué ni
signalé : il est hors lot depuis P2-155. Un âge seul n'identifie pas une
personne ; il compte dans un faisceau d'indices, que mesure le rapport de
ré-identification (§ 7), pas la détection.

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

**Pathologies : signalées, pas évaluées (P2-125 à P2-127).**
`extrairePathologies` repère les mentions de pathologie (table maison
validée, P2-110, et Orphanet), leur rattachement à une personne et leur négation.
Depuis P2-127, le rapport de risque **liste** les pathologies rattachées
(`RiskReport.pathologies`, et une ligne dans `limites`), mais elles **ne
comptent pas dans l'estimation** (aucune prévalence ne permet de chiffrer F)
et **restent en clair**, sauf les maladies rares depuis P2-143 (ci-dessous).
Depuis P2-135, le rapport
propose des généralisations (catégorie, puis « maladie rare » ou « maladie
chronique ») que l'application applique **sur demande**
(`appliquerGeneralisationsPathologie`), sans F chiffré ; les formes
adjectivales (« diabétique ») n'en reçoivent pas. Les maladies rares
ne sont repérées que si l'appelant a chargé `reference.rareDiseases`.

**Maladies rares masquées (P2-143).** Avec `Ecluse.redact(…, maladiesRares:
catalogue)` (catalogue **chargé**, sinon refus), une maladie rare non niée est masquée si
elle est rattachée à une personne (« atteinte de »), ou si le texte nomme
quelqu'un (« Mme Verdier. Diagnostic : maladie de Wilson »). Est rare : une mention d'Orphanet ; une mention de la
table maison qu'Orphanet connaît aussi (mucoviscidose, drépanocytose,
phénylcétonurie, maladie de Gaucher), sauf tuberculose et bilharziose ; une
mention de la table suivie d'un éponyme (« myopathie de Duchenne »). Mesure
(`run_maladies_rares_bench.dart`) : 51 sur 51 mentions rares du corpus P2-112
masquées (0 avant), aucune pathologie fréquente ni aucun mot du témoin
masqué. Sur 300 noms Orphanet tirés au hasard (graine 42, nom préféré tel
qu'écrit), 276 masqués en phrase rattachée ou qui nomme une personne, 0 en
phrase niée ou générale sans personne. Les 24 manqués sont des intitulés
longs (plus de mots que la fenêtre de repérage) ou à formule
(« 46,XY », « del(16) »). Les mentions de mucoviscidose et de drépanocytose
du corpus, annotées comme pathologies de la table maison, sont désormais
masquées : c'est voulu (maladies rares au sens d'Orphanet).
**Ce qui reste en clair** : une maladie rare non rattachée dans un texte où
aucun nom n'est détecté, un nom absent du catalogue ou écrit autrement, et
toute maladie rare quand l'application ne passe pas le catalogue. Le masquage retire aussi la mention du rapport de risque, qui ne
lit que le texte masqué.

**Lieux à tort et professions manquées, corrigés (P2-175).** Un patronyme
homonyme d'une commune de la référence publique (ex. « Chevrier »,
Haute-Savoie) n'est plus lu comme un second lieu quand il suit une civilité,
un titre ou un métier (sauf s'il suit un nom commun de lieu comme
« commune » ou « village »). Les abréviations « pneumo » et « gynéco » et les
graphies sans accent (« pediatre », « generaliste »...) sont désormais lues
comme une profession. Mesure (`ecluse_reid` seul, corpus QI) : précision
lieu 88,2 % → 100 % (réaliste) et 92,3 % → 100 % (adversarial) ; rappel
profession 96,2 % → 100 % (adversarial). **Reste possible** : un homonyme non
couvert par les motifs ajoutés (un nom commun de métier ou une civilité
absents des tables `_civiliteAvant` / `_nomCommunAvant`) resterait lu comme
un lieu ; aucun cas de ce type n'a été trouvé sur les corpus mesurés.

**Mots courants lus comme une commune : liste d'exclusion (P2-302, décision du
26 novembre, point 6).** La référence publique porte pour communes des mots
courants (« Son », « Aucun », « Salles », « La Réunion », « ARS »…). Lus comme un
lieu, ils fabriquaient un quasi-identifiant fantôme, et **un seul mot courant en
tête de phrase suffisait à faire passer un rapport de `evalue` à `nonEvaluable`**
(`agent/specs/P2-287.md` § 5). `motsCourantsSansLieu` (`ecluse_reid`, 21 mots,
extensible) les écarte, **sauf derrière un locatif écrit en minuscules** (« né à La
Réunion », « habite à Fontaine »). Mesuré par `Ecluse.redact` avec référence, graine
42 : documents du corpus sans personne (60 000) portant un lieu qui est un mot courant
17 333 → 0 ; lieux de mots courants écartés 18 650 sur 18 653 (les 3 restants sont
« Chevrier », volontairement hors liste) ; 0 lieu perdu sur les corpus de
quasi-identifiants (320 et 396 lieux lus avant et après) ; sonde isolée de 112 mots,
15 lus comme un lieu → 0 ; sonde combinée : les 7 mots qui faisaient perdre le rapport le
laissent évalué (bande moyen, F = 31,6, comme sans la phrase). **La liste ne couvre que
ce qu'elle contient** : elle est écrite d'après les mots observés dans les corpus
synthétiques du dépôt et la sonde de 112 mots, donc le « 0 perdu » et le « 100 % écartés »
mesurent ce qu'elle couvre, pas ce qu'elle manque ; tout autre mot courant homonyme d'une
commune reste lu comme un lieu. **Coût assumé** : un vrai lieu de la liste écrit sans
locatif en minuscules (« Domicile : Fontaine », « Mont (25) », un titre « Résidence De
Salles ») n'est plus lu ; le rapport de risque l'ignore (fausse rassurance possible, du côté
d'un F plus grand), le masquage du texte n'est pas concerné. « Plan » seul est aussi dans
la liste (sans lui, exclure « Le Plan » laissait « Plan »).

**QI par `Ecluse.redact` : patronyme en clair derrière un métier sans
civilité (P2-175, non corrigé).** La ligne « QI par `Ecluse.redact` » du
tableau de bord (`bench/score_qi_redact.py`) mesure, sur le texte que
`Ecluse.redact` laisse réellement partir (pas `ecluse_reid` seul), si le
patronyme de la personne reste lisible. Un patronyme qui suit un métier
**hors périmètre** d'`ecluse_reid` (infirmière, kinésithérapeute,
orthophoniste, aide-soignante, ergothérapeute, diététicienne) sans civilité
(« L'infirmière Chevrier », « Le kinésithérapeute Marchand ») n'est pas
masqué : `NameDetector` (`ecluse_redact`) ne déclenche que sur une civilité
(M., Mme, Dr...) ou un titre professionnel d'un ensemble fermé, jamais sur un
nom de métier quelconque. Mesuré sur le corpus QI adversarial : 29 documents
sur 400 (0 sur 400 en réaliste, où ce tour de phrase n'apparaît pas). Non
corrigé ici (hors périmètre de ce volet, la correction porterait sur
`NameDetector`, pas sur `ecluse_reid`) ; à reprendre dans une tâche dédiée si
le mainteneur le juge prioritaire.

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

**Option `prenomsInsee` (P2-149), désactivée par défaut.** Avec les effectifs
de l'INSEE chargés par l'appelant, un prénom du fichier de l'INSEE (au moins
20 naissances depuis 1900) absent de la liste écrite à la main, suivi d'un
patronyme en casse de titre ou en capitales, est masqué : « Souleymane
Aubry », « Łukasz Kowalski ». Limites : casse ordinaire seulement (en
minuscules, ces noms partent encore en clair) ; jamais un prénom seul ni
l'ordre « Nom Prénom » ; sur-masquage possible d'un mot courant qui est aussi
un vrai prénom, suivi d'un mot capitalisé. « France Travail » et « Ange
Gardien » sont exclus comme paires (P2-150) : « France Dupuis » reste
masquée. Une autre paire de ce genre serait masquée à tort. Sans l'option, rien ne change : l'application qui veut cette
protection doit charger `EcluseReference.firstNameFrequencies` et la passer.
Mesures : `agent/specs/P2-148.md` § 6.

Le détecteur d'établissement peut, lui, absorber un mot capitalisé isolé
qui suit immédiatement un nom d'établissement, sans ponctuation ni mot
minuscule pour l'arrêter (« Hôpital Saint-Louis Réunion » où « Réunion »
introduit une phrase). C'est du sur-masquage, jamais une fuite : le nom de
l'établissement, lui, est bien protégé. Distinguer un mot appartenant au
nom d'un mot qui le suit relève du NER de la phase 2.

**Un mot de nom d'établissement commence par une majuscule (P2-289).** La classe
de caractères du détecteur (`[A-ZÀ-Ÿ]`) contenait les minuscules accentuées, « à »
compris : « CHU à Lille » était masqué en entier. Corrigé (`[A-ZÀ-ÖØ-ÞŒ]`, comme
dans `coupures_de_nom.dart`). Mesuré par `Ecluse.redact`, graine 42 : sur
200 000 phrases sans personne, documents avec un établissement masqué 7 965 → 2 063
(« sigle + à + ville » 5 902 → 0) ; corpus flou réaliste, bornes exactes
317 → 400 / 400 ; adversarial 114 / 114 inchangé. Le « Ÿ » capital
(U+0178) n'est plus un début de mot.

**« Type + mot générique » : liste fermée (P2-301, décision du 26 novembre, point 5).**
Un type d'établissement écrit en toutes lettres (« Résidence », « Foyer »,
« Centre »…) suivi *seulement* de mots d'une liste fermée n'est plus masqué : Autonomie,
D'accueil, Médicalisé, Médicalisée, Services, Social, Agricole
(`EtablissementDetector.motsGeneriques`). Mesuré par `Ecluse.redact`, graine 42 :
200 000 phrases sans personne, documents avec un établissement masqué 2 063 → 0 ;
témoin de 480 documents 9 → 0 ; flou réaliste et adversarial en 7 présentations,
0 établissement annoté perdu (3 305 bornes exactes sur 3 595 avant et après).
**La liste ne connaît que ce qu'elle contient** : un établissement réellement nommé
« Résidence Autonomie », « Centre Social » ou « Lycée Agricole » ne serait pas masqué,
et c'est une fuite possible du nom de l'établissement (les corpus synthétiques n'en
contiennent aucun : le coût réel est inconnu). Ne sont pas concernés : un sigle (« CH
Services » reste masqué), un nom entre guillemets, un nom qui contient un mot hors liste
(« Résidence Autonomie Horizon » est masqué en entier). Des mots courants hors liste
(« Résidence Seniors », « Centre Médical »…) restent masqués : la liste est écrite
d'après le corpus et quelques ajouts du mainteneur, pas d'après un annuaire. Le retrait
est silencieux (pas d'avertissement) : à rapprocher de l'inventaire P2-303.

#### IBAN en paires : masquages à tort assumés (décision du 26 novembre)

Une référence qui a la forme d'un IBAN français écrit en paires (« FR + clé +
onze paires de chiffres »), même à clé fausse, est masquée comme `iban` :
13 documents sur 5 000 du témoin élargi de P2-279 (0,26 %), sur des références de
commande, de lot ou d'étiquette. C'est voulu : les gardes mesurées (P2-293)
feraient perdre jusqu'à 37,5 % des vrais IBAN écrits en paires sans mot bancaire.
Un masquage à tort ne fait rien fuiter ; il gêne la lecture de la référence.

### 5.2 Entités coupées par la mise en forme

#### 5.2.1 Coupures de ligne : adresses et établissements

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
- Toute autre entité coupée par une mise en forme multiligne reste soumise
  à la règle générale : aucun span ne traverse la ligne. Les exceptions sont
  l'adresse (forme voie → CP + commune, ci-dessus), l'identifiant coupé entre
  deux groupes (P2-38, plus bas) et, depuis P2-173, le nom d'établissement ou
  de commune coupé à un endroit où il continue visiblement (ci-dessous).

**Nom d'établissement ou de commune coupé par une fin de ligne (P2-173).**
Chemin : `Ecluse.redact`. Sur le corpus flou réaliste recoupé
(`bench/ETAT.md`, « Mise en page »), 44 établissements coupés à 90 colonnes
restaient en clair (37 en entier : « Centre⏎Hospitalier de Dole », « CH⏎de
Vesoul », « EHPAD⏎Les Tilleuls » ; 7 en partie : « IME La⏎Source »), soit
9,2 % des caractères d'établissement ; à 60 colonnes, 13 adresses laissaient
le dernier mot de la commune (« 70180 DAMPIERRE SUR⏎SALON », 1,3 %) et
4 établissements leur fin. La fin de ligne est maintenant remplacée par une
espace **dans la vue de détection seulement** (le texte n'est pas réécrit,
`ecluse_core` n'est pas touché), dans quatre cas :

1. la ligne finit par un mot de liaison derrière un mot-clé d'établissement
   (« CH de⏎Vesoul », « IME La⏎Source ») ou derrière un code postal et le
   début d'une commune (« DAMPIERRE SUR⏎SALON », « 25000 SAINT⏎VIT ») ;
2. la ligne suivante commence par un mot de liaison en minuscules suivi d'un
   nom propre (« CH⏎de Vesoul ») ;
3. la ligne suivante commence par un nom propre qui n'ouvre pas une phrase
   (« EHPAD⏎Les Tilleuls », « Centre⏎Hospitalier de Dole ») ;
4. la coupure tombe dans un mot-clé de plusieurs mots (« centre⏎hospitalier »,
   « Maison de⏎retraite »).

Jamais à travers une ligne vide ; au plus deux fins de ligne de suite. Après :
établissements à 90 colonnes 9,2 % → **0 %**, adresses à 60 colonnes 1,3 % →
**0 %**, les 44 et les 4 établissements coupés couverts, témoins recoupés à
0 prédiction, prose de 78 fichiers `.md` du dépôt (13 791 fins de ligne) :
détections identiques avant et après. **Ce qui reste :**

- Le cas 3 est ambigu par nature. Ne sont pas recollés : un pronom, un
  déterminant, une conjonction, une civilité, une étiquette (« Contact : »),
  un article suivi d'une minuscule (« EHPAD⏎Les résidents déjeunent »). Un nom
  propre qui ouvrait une phrase sans ponctuation avant (« …à l'EHPAD⏎Bellevue
  est fermée ») ou un article suivi d'une majuscule (« EHPAD⏎Les Tilleuls sont
  en fleurs ») **est** recollé : sur-masquage, jamais une fuite.
- Une commune coupée ailleurs que derrière un mot de liaison (« 42260 SAINT
  GERMAIN⏎LAVAL ») n'est pas recollée : rien ne distingue « LAVAL » du début
  de la ligne suivante. Le dernier mot reste en clair. Non mesuré : le corpus
  ne contient pas cette forme.
- Un nom d'établissement sur plus de trois lignes, ou coupé deux fois par un
  article seul sur sa ligne (« EHPAD⏎Les⏎Tilleuls »), n'est pas recollé.
- Texte tout en minuscules ou tout en capitales : la règle lit les mots-clés
  dans leur casse d'origine, comme `EtablissementDetector` ; les détecteurs de
  casse (P2-120, P2-122) ne recollent pas. Non mesuré.
- **Un refus de plus à 60 colonnes** (2 → 3 documents sur 400). Une fois
  « PORT SUR⏎SAONE » recollé, la ligne « demeurant …, 70160 PORT SUR SAONE, »
  retrouve la forme qu'elle a sans coupure, et le détecteur de tableaux la lit,
  avec ses voisines, comme un tableau à colonnes inégales : refus explicite,
  rien n'est envoyé. C'est le défaut déjà connu des faux tableaux (les deux
  autres refus ont la même cause, sans ligne recollée), pas une règle
  nouvelle. Des 13 adresses, 12 sont maintenant couvertes et 1 est dans ce
  document refusé.
- **Coût des faux tableaux selon la largeur** (P2-296, `Ecluse.redact`, flou
  réaliste, 400 documents, graine 42) : 0 document refusé à partir de 70
  colonnes, 3 à 60, 14 à 15 à 50-55. Le refus fait ce qu'il doit : rien ne part,
  mais le document n'est pas traité. Les trois règles plus souples mesurées
  enverraient de vrais tableaux de noms à tort (jusqu'à 80 documents de la
  sonde) : aucune n'est retenue (règle 4 de `CLAUDE.md`). Le message d'exception
  parle de « tableau de noms » même quand la colonne en cause est une date de
  naissance.
- **Établissements en capitales masqués comme une personne** (P2-297) : en
  capitales, 69 établissements sur 400 (flou réaliste) et 98 sur 114
  (adversarial) sont masqués par un jeton de personne (`[NOM_k]`) au lieu de
  `[ETABLISSEMENT_k]`, à cause de l'article élidé en tête (« L'HÔPITAL… »). Rien
  ne part en clair, la restauration est exacte et le rapport de risque n'en
  dépend pas ; seul le type du jeton est faux.

Dans tous les autres cas, le coût reste symétrique : entre « fusionner deux
lignes à tort » et « rater une entité coupée par la mise en forme », le
second risque est jugé préférable — mais les deux méritent une vigilance
humaine sur des documents à la mise en page inhabituelle.

#### 5.2.2 Noms sans civilité et titres

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

#### 5.2.3 Caractères invisibles et accents décomposés

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

#### 5.2.4 Casse : minuscules, capitales, casse de phrase

**Casse de phrase (P2-138).** Un texte dont les seules majuscules ouvrent
les phrases (« Rdv avec m. julien chevrier ») est traité comme un texte sans
majuscule : fuite globale du corpus réaliste 64,2 % → 0,6 %, adversarial
82,7 % → 14,4 %, 0 faux positif. Une majuscule après « M. » ou une initiale
compte comme celle d'un nom propre. L'avertissement n'est émis que si un nom,
une adresse ou un établissement a été trouvé ; un patronyme seul (« rdv avec
chevrier ») passe donc sans avertissement. Depuis P2-139, l'ordre « nom prénom » (« suivi par perrot olivier »),
l'initiale (« présent : t. lefèvre ») et les particules (« monsieur jean de la
fontaine ») sont couverts après un champ ou un mot qui introduit une personne :
adversarial en minuscules, fuite des noms 27 % → 5,9 %. Un prénom absent du
gazetteer n'est pas reconnu.

**Initiale et patronyme après un libellé (P2-147).** En casse ordinaire,
« Présent : T. Lefèvre » ou « Présents : S. Verdier, K. Perrot » sont masqués
quand le libellé annonce une personne (présent, excusé, absent, rédacteur,
signé, auteur, référent, destinataire, participant, validé par…). Un autre
libellé (« Annexe : A. Introduction ») ne déclenche rien. Corpus adversarial :
fuite des noms 18,3 % → 13,9 %, fuite globale 9,3 % → 7,2 % ; autres corpus et
témoins inchangés. Le témoin ne contient pas de piège de cette forme : les
faux positifs ne sont vérifiés que par les tests unitaires.
**Reste en clair** (mesure P2-89) : un prénom absent de la liste suivi d'un
patronyme (« Contacter Yaroslav Delaunay »), 572 caractères sur
l'adversarial.

**Patronyme repris seul et casse mixte (P2-144, P2-145).** Un patronyme établi
par une mention sûre (« mme aurélie hautecoeur », « julien chevrier ») est
ensuite reconnu seul (« compte rendu : hautecoeur a confirmé »), dans le même
texte et dans les documents suivants d'un dossier : sur les dossiers en
minuscules, noms non détectés 116 → 4 (réaliste), 47 → 10 (adversarial), en
capitales 104 → 28 ; 0 faux positif sur les témoins. Un mot courant égal à un
patronyme établi est masqué (même sur-masquage que § 5.4). Depuis P2-145, la
**civilité de genre reste en clair** en minuscules et en capitales, comme en
casse ordinaire (point 4 de l'essentiel) : la fuite des noms mesurée passe
donc de 2,2 % à 30 % sur le réaliste en minuscules, **uniquement par la
civilité** (hors civilité : 185 caractères avant comme après,
`leak_hors_civilite.py`). Effet recherché : une même personne citée en casses
différentes dans un dossier (« M. Antoine Lacombe », puis « m. antoine
lacombe ») reçoit le même jeton, et une civilité n'est plus ajoutée à la
restauration. **Restauration en casse mixte** : un jeton ne garde qu'une
graphie par dossier ; sur le corpus réaliste à casse mixte (une casse par
document), 95 documents sur 397 sont restaurés avec une autre casse que
l'original (vérifié : la casse seule diffère).

**Texte sans majuscules (P2-117).** Sur un texte mis en minuscules, ponctuation
intacte, la fuite au caractère est de 100 % pour les noms, les adresses et les
établissements (corpus flou réaliste, 400 documents), contre 27,7 % et 0 % sur
le texte d'origine : ces détecteurs reposent sur la majuscule initiale. Cela
vaut pour une dictée transcrite comme pour un message tapé tout en minuscules.
Depuis P2-118, `Ecluse.redact` le **signale** dans `warnings` (texte d'au
moins trois mots et sans aucune majuscule ; message ajusté par P2-133 : la
détection y est « moins sûre », plus « absente »). Depuis P2-119, un détecteur
dédié (`NomMinusculesDetector`, actif seulement sans aucune majuscule)
rattrape les **noms** : civilité suivie d'un nom, ou prénom connu suivi d'un
mot (P2-124 : pas si ce mot est un adjectif et le prénom un mot courant,
« rose pâle » ; 280 → 0 faux positif sur un témoin de faux amis écrit par le
projet). Fuite des noms sur le corpus réaliste en minuscules : 100 % → 2,2 % ;
adversarial : 100 % → 27 % ; 0 faux positif sur le témoin en minuscules.
Depuis P2-120, adresses et établissements y sont rattrapés aussi
(`MinusculesRecapitaliseDetector` : les détecteurs habituels lisent un texte
d'ombre recapitalisé, de même longueur). Fuite sur le corpus réaliste en
minuscules : adresses 100 % → 0 %, établissements 87 % → 0 % ; adversarial :
94 % → 26,6 % et 47 % → 0 % ; 0 faux positif sur le témoin en minuscules et
sans ponctuation. Pour les adresses, seule la commune après un code postal
est recapitalisée, et le nom de voie seulement après un indice d'adresse
(« située », « demeurant », « domicilié », « adresse … : », P2-131 ;
adversarial 26,6 % → 1,9 %) : **une voie sans code postal ni indice
(« rdv au 3 route de vellexon ») reste non détectée** en minuscules, pour ne
pas masquer « 3 chemin de fer » ou « 12 place disponible ». Les mots outils, unités et noms de comptage
(« 70000 euros », « 21000 dossiers ») ne sont pas recapitalisés ; un autre
nom commun après un code postal peut être pris pour une commune
(sur-masquage). Un patronyme seul sans civilité ni prénom connu n'est pas
détecté, sauf s'il a été établi plus haut ou dans le dossier (P2-144).
**Lexique de formes verbales fourni par l'application (P2-251, option
`formesVerbales`, désactivée par défaut).** Avec le fichier de
`packages/ecluse_lexique` (511 245 formes de Morphalou 3.1), un prénom suivi
d'une forme verbale est masqué seul : sur la sonde de P2-240 (`Ecluse.redact`),
verbes masqués 810 → 0 sur 1 280 phrases (reserve 180 → 0 sur 200, reserve2 630
→ 0 sur 680), 0 prénom en clair. **Fuite connue et assumée seulement si
l'application active l'option** : un patronyme homographe d'une forme du
lexique (« laurent », « roche », « martinez »…) passe **en clair** derrière un
prénom dans un texte sans majuscule ou en casse de phrase (« rdv avec marc
laurent ») ; 5 583 patronymes du fichier de l'INSEE (4,5 % des naissances) sont
dans ce cas. Aucun nom annoté des 76 corpus du dépôt n'est perdu (listes de
patronymes courtes) : ce zéro ne dit rien des noms réels. Retirer du lexique les formes qui sont
des patronymes fréquents réduit la fuite au prix de verbes de nouveau masqués
(voir la PR de P2-251 pour le chiffrage par seuil).
**Homonymes écartés par les listes d'exclusion : signalés (P2-310, 27 novembre
2026).** Quatre listes retirent un mot de ce qui serait masqué comme nom :
`verbes_conjugues`, `statuts`, `mots_voisins_neutres` et `mots_de_role` (inventaire
`agent/specs/P2-308.md`). Un patronyme qui s'écrit comme un de leurs mots (« Madame
Marié », « le dossier de Avril », « le dossier de Maître », « sophie porte a
rappelé ») **n'est pas masqué** : choix assumé (aucun verbe masqué, P2-240 ; « dans
le doute, masquer » ne vaut pas pour un mot courant). `Ecluse.redact` le signale
désormais « mot pris pour un nom commun derrière un prénom, une civilité ou « le
dossier de », non masqué : à vérifier » (compte et positions, jamais la valeur), sauf
si une entité couvre le mot. Aucun masquage ne change. Sonde de P2-308 (chemin
`Ecluse.redact`) : verbes 0 → 170 / 170, statuts 0 → 29 / 29, jours et mois 0 →
30 / 30, mots de rôle 0 → 30 / 30 patronymes en clair signalés ; les autres listes
restent silencieuses (hors fiche). **Coût** : dans un texte **entièrement en
minuscules** (dictée, transcription), chaque « sophie rappelle » légitime est aussi
signalé quand il est aussi un patronyme INSEE (un verbe, pas un nom) : sur la sonde
de P2-240 mise en minuscules, 240 documents sur 1 280 ; en casse ordinaire, 0 sur
1 280. Seuls les mots qui sont aussi un patronyme (≥ 30 naissances, 236 mots, fichier
généré `homonymes_patronymes.dart`) sont signalés : « M. Bénéficiaire du RSA » ne
l'est pas. Témoins propres rejoués :
0 document averti sur 43 680 (mots neutres 31 200, commune neutre 400, neutre
cedex 400, faux amis 400, réaliste 400, adversarial 400, v3 1 000, commune suivie
480, durci élargi 5 000, mots-nombres durci élargi 5 600, libellé fort 3 000). Ces
corpus ne contiennent aucune de ces tournures : le coût sur un texte naturel n'est
pas mesuré.
**Homonymes écartés, texte sans majuscule (P2-315, 27 novembre 2026).** Les chemins
« civilité » et « le dossier de » de l'avertissement ci-dessus exigeaient une
majuscule : dans un texte tout en minuscules (dictée, transcription, courriel
pressé), 243 des 607 homonymes en clair de la sonde de P2-308 n'étaient pas
signalés (« le dossier de avril », « madame fait est venue »). Ils le sont
désormais : **607 / 607** (364 avant) ; en casse ordinaire, 77 / 77, inchangé.
Chemin mesuré : `Ecluse.redact`. Aucun masquage ne change. Un mot suivi
immédiatement d'une entité masquée n'est pas signalé (« le dossier de monsieur
pelletan » : « monsieur » est un titre, le nom est masqué). **Coût** : un nom
commun qui est aussi un verbe conjugué, un statut, un jour, un mois ou un mot de
rôle **et** un patronyme INSEE est signalé derrière « dossier de », « à la demande
de » ou « entretien avec » : « le dossier de contrôle » (8 documents sur 400 du
témoin `tournures_sans_nom`, 2,0 %, tous « contrôle » ; 0 avant). Sur 100 992
documents des corpus du dépôt, 0 autre avertissement nouveau. **Limite qui
demeure** : une civilité **capitalisée** devant un mot en minuscules (« Madame fait
un malaise ») n'est pas signalée ; ce chemin n'est pas celui du texte sans
majuscule et n'a pas été mesuré.
**Homonymes écartés : les treize listes signalées (P2-318, reprise de P2-316,
27 novembre 2026).** Les neuf autres listes d'exclusion des noms (`non_noms`,
`mots_structure`, `sigles_organismes`, `mots_contexte_non_noms`,
`articles_capitalises`, `sigles_exclus`, `prenoms_insee_exclus`, `mots_neutres`,
`outils_initiale`) laissaient aussi en clair, sans un mot, un patronyme qui s'écrit
comme un de leurs mots (« le dossier de Sans », « Madame Ma »). Elles sont signalées
comme les quatre premières : **aucune liste d'exclusion des noms n'est plus
silencieuse**. Sonde de P2-308, chemin `Ecluse.redact` : neuf listes 2 → **148 / 148**
patronymes en clair signalés, quatre listes 259 / 259 (inchangé) ; en minuscules
607 / 607, en casse ordinaire 77 / 77 (inchangés). Aucun masquage ne change. Trois
règles évitent le bruit : un faux ami de prénom écrit en minuscules (« iris sans
particularité », liste de `NomMinusculesDetector`) n'est pas lu comme un prénom ;
le mot qui suit un nom complet déjà masqué (« rappel chloé martin est ») n'est pas
signalé, mais « sophie porte » (seul « sophie » masqué) l'est ; un article suivi d'un
mot à majuscule (« à la demande de la Préfecture ») n'est pas signalé (règle ajoutée
hors fiche : sans elle, 59 documents sur 400 du témoin `tournures_sans_nom`, 14,75 %,
contre 8 avant). **Coût mesuré** (`bench/mesure_temoins_homonymes.sh`, 74 corpus,
`Ecluse.redact`) : `corpus_flou_fauxamis` 0 / 400 (38 / 400 avec le code de P2-316) ;
`tournures_sans_nom` 8 / 400 (inchangé) ; 0 en casse ordinaire sur les autres témoins
propres ; en texte sans majuscule, en casse mixte ou de phrase, au plus 9 / 400
(2,25 %, `flou_realiste_minuscules`), surtout « est », « pour », « au » derrière un
prénom connu seul (« monsieur gauthier est »). **Limite
qui demeure** : « le dossier de la » suivi d'un mot en minuscules reste signalé, voulu
(« la » peut être un patronyme).
**Prénom + verbe conjugué (P2-240).** « Sophie rappelle. » donnait un seul nom
de deux mots, puis le verbe était retenu comme patronyme et masqué dans toute
la suite d'un dossier (sonde reproductible `bench/generate_corpus_prenom_verbe.py` :
320 verbes masqués sur 400 phrases avec un verbe courant). Exigence du
mainteneur : aucun verbe n'est masqué, le LLM en a besoin. Une **liste fermée**
de formes verbales courantes (`verbes_conjugues.dart`, écrite par le projet) et
les terminaisons « -ait », « -aient », « -erait », « -eraient », « -eront »
écartent le mot qui suit un prénom : seul le prénom est masqué (320 → 0). Deux
limites assumées. **(1) Un verbe absent de la liste reste masqué avec son
prénom** : après l'extension de P2-242 (558 formes), 20 verbes écrits
après la première liste donnent encore 180 phrases sur 200, et 68 verbes
écrits avant la seconde extension 630 sur 680 (« Sophie sollicite. »),
sur-masquage seulement ; la liste ne couvre pas tout et ne généralise presque
pas. **(2) Fuite connue :
un patronyme homographe d'un verbe de la liste passe en clair derrière un
prénom** (« marc porte », « julien marche » : le nom n'est pas masqué ; un
patronyme en « -ait » ou « -aient » aussi). P2-242 étend la fuite : tout verbe ajouté (« marc dispose »,
« julien documente ») et les formes dérivées (pluriel, futur) sont en clair
s'ils sont aussi un patronyme ; mesure ponctuelle (21 novembre, texte en minuscules « rdv avec
marc calme ce matin. », 20 verbes ajoutés par P2-242 pris comme patronymes × 10 prénoms,
chemin `Ecluse.redact`) : **200 patronymes sur 200 en clair** (même chose
pour 20 verbes de P2-240 : 200 sur 200), c'est-à-dire que la fuite est totale
pour tout mot de la liste, par construction ; les terminaisons ajoutées (« -ifie »,
« -ionne », « -isent »…) ont été mesurées contre les noms annotés et les prénoms
INSEE d'effectif au moins 1 000, pas contre de vrais patronymes. Aucun mot de nom annoté des corpus
du dépôt (107 mots de plus de 4 lettres) n'est reconnu comme verbe, et aucune forme de la liste n'est un
prénom du gazetteer : la fuite n'est donc **pas mesurée** sur des patronymes
réels (le dépôt n'a pas de référentiel de patronymes, voir P2-231) ; à lire
comme un risque, pas comme un chiffre. Un texte entièrement en MAJUSCULES n'est
pas concerné ; relire avant envoi. La branche « civilité + prénom + mot » garde
son défaut équivalent (« monsieur marc loyer présente » : le verbe est masqué),
non traité ici. Dates et
téléphones ne sont pas touchés tant que les chiffres restent des chiffres.

**Texte entièrement en MAJUSCULES (P2-121).** Fuite globale doublée par
rapport à la casse ordinaire (corpus flou réaliste : 7,5 % → 14,8 % ;
établissements 0 % → 27,2 %, noms 27,7 % → 35,6 %), et faux positifs
d'adresse sur des montants ou des références (« 70000 EUROS », « 75015 POUR
L'ANTENNE ») : 194 sur le témoin. Depuis P2-122 : `AdresseDetector`
écarte en capitales une commune qui commence par un mot neutre, et les
établissements passent par le texte d'ombre de P2-120 ; fuite globale
14,8 % → 9,7 % (réaliste), établissements 27,2 % → 0 %, **0 faux positif** sur
le témoin. Depuis P2-123, les noms en capitales passent par `NomMinusculesDetector`
(texte mis en minuscules, même longueur) : 35,6 % → 2,2 % (réaliste),
23,7 % → 18,7 % (adversarial) ; fuite globale réaliste en capitales 9,7 % →
0,6 % ; 0 faux positif sur le témoin. Aucun avertissement n'est émis pour un
texte en capitales.

**Texte en capitales : communes en « LA », « LE », « LES », « L' » (P2-187).**
Une commune qui commence par un déterminant (« 01097 LA BOISSE CEDEX 1 », 2 222
communes du référentiel) était écartée avec les mots neutres : ni la commune,
ni le code postal, ni le CEDEX n'étaient masqués. Balayage des communes en
capitales, chemin `Ecluse.redact` : 8 736 adresses sur 139 500 en partie en
clair → 95 ; cause « déterminant initial » 8 457 → 4. **Coût, dit
franchement : un masquage en trop.** Un nombre à cinq chiffres suivi d'un
déterminant et d'un mot ordinaire non neutre (« VOIR 12345 LE SERVICE DES
ADMISSIONS. ») est masqué comme une adresse, et en capitales la « commune »
avale tous les mots qui suivent (« VOIR [ADRESSE_1]. »). Témoin versionné
(400 phrases, `bench/generate_corpus_determinant.py`) : phrases masquées en
capitales 26 / 200 → 107 / 200, en casse ordinaire 113 / 200 (inchangé).
Décision du mainteneur (15 novembre, `DECISIONS.md`) : un masquage en trop
coûte de la lisibilité, une commune en clair est une fuite. Le coût sur du
texte réel en capitales n'est pas mesuré.

**Texte en capitales sans « CEDEX » : nom exact du référentiel (P2-214).**
Décision du 16 novembre. En texte tout en capitales, la commune qui suit un
code postal est portée jusqu'à la fin de son nom quand ce nom, écrit en entier,
est l'un des 261 noms du référentiel que le motif ne lit pas seul : 251 de
cinq mots ou plus (« DHUYS ET MORIN EN BRIE »), 9 à parenthèse, tiret isolé ou
blancs multiples (« CHATEAU CHINON (VILLE) », « SARROUX - SAINT JULIEN ») et
« LES PLACES » (déterminant puis mot neutre). La table est écrite dans le
paquet (`communes_nom_exact.dart`, générée par
`tools/build_communes_nom_exact.py`) : le détecteur reste pur, rien n'est
chargé. Balayage en capitales sans CEDEX (`Ecluse.redact`, 139 500 adresses) :
**309 → 57** adresses en partie en clair. **Ce qui reste, par décision : la
forme B**, 57 adresses de 15 communes dont le premier mot est un mot neutre
(« SON », « VERS », « SOUS PARSAT », « AUX MARAIS », « JOURS LES BAIGNEUX ») :
sans « CEDEX », ni le nom ni le code postal ne sont masqués, parce que les
reconnaître ferait une adresse de « 08061 SON » ou « 70000 VERS » dans une
phrase (200 phrases sur 200 au témoin construit). **Ce que la règle ne
couvre pas** : une faute de lettre, une lettre omise, une ancienne commune
garde la limite d'avant, fin du nom en clair ; un texte en casse ordinaire n'est
pas concerné par la règle. **Écritures postales lues depuis P2-244** : « ST » et
« STE » sont lus « SAINT » et « SAINTE », et les noms sont comparés **collés**
(sans espace des deux côtés), ce qui absorbe une apostrophe ou un tiret perdu sans
espace (« DAURELLE », « CHATEAUCHINON »). Mesure (`Ecluse.redact`, 1 007 adresses
de 261 communes écrites hors référentiel, tout en capitales, sans CEDEX) :
**392 → 284** adresses en partie en clair ; « ST »/« STE » 66 → 0, apostrophe collée
9 → 0, tiret collé 33 → 0 ; les deux écritures qui restent sont la lettre fautive
(143) et la lettre omise (141), **non traitées** : pas de distance d'édition (option 2
de la spec P2-215, reportée après un témoin de noms longs). Ne sont pas lus non plus :
« ST. » avec un point, « S/ » pour « SUR », « STS », deux fautes dans un même nom. Le
dépliement ne vaut que sur la table réduite (261 noms) : la table complète
changerait le risque de faux positifs, non mesuré ici. La fréquence réelle de ces
écritures dans des adresses réelles n'est pas connue (aucune mesure sur des
adresses réelles : règle 1 de `CLAUDE.md`). **Coût mesuré** : « LES PLACES » est le seul nom de la table qui se
lit aussi comme du texte ; « VIREMENT DE 99307 LES PLACES EFFECTUE LUNDI », en
capitales, est masqué jusqu'à « PLACES » (8 phrases sur 200 au témoin des noms
de forme neutre, 0 avant ; les autres témoins sans adresse sont inchangés).
« LA REUNION », que la simulation de P2-206 donnait comme faux positif (1
phrase sur 200 au témoin déterminant), **n'en est pas un ici** : la table ne
contient que les noms que le motif ne sait pas lire, et « LA REUNION » n'en
fait pas partie ; ce témoin reste à 107 / 200.

**Texte en capitales : communes devant « CEDEX » (P2-201).** Cinq formes de
nom laissaient une commune en partie en clair quand « CEDEX » la suit sur la
même ligne : un mot neutre en tête (« 46090 VERS CEDEX 2 »), un déterminant
puis un mot neutre (« LES PLACES »), un complément entre parenthèses
(« CHATEAU CHINON (VILLE) »), un tiret entouré de blancs et deux ou trois
blancs de suite (« SARROUX - SAINT JULIEN »). Elles sont levées **devant
« CEDEX » seulement**. Balayage des communes en capitales avec « CEDEX n »,
chemin `Ecluse.redact` : 95 adresses sur 139 500 en partie en clair → 1 (« SAINT
M HERVE » : le « M » isolé est lu comme une civilité, `_titres`, et le numéro
de CEDEX reste). Balayage **sans** « CEDEX » : inchangé (338), la règle du mot
neutre y reste entière. **Coût, dit franchement : un masquage en trop.** Un
nombre à cinq chiffres, un mot neutre et « CEDEX » à la suite (« VIREMENT DE
70000 EUROS CEDEX 3 ») est masqué comme une adresse. Témoin du pire cas
(`bench/generate_corpus_neutre_cedex.py`, 400 phrases construites, aucune
adresse annotée) : phrases masquées en capitales 0 / 200 → 113 / 200, en casse
ordinaire 0 / 200 (inchangé). Les tournures de quantité (« total de », « lot »,
« réf. ») protègent toujours le nombre quand il suit un autre mot : 13 phrases
sur 200 au milieu d'une phrase contre 100 sur 200 en tête de phrase. Le témoin
dit le pire cas, pas une fréquence ; « nombre + mot neutre + CEDEX » est rare
dans un vrai texte, mais le coût n'est pas mesuré sur du texte réel.
Conséquence non demandée : les parenthèses, tirets isolés et blancs multiples
devant « CEDEX » sont aussi admis en casse ordinaire (le motif est partagé) ;
balayage en casse ordinaire avec « CEDEX n » : 41 → 8 adresses en partie en
clair, aucun autre chiffre du tableau de bord ne change.

**Commune dont le nom contient un mot de voie (P2-213).** 52 communes du
référentiel ont un type de voie dans leur nom (« Graffigny-Chemin », « La
Chaussée-Tirancourt », « Cours-la-Ville », « Rue »). Suivies d'une ligne « code
postal + mot » (une liste d'adresses, une ligne de quantité), elles étaient lues
à partir du mot de voie, la ligne suivante devenant le code postal de cette
« voie » : « 52417 GRAFFIGNY [ADRESSE_1] », le vrai code postal et le début du
nom en clair ; pour la commune de Rue, le premier chiffre du code postal seul
(« 8[ADRESSE_1] »). Balayage `bench/generate_corpus_commune_voie.py`
(`Ecluse.redact`, 3 744 documents, capitales et casse ordinaire, avec et sans
CEDEX) : documents à adresse en partie en clair **641 → 26**, dont code postal
ou début du nom en clair **615 → 0**. **Ce qui reste (26 documents, 4 communes,
tous sans CEDEX)** n'a pas le mot de voie pour cause : c'est la fin d'un nom de
plus de quatre mots (« SAINT JEAN DE LA RUELLE » derrière une vraie voie,
« VILLERS CHEMIN ET MONT LES ETRELLES ») ou lié par « au », « et »
(« Villeneuve au Chemin »), la limite des communes longues sans CEDEX décrite
dans ce document (P2-181, P2-205) ; ces 26 documents étaient déjà en défaut avant, à l'identique.
**Jetons fusionnés.** Quand les deux lignes sont chacune un « code postal +
commune » reconnu, elles gardent un jeton chacune. Sinon l'adresse est étendue
jusqu'au vrai code postal et **les deux lignes partagent un seul jeton** : c'est
le cas en capitales quand la commune commence par un déterminant (« 80691 LA
CHAUSSEE TIRANCOURT » puis « 80000 AMIENS »), ou quand le code postal suit une
tournure de référence (« Lot 52417 GRAFFIGNY CHEMIN CEDEX 7 » : le nombre, qui
seul resterait en clair, est masqué avec l'adresse). Rien ne fuit, la
restauration est exacte, mais le LLM voit une adresse là où il y en a deux. La
ligne « code postal + mot » qui suit reste masquée en trop (1 248 / 1 248 au
balayage, 1 246 avant) : ce n'est pas l'objet de cette correction. Le balayage
ne couvre ni un texte tout en minuscules, ni une commune hors référentiel.

#### 5.2.5 Variantes d'écriture : noms, dates, civilités, voies, CEDEX

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

**Numéro de CEDEX (P2-164, 13 novembre).** Mesure P2-157 : « 70000 VESOUL CEDEX 9 » était masqué jusqu'au mot
« CEDEX », et le numéro de distribution restait en clair (« [ADRESSE_1] 9 ») ; « cedex » en minuscules et
« , CEDEX 9 » restaient entiers en clair. Le motif « code postal + commune » accepte maintenant « CEDEX » dans toutes
les casses, après une virgule facultative, et **1 ou 2 chiffres** derrière lui, sur la même ligne. Tests d'abord
(12 rouges sur 20) ; par `Ecluse.redact`, adresses du corpus flou adversarial : 1,9 % → **0 %** de caractères en
clair (global 7,2 % → 6,7 %), toutes variantes de casse et de mise en page comprises ; corpus réaliste, témoins et
reste du tableau de bord inchangés. Contre-exemples testés : « 70000 VESOUL 3 agents » (pas de CEDEX : le nombre
reste), « CEDEX 2026 dossiers », « CEDEX 9e étage », un nombre à la ligne suivante, « Le service CEDEX 9 » hors
adresse. **Restent en clair** : la boîte postale (« BP 12 », « CS 40001 », « TSA »), avant le code postal ou sur
sa propre ligne (complément intercalé, hors périmètre v0, voir plus haut), et, sans « CEDEX » derrière elle, la fin d'une
commune de plus de quatre mots (ci-dessous, P2-181).

**Nom de commune masqué en partie (mesure P2-178 ; corrigé par P2-180 et, devant « CEDEX » seulement, par P2-181).** Par
`Ecluse.redact`, sur des adresses « code postal + commune + CEDEX » dont la commune vient du référentiel
(`agent/specs/P2-178.md`, `bench/generate_corpus_cedex.py`) : en écriture postale (capitales, espaces), une commune de
**cinq mots ou plus** laissait sa fin en clair, et « CEDEX » et son numéro avec elle (20,8 % des caractères de l'adresse
à cinq mots, 27,6 % à six, 34,9 % à sept ; 0 % jusqu'à quatre). Le CEDEX n'est pas la cause : dès que la commune est
masquée en entier, il l'est aussi.

**Corrigé devant « CEDEX » (P2-181).** Ce qui sépare un code postal du mot « CEDEX », sur la même ligne, est la
localité : devant « CEDEX », le nom accepté va jusqu'à neuf mots et admet les mots de liaison absents de la liste
courante (« et », « au », « à », « près », « devant », « di », « ès »…). Balayage : `postale` **145 → 7**,
`libelle_espaces` **626 → 15**, `libelle` 26 → 10, `capitales_tirets` 14 → 9. **Sans « CEDEX » derrière, rien ne
change** : « 07590 SAINT LAURENT LES BAINS LAVAL D AURELLE » seul sur sa ligne laisse toujours « LAVAL D AURELLE » en
clair, « 40660 Moliets et Maa » laisse « et Maa » (corpus par longueur, sans CEDEX : 263 adresses en défaut sur 1 960,
avant comme après). Allonger le nom sans cette borne masquerait davantage le texte ordinaire qui suit une commune : le
témoin `bench/generate_corpus_commune_suivie.py` mesure déjà 56 % des caractères d'une telle suite masqués (« 70000
VESOUL SERVICE DES ADMISSIONS » est pris en entier), et une règle « jusqu'à la fin de la ligne » le porterait à 73 %
(`bench/ETAT.md`). Le choix revient au mainteneur ; une table des communes le trancherait mieux (P2-182). Hypothèse
assumée de la règle : une mention placée entre la commune et « CEDEX » (« 70000 VESOUL SERVICE DES ADMISSIONS BATIMENT B
CEDEX 3 ») est masquée avec l'adresse.

Deux autres causes, **indépendantes de la longueur**, sont corrigées (P2-180) : la lettre « œ »/« Œ » (U+0153/U+0152),
hors des classes Latin-1 (`À-ÖØ-Þ`/`à-öø-ÿ`, qui s'arrêtent à U+00FF) du motif de commune — « 59112 Annœullin » perdait
tout après « Ann », une commune qui **commence** par « Œ » (« Œuilly ») n'était pas reconnue comme commune du tout ;
et un mot qui commence comme un titre abrégé (« M », « Me », « Pr », « Dr »…) suivi d'une lettre accentuée, refusé
comme une civilité annonçant un nom (« 93310 Le **Pr**é-Saint-Gervais », « 04190 Les **M**ées ») — `\b` de Dart se
fonde sur `\w` ASCII (sans drapeau `unicode`) : il voit une frontière de mot entre un « r »/« m » et une lettre
accentuée qui suit directement, comme si la civilité s'arrêtait là. Une vraie civilité devant un nom est toujours
suivie d'un espace ou d'un point (« Mme Durand », « M. Durand », « Dr Faure », « Me Blanc ») : inchangée. Balayage des
34 875 communes, une fois par écriture : `libelle` (officiel) **163 → 26**, `capitales_tirets` **143 → 14** ; `postale`
inchangé à 145 (cause dominante : la longueur, non traitée ici) ; `libelle_espaces` descend en sous-produit (901 → 626,
il partage ces deux causes avec sa cause dominante, les mots de liaison absents de la liste, non traités).

**Reste en clair, non corrigé** : sans « CEDEX », la fin d'une commune de cinq mots ou plus en écriture postale et un
mot de liaison absent de la liste courte quand le nom est écrit sans tirets (« Moliets et Maa », « Pont à Mousson »,
« au », « près », « devant »…) ; **sans** « CEDEX », une parenthèse dans le nom (« Bors (Canton de …) » ; devant
« CEDEX », levée par P2-201) et, avec ou sans « CEDEX », un mot en minuscules hors liste (« et ses environs »). Mesuré en casse ordinaire ; un texte tout en capitales ou sans
majuscule passe par d'autres détecteurs (mesure P2-183).

**Nombre à cinq chiffres hors adresse (P2-167, 13 novembre).** Par `Ecluse.redact`, « Commande de 70000 unités,
cedex 9 non concerné. » sortait avec « 70000 unités » masqué comme adresse. Deux règles : `AdresseDetector` seul
(code postal + mot à majuscule, même en casse ordinaire : « Réf. 55090 Standard ») et, dans un texte sans
majuscule hors début de phrase, le texte d'ombre de `MinusculesRecapitaliseDetector` (code postal + nom commun :
« 70000 unités »). Témoin `bench/generate_corpus_cinq_chiffres.py` (400 phrases sans adresse) : **130 → 74** adresses
prédites à tort (nombre après des mots : 64 → **8**). Le motif « code postal + commune **sans voie** » écarte
maintenant un nombre introduit par une tournure de quantité ou de référence (« environ », « lot », « réf. »,
« n° », « dossier », « commande », « facture », « total », et « de » **seulement après un de ces noms** : « commande
de 70000 unités »), jamais d'après le mot qui suit. **Restent masqués à
tort** : un nombre **en tête de phrase** suivi d'un mot (« 58699 Alpha livrés », 66 sur 200), qui a la forme d'un
code postal en tête de ligne (« 70000 Vesoul ») ; un nombre derrière une tournure absente de la liste, dont « de » seul
(8 sur 200). **Choix du 13 novembre** : « de » seul n'écarte rien, pour que « la mairie de 70000 Vesoul » ou « originaire
de 25000 Besançon » restent masqués ; mieux vaut un nombre masqué à tort qu'un code postal en clair. Une adresse avec numéro et voie (« rue du Lot 46000 Cahors ») n'est pas concernée. Adresses des corpus flous
et reste du tableau de bord inchangés.

**Nombre à cinq chiffres en tête de phrase : le masquage à tort est gardé (P2-177).** « 58699 Alpha livrés. » et
« 71344 boîtes expédiés. » (texte sans majuscule) restent masqués comme des adresses : 66 phrases sur 200 du témoin,
inchangé. La seule tournure qui les distingue de « 70000 Vesoul » est ce qui **suit** le nom : un mot en minuscules sur
la même ligne. Mesure par `Ecluse.redact` (`run_cp_tete_bench.dart`, règle simulée dans le banc, jamais dans `lib/`) :
écarter « nombre en tête + nom + mot en minuscules » retirerait les **66** prédictions à tort, mais ferait partir en
clair **108 adresses sur 432** du corpus `bench/generate_corpus_cp_tete.py` (toutes celles que suit un mot en minuscules :
« 25000 Besançon depuis 2019 », « domiciliée au⏎25000 Besançon depuis 2019 » dans une prose recoupée comme la rend un
PDF, « 70000 vesoul et environs » tapé sans majuscule), dont 36 en début de ligne, 36 en début de texte et 36 après une
phrase. Les adresses des corpus flous du tableau de bord, elles, ne seraient pas touchées (0 perdue) : aucune n'a
cette forme, ce qui dit seulement qu'ils ne l'exercent pas. Les deux formes ne se séparent donc pas sans perte, et
une adresse en clair est une fuite quand un nombre masqué à tort ne coûte que de la lisibilité : **rien n'est
changé dans le détecteur**. Pistes écartées sans mesure : juger les deux premiers chiffres (un département qui
n'existe pas) ne retirerait presque rien, un nombre quelconque ayant presque toujours un préfixe de département
valide, et ferait perdre des adresses étrangères à cinq chiffres ; une liste de noms de comptage (« unités »,
« boîtes ») reviendrait à ajuster le détecteur au témoin. Ce qui séparerait vraiment : reconnaître la commune
(table des communes d'`ecluse_reference`), ce que ce détecteur ne fait pas.

#### 5.2.6 Identifiants coupés, dates et étiquettes de champ

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
*P2-152 (11 novembre)* : sur un échantillon de 400 documents du corpus structurel remis en page (retours
à la ligne d'une page, sans autre changement), 5 identifiants sur 316 restaient en clair : coupure après
une lettre de groupe (« 461K⏎4056 », « 2A ⏎073 ») ou bordée d'espaces insécables (« 7460⏎\u00A08432 »).
La coupure est maintenant admise après **une** majuscule précédée d'un chiffre et avec les mêmes blancs
que `DigitCompaction` ; ce qui suit doit toujours être un chiffre. Tests d'abord (4 rouges sur 6) ;
4 contre-exemples intacts (« Chambre 12B⏎34 lits »…) ; échantillon : 5 → 0 ; tableau de bord et
fichiers de prédiction inchangés octet pour octet ; coût mesuré sur 4 entrées de 400 000 caractères : 1,5 à 2,4 s.
*P2-153 puis P2-158 (12 novembre)* : sur le corpus structurel (1 000 documents, 778 identifiants) remis en
page à 60 colonnes, **`Ecluse.redact`** (le chemin que reçoit le LLM) détectait 777 identifiants sur 778 : un
IBAN coupé juste avant un groupe qui commence par une lettre (« …0270⏎D932… ») restait en clair. La coupure est
maintenant aussi admise devant **une** majuscule suivie d'un chiffre : 778 / 778 à 60 et à 90 colonnes. Contre-
exemples intacts, testés : « Salle 4⏎A2 fermée », « Vol 12⏎B7 porte », « le 3⏎C4 du plan », « Étage 2⏎A1 ». Le
**moteur seul** (`EcluseEngine`, `ecluse_core`) n'a pas cette neutralisation : à 60 colonnes il ne détecte que 87,7 %
des identifiants (NIR 91,8 %, RPPS 90,4 %, IBAN 72,9 %), à 90 colonnes 96,5 % ; une application qui l'appellerait
directement manquerait les identifiants coupés (voir P2-162).

**Limite du moteur seul et des détecteurs appelés seuls (décision du 13 novembre, option B de P2-162 ; P2-171).**
Un détecteur d'`ecluse_core` appelé directement (`NirDetector().detect(texte)`, l'exemple de son README) ou le
moteur seul (`EcluseEngine`) **ne lit pas un identifiant coupé par une fin de ligne** : aucun des deux ne franchit
un saut de ligne. Mesuré sur le corpus structurel synthétique remis en page (778 identifiants, `bench/ETAT.md`,
section « Mise en page ») : **682 / 778** détectés à 60 colonnes (96 manqués : 22 NIR, 16 RPPS, 58 IBAN) et
**751 / 778** à 90 colonnes (27 IBAN manqués), par l'appel direct comme par le moteur seul. Depuis le 22 novembre
(48 IBAN à clé fausse annotés, 826 identifiants) : moteur seul 730 / 826 et 799 / 826 (mêmes coupures manquées),
détecteur appelé seul 682 / 826 et 751 / 826 (il écarte en plus la clé fausse, que le moteur et `Ecluse.redact`
masquent). Le morceau qui reste
sur une ligne peut en plus être pris pour un autre identifiant (9 fins d'IBAN lues comme un RPPS). Par
**`Ecluse.redact`**, le seul chemin du produit et ce que reçoit le LLM : **778 / 778** aux deux largeurs (826 / 826 depuis le 22 novembre). Un texte
qui vient d'un PDF, d'un courriel ou d'un formulaire passe donc par `Ecluse.redact`, pas par un détecteur seul.
Ces chiffres valent pour un corpus synthétique recoupé mécaniquement ; ils ne disent pas la fréquence d'une
coupure dans des documents réels. Descendre la neutralisation dans le cœur (option A1) n'est pas décidé : les deux
mesures qui manquaient sont dans `agent/specs/P2-171.md`.

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

#### 5.2.7 Téléphones, noms de naissance, titres et particules

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

#### 5.2.8 Types de voie, balisage, courriels, signatures, rôles

**Types de voie et abréviations (P2-49).** Sonde de 26 adresses : « 25 R. de la Paix, 75002 Paris »,
« 3 pl. de la Bastille, 75004 Paris » et « 14 sentier des Roses, 44000 Nantes » ne masquaient que « code postal
+ commune » et laissaient le **numéro et le nom de rue en clair** (les types « r », « pl », « sentier » n'étaient
pas reconnus). Sont ajoutés : « sentier », « ruelle », « traverse », « venelle », « parvis », « promenade »,
« montée », « clos » et les abréviations « r », « pl », « ch », « imp », « all », « sq », « crs » (point facultatif).
Tests d'abord (17 rouges) ; banc inchangé octet pour octet ; 715 tests ; coût linéaire. Le code postal + commune
reste obligatoire en fin de motif : « Le 25 R de la table », « Chapitre 3 pl. de la liste », « Il a fait 6 clos de la
saison », « Page 6 ch. 3 » restent intacts (5 contre-exemples testés). **Restent non couverts** : « Rond-point »,
« Cour », « Mail », « Domaine », « Résidence » (complément d'adresse), « Cedex 03 » (le suffixe restait en clair ; **traité par P2-164**, voir § adresses ci-dessous),
une adresse sans code postal (« 12 rue des Lilas »), « Paris 11e ». Les abréviations d'une
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

#### 5.2.9 Adresses sans code postal, identifiants étiquetés, IBAN, téléphones étrangers

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
**Vérification des longueurs** : 23 des 38 ont été recoupées avec des documents bancaires publics (liste consultée par
recherche, 27 octobre 2026) ; CH, ES, SE, FO, GI, LI, LT, LV, MC, MT, RO, SI, SK, SM, VA n'ont pas pu l'être, le registre
SWIFT (ISO 13616) n'étant pas joignable depuis l'environnement d'exécution ; elles sont reprises du registre de mémoire. Une
longueur fausse entraînerait un IBAN **manqué**, jamais un faux positif (la clé reste exigée) : à confirmer par le
mainteneur contre le registre. Luxembourg : 20 (trois sources) contre 19 dans une quatrième. **Non traité** : BIC/SWIFT,
IBAN hors espace SEPA (Maroc, Algérie, Tunisie, Royaume-Uni hors SEPA…), IBAN coupé par un saut de ligne au milieu d'un groupe.

#### 5.2.10 Tableaux, formats structurés et coût de calcul

**Noms en clés de données explicites et tableaux CSV à en-tête (P2-61).** Arbitrage du 27 octobre (question 7).
*Clés* : `nom_patient`, `nom_famille`, `nom_naissance`, `nom_usage`, `nom_de_naissance`, `lastname`, `family_name`,
`surname`, `firstname`, `given_name`, `prenom(s)` (snake_case, kebab-case ou camelCase) sont reconnues en JSON
(`"cle": "v"`), XML (`<cle>v</cle>`), paramètres (`cle=v`) et texte brut ou YAML (`cle: Valeur`, majuscule initiale). La
valeur peut être en minuscules hors du texte brut (la clé est l'indice) ; `null`, `inconnu`, `vide`, `oui`, `non`, `n/a`, un
nombre, une valeur absente ne sont jamais des noms. **La clé nue « nom » reste exclue** (`"nom": "Aspirine"`,
`nom_fichier`, `nom_projet`). *CSV* : une ligne d'au moins 2 champs courts dont l'un est une colonne de personne (« Nom »,
« Prénom », « Nom de naissance », « Nom d'usage », `LastName`, `FirstName`…), suivie d'une ligne de données de même largeur,
est un tableau : les cellules de ces colonnes sont masquées, quelle que soit leur casse. Séparateurs `;`, tabulation, `|`,
`,` ; guillemets doublés admis. **Refus explicite** : une ligne de données qui n'a pas le nombre de colonnes de l'en-tête
(virgule non protégée, colonne manquante) ou un guillemet non fermé (cellule sur plusieurs lignes, non prise en charge)
lève `TableauAmbiguException` (ligne et motif, jamais le contenu) au lieu de laisser des noms en clair ; une ligne sans
séparateur ou une ligne vide met fin au tableau (texte qui suit). Un en-tête sans ligne de données conforme n'est pas un
tableau (« Nom, prénom et adresse seront demandés »). Tests d'abord (36 rouges : 21 clés, 15 CSV) ; 23 contre-exemples intacts (16 clés, 7 non-tableaux) ; banc inchangé
octet pour octet ; 962 tests. **Conséquence à connaître** : `Ecluse.redact` et ses dérivés peuvent maintenant lever
`TableauAmbiguException` ; un appelant qui ne la gère pas verra l'envoi refusé (comportement voulu : pas d'échec
silencieux). **Non traité** : cellules sur plusieurs lignes entre guillemets, colonnes dont l'en-tête est une autre langue ou
une abréviation (`NOM_USUEL`, `patient`), tableaux sans en-tête, colonnes combinées « Nom Prénom » dans la clé nue.
Un tableau à virgule suivi directement d'une phrase qui contient une virgule est refusé : séparer par une ligne vide.

**Tableaux et blocs HTML (P2-63).** Arbitrage du 27 octobre (question 9). *Mesuré d'abord* : les titres Markdown
(`## Date de naissance⏎12/03/1950`, `### Né le …`) étaient déjà traités ; `## Nom : Quenelle` reste en clair à cause de la
règle « Nom » seul (une fiche d'identité exige « Prénom » à proximité, P2-36), pas à cause du titre. Les fuites étaient les
balises entre l'étiquette et sa valeur (`<td>Date de naissance</td><td>12/03/1950</td>`) et `&nbsp;`. Dans la vue de
détection seulement (le texte n'est jamais réécrit, les positions restent exactes), les balises `td`, `th`, `tr`, `table`,
`thead`, `tbody`, `tfoot`, `p`, `div`, `li`, `ul`, `ol`, `h1` à `h6`, `br` et `&nbsp;` sont retirées et remplacées par un
séparateur : U+001F entre deux cellules (lu comme `:` par les étiquettes de nom, de prénom, de date de naissance et
d'identifiant, et comme séparateur de colonnes par le CSV de P2-61), U+001E entre deux cellules d'en-tête `<th>`
(séparateur de colonnes seulement : un en-tête « Nom, Prénom, Service » ne se lit jamais « Prénom : Service »), saut de
ligne entre deux blocs (jamais deux de suite), espace pour `&nbsp;`. Les attributs ne sont tolérés que s'ils sont de pure
mise en forme (`class`, `style`, `colspan`, `rowspan`, `width`, `height`, `align`, `valign`, `bgcolor`, `id`, `border`) :
`title`, `href`, `alt` restent visibles des détecteurs, donc une donnée personnelle dans un attribut est toujours
détectée (`<a href="mailto:…">`, `<td title="Mme Dupont">`). Un tableau à en-tête `<th>` est lu comme un CSV (colonnes de noms
masquées) ; les sauts de ligne réels entre les lignes `<tr>` sont admis. **Refus explicite** : dans un tableau HTML à
en-tête, une première ligne de données dont le nombre de cellules diffère de l'en-tête (cellule fusionnée `colspan`, colonne
manquante) lève `TableauAmbiguException`, la structure HTML étant certaine ; une ligne à une seule cellule (« Total »)
met fin au tableau sans refus, et les lignes qui la suivent ne sont plus lues. Tests d'abord (9 rouges sur 21, puis 2 cas ajoutés en vérifiant : sauts de ligne réels, cellule fusionnée) ; 6 contre-exemples intacts ; banc inchangé octet pour octet ; 1022 tests ; 10
entrées pathologiques d'~1 Mo en 0,3 à 1,9 s. **Non traité** : balises avec un attribut libre (`<td data-x="…">`), tableaux
imbriqués, listes de définitions (`dl`, `dt`, `dd`), liens Markdown (texte et URL) et listes à puces, que l'arbitrage n'a
pas retenus. Un en-tête écrit avec `<td>` plutôt que `<th>` (`Nom`, `Prénom` en `td`) peut faire lire « Nom : Prénom » comme un
nom : la valeur « Prénom » ou « Nom » est écartée, mais pas un autre libellé de colonne.

**Coût de la résolution des pseudonymes (P2-64).** Arbitrage du 27 octobre (question 12). Le coût résiduel « au-delà de
~50 000 mentions » (P2-48, P2-53 à P2-56) dépendait en réalité du nombre d'identités **distinctes**, non du nombre de
mentions : 10 000 noms distincts (110 Ko) prenaient 37 à 43 s, 10 000 mentions d'un même nom 0,6 s, 10 000 « Marie X »
14 s. Mesuré avant de corriger (détection : 0,5 s ; tout le reste dans la résolution). **Cause principale** (trouvée après
une première piste insuffisante, un index des identités seul : 43 s → 36 s) : `_freshToken` appliquait le motif de jeton
à **tout le texte** pour chaque nouveau jeton (10 000 jetons × 110 Ko). Il ne regarde plus que les segments `[...]` sans
crochet intérieur, relevés une fois par texte (même raisonnement que `jetonsLitteraux`, P2-25) : 37 s → 0,55 s.
**Seconde cause** : chaque mention était comparée à toutes les identités du dossier ; un index les retrouve par segment le
plus rare de la mention (identités qui contiennent tous ses segments) et par sous-ensemble exact de ses segments
(identités incluses dans la mention), le prédicat d'inclusion exact restant appliqué ensuite : « Marie X » ×10 000 :
14 s → 1,1 s. Mesuré : 10 000 / 20 000 / 40 000 noms distincts en 0,55 / 2,0 / 5,2 s (légère croissance résiduelle, due au
reste de l'attribution) ; 10 000 / 20 000 « Marie X » en 1,1 / 2,8 s. **Équivalence vérifiée** : 3 000 exécutions
(1 500 graines × 2 règles de noms × 3 documents d'un dossier, civilités, initiales, ordres inversés) puis 2 000 avec des
jetons littéraux dans le texte (`[NOM_1]`, `[ nom_2 ]`, `\[NOM\_3\]`…), comparées à `main` : sorties identiques
(texte masqué et carte de restauration). Banc inchangé octet pour octet ; 1033 tests ; trois tests de coût
(`cout_noms_distincts_test.dart`, bornes de 10 s pour des mesures de 0,5 à 1,1 s). **Non traité** : la croissance résiduelle
au-delà de 40 000 noms distincts, non mesurée plus loin ; la détection des noms elle-même (0,5 s pour 10 000 noms).

**Résolveur de chevauchements linéaire (P2-66).** Mesuré en traitant un tableau de 40 000 rangées (P2-65) : la détection de noms seule
prenait 0,7 s, mais `Ecluse.detect` 18 s. La cause est dans `ecluse_core` : `resolveOverlaps` comparait **chaque** entité candidate à
**toutes** les entités déjà retenues (`kept.any(...)`), soit un coût quadratique dès qu'un texte contient beaucoup d'entités (80 000
entités disjointes : 14 s ; 80 000 entités se chevauchant par paires : 9,8 s). C'est aussi la **cause restante** des coûts « au-delà de
~50 000 mentions » signalés de P2-48 à P2-56 : la résolution des pseudonymes (P2-64) n'en était qu'une partie. Les entités retenues étant
disjointes, seule celle qui commence le plus tard avant la fin du candidat peut le chevaucher : une `SplayTreeMap` triée par début la
donne en O(log n). L'ordre de priorité (longueur, confiance, tier, position) est inchangé. **Équivalence vérifiée** : 5 000 tirages
aléatoires (jusqu'à 40 entités, longueurs, confiances, tiers et types variés, égalités) comparés à l'ancienne implémentation, gardée dans
le test : sorties identiques. Mesuré : 80 000 entités en moins de 3 s (borne du test) ; tableau CSV de 10 000 / 20 000 / 40 000 / 80 000
rangées en 0,8 / 1,2 / 2,3 / 4,3 s (avant : 1,5 / 4,7 / 18 s pour 10 000 / 20 000 / 40 000) ; « née Dupont » ×100 000 (1,1 Mo) en 3,1 s
et ×200 000 (2,2 Mo) en 5,9 s ; 80 000 noms distincts en 4,4 s. Banc inchangé octet pour octet ; core 215 tests, tous les paquets verts.
`ecluse_core` reste pur (la bibliothèque standard `dart:collection` seule, aucune dépendance ajoutée).

**Tableaux Word et ODT (P2-65).** Sonde d'ingestion (1ᵉʳ novembre 2026), faite sur des fichiers `.docx` et `.odt` générés : les
cellules d'un tableau étaient aplaties en **un paragraphe chacune** (« Nom⏎Quenelle⏎Prénom⏎Zorglub »), sans lien entre l'étiquette et sa
valeur, ni entre l'en-tête d'un tableau et ses colonnes. Les noms d'un tableau étiquette / valeur et d'un tableau à en-tête
(« Nom ⇥ Prénom ⇥ Service ») restaient **en clair** ; seuls la date de naissance et le téléphone (reconnus par leur forme ou par un
saut de ligne unique) étaient masqués. Les tableaux sont le format dominant des fiches et plannings des établissements : c'est la fuite
la plus étendue trouvée depuis P2-34. **Maintenant** (`ecluse_ingest`) : les cellules d'une rangée sont séparées par une tabulation et les
rangées par un saut de ligne (`</w:tc>` / `</w:tr>` pour le docx, `table:table-cell` / `table:table-row` pour l'odt). Dans une cellule,
les paragraphes, tabulations et sauts de ligne deviennent des espaces ; une cellule fusionnée (`w:gridSpan`, cellule couverte ou répétée
d'un odt) garde le même nombre de champs ; un tableau imbriqué reste dans la cellule parente. Hors tableau, l'extraction est inchangée.
`ecluse_redact` lit alors le texte : un tableau à en-tête (colonne « Nom », « Prénom »…) est traité comme un CSV tabulé (P2-61, avec son
refus explicite si une rangée n'a pas le nombre de colonnes de l'en-tête, par exemple après une fusion de cellules) ; une rangée de **deux
champs** « étiquette ⇥ valeur » est lue comme « étiquette : valeur » pour les étiquettes de nom, de prénom et de rôle. Une rangée de plus de
deux champs ne l'est jamais (« Prénom ⇥ Service ⇥ Chambre » n'est pas un prénom). Tests d'abord (11 rouges sur 15 pour l'extraction et le
masquage de bout en bout, 5 rouges sur 9 pour la tabulation) ; contre-exemples : tableau sans colonne de personne, « Nom ⇥ Aspirine » seul, texte hors
tableau ; banc inchangé octet pour octet ; ingest 136 tests, redact 1042. Coût : 6 entrées pathologiques de 0,35 à 8,6 Mo en 0,2 à 3,5 s
(extraction) ; un tableau de 50 000 rangées (8,6 Mo) met 4,3 s d'extraction et 28 s de détection, le reste étant le coût quadratique du
résolveur de chevauchements (`resolveOverlaps`), traité en P2-66. **Non traité** : tableaux des PDF (hors périmètre), cellules d'une
feuille de calcul (`.xlsx` refusé), formules de champs et zones de texte flottantes, en-têtes et pieds de page (déjà signalés dans
`ignored_parts`), cellules à plusieurs lignes dont le contenu relève d'une seule valeur (les paragraphes d'une cellule sont joints
par une espace).

**Formats texte structurés à l'ingestion (P2-67).** Les fichiers `.csv`, `.tsv`, `.json`, `.html`/`.htm` et `.xml` étaient refusés
(« Format non traité ») alors que la détection lit désormais leur structure : en-tête CSV (P2-61), clés de données explicites (P2-61), tableaux
HTML (P2-63). Ils sont maintenant lus comme du **texte brut**, avec les garde-fous de `.txt` : UTF-8 strict (BOM retiré), refus d'un
contenu binaire déguisé (signature reconnue), d'un NUL, de l'UTF-16 et d'un encodage non reconnu. **Conséquence à connaître** : un export
Excel français est souvent en Windows-1252 : il est refusé avec le motif « ré-enregistrez en UTF-8 », jamais deviné (un accent mal décodé
décalerait les caractères et casserait le masquage). Aucun rendu : la syntaxe brute est le texte que la détection voit. Une cellule CSV sur
plusieurs lignes entre guillemets, ou un CSV dont une ligne n'a pas le nombre de colonnes de l'en-tête, lève `TableauAmbiguException` à la
détection. `IngestFormat` gagne cinq valeurs (`csv`, `tsv`, `json`, `html`, `xml`) : aucune autre partie du dépôt n'énumère ces valeurs. Tests
d'abord (20 tests, dont le bout en bout par format et les refus) ; ingest 156 tests, redact 1042, demo 37. **Non traité** : `.xlsx`, `.rtf`,
`.doc`, `.pptx` (refusés avec motif), `.yaml`/`.yml`, `.ini`, `.log`, les encodages autres qu'UTF-8. **Décision de périmètre, révocable** :
retirer la ligne correspondante du `switch` de `ingest_file.dart` rétablit le refus.

#### 5.2.11 Prénoms, civilités au pluriel, chemins, noms coupés

**Diversité des prénoms du gazetteer (P2-68).** Sonde de 143 prénoms courants d'origines variées (« Il a vu {prénom} Zxqvlorn hier. », un
nom de famille inconnu) : **82 n'étaient pas détectés** (61 sur 143 seulement). Étaient manqués, entre autres, des prénoms du Maghreb
(Rachid, Nabil, Hakim, Aicha, Khadija), d'Afrique de l'Ouest (Moussa, Ousmane, Cheikh, Fatou, Aminata), d'Europe du Sud et de l'Est
(Giuseppe, Luigi, Carlos, Piotr, Olga, Svetlana), d'Asie (Linh, Hiroshi, Priya, Ravi), des prénoms anciens (Mauricette, Ginette) et récents
(Dylan, Océane, Maëlys, Nolan). Le gazetteer du détecteur de noms (une liste de démonstration, 97 lignes) ne contenait que les prénoms
français les plus répandus. **68 prénoms sont ajoutés**, d'origines variées ; ceux qui sont aussi des mots courants sont **écartés** (Jan et
Jun, mois abrégés ; Lou ; Said, verbe anglais ; Manuel, adjectif et titre d'ouvrage ; Mario ; Li ; Thi). Tests d'abord (69 rouges sur 78) ;
phrases ordinaires intactes (« Manuel d'utilisation », « en Jan et en Jun », « Mario Kart »). **Faux positifs mesurés** sur 3 896 textes
des corpus synthétiques du dépôt (graine 7, 300 textes par corpus : dossiers, flou, patronymes y compris les « leurres », QI ; avant /
après) : **32 textes changent, tous dans le corpus « flou adversarial »**, conçu pour les prénoms étrangers, et tous pour de **vrais prénoms**
désormais masqués (Aïcha, Krzysztof, Mei-Ling, Ibrahim…) ; aucun changement dans les corpus témoin, réaliste ni leurres. Banc inchangé octet pour
octet ; 1120 tests. **Non traité, et à ne pas surestimer** : la liste reste une liste de démonstration. Le gazetteer INSEE des prénoms
(155 000 entrées, `ecluse_reference`) n'est pas branché au détecteur : sans fréquences, il contient trop de mots courants pour servir de
masque (voir son avertissement) ; un seuil de fréquence demanderait le fichier INSEE avec les effectifs (DATA_SOURCES.md), non retenu ici. *Mise à
jour (P2-149)* : les effectifs sont désormais embarqués et servent à l'option `prenomsInsee` (§ 5.1) ; la liste sans effectifs reste hors
de la détection.
Un prénom d'une origine non listée reste manqué sans contexte (civilité, étiquette, en-tête…).

**Civilités au pluriel, en minuscules ou en majuscules, mots de parenté (P2-69).** Sonde de 26 formules de politesse (1ᵉʳ novembre 2026) :
**13 laissaient le nom (ou le patronyme) en clair** — « Mmes Quenelle et Dupont », « MM. Quenelle et Dupont », « La famille Quenelle », « Les époux
Quenelle », « Les consorts Quenelle », « le docteur Quenelle », « la doctoresse Quenelle », « Père Quenelle », « Mdme », « Melle », « MME
QUENELLE Zorglub » — et « Sœur Marie-Pierre Quenelle » masquait le prénom (avec « Sœur ») mais **laissait le patronyme** ; « Capitaine Quenelle » fait partie des 13 et n'est pas traité. **Maintenant** :
(1) civilités singulières ajoutées : `Mdme`, `Melle`, `MME`, `MLLE`, `MR`, `MONSIEUR`, `MADAME`, `MADEMOISELLE`, `DOCTEUR`, `PROFESSEUR` et
les formes en minuscules `monsieur`, `madame`, `mademoiselle`, `docteur`, `docteure`, `doctoresse`, `professeur`, `professeure` (les titres
professionnels `docteur`… sont inclus dans l'étendue masquée, comme « Dr ») ; (2) pluriels `Mmes`, `Mlles`, `MM.`, `Mesdames`, `Messieurs` :
**une entité par nom** (« Quenelle », « Dupont »), jamais un seul jeton pour deux personnes, noms séparés par une virgule, « et » ou « ou » ;
(3) mots de parenté `famille`, `époux`, `consorts`, `Sœur`/`Soeur`, `Frère`, `Père` suivis d'un nom en majuscule initiale (1 à 2 mots, jamais
un mot-clé d'établissement ni une particule seule : « la famille de la résidence » n'est pas un nom). Tests d'abord (26 rouges sur 37) ; 13
contre-exemples intacts (« La famille est présente », « Famille d'accueil », « le docteur est passé », « madame est partie », « 10 MM. de
mercure », « Père et mère »…) ; **faux positifs** : 3 896 textes de corpus synthétiques comparés à `main`, **0 changement** ; banc inchangé octet
pour octet ; 1157 tests ; coût linéaire sur 9 entrées d'~1 Mo (1,6 à 3,4 s). **Sur-masquages connus** : « Père Noël » (masque « Noël »), « madame
Rose » (Rose est un prénom) et tout mot en majuscule initiale après `famille` (« Famille Aidante » masque « Aidante »). **Non traité** : grades
(« Capitaine », « Colonel »), « tante », « oncle », « grand-mère » suivis d'un nom, « la famille de Rose » (la particule empêche la règle de
parenté ; seul « Rose » est masqué, car c'est un prénom du gazetteer).

**Prénom entre deux mots capitalisés (P2-70).** Trouvé en sondant des noms dans des noms de fichiers (1ᵉʳ novembre 2026) : « Pièce jointe :
Bilan Pierre Dupont.docx » donnait « [NOM_1] Dupont.docx ». La cause est générale : la règle bidirectionnelle (un prénom du gazetteer
et un mot capitalisé voisin) **prenait le mot qui précède et ne regardait pas celui qui suit** quand les deux existaient. Donc dès qu'un
mot capitalisé précédait « Prénom Nom » — début de phrase (« Appeler Pierre Dupont demain »), titre (« Bilan Pierre Dupont »), mot
d'état (« Patient Pierre Dupont », « Résident Pierre Dupont »), « Merci », un jour (« Mardi ») — **le patronyme restait en clair**. Mesuré :
9 formulations sur 14 sondées laissaient le patronyme (« Appeler », « Contacter », « Bilan », « Merci », « Mardi », « Rendez-vous »,
« Résident », « Patient », « Visite »). **Maintenant**, quand un mot capitalisé libre existe de chaque côté du prénom, **les deux sont couverts** (étendue de trois
mots, confiance 0.6) : on ne sait pas lequel est le patronyme (« Dupont Pierre Jean » ou « Pierre Dupont »), et en couvrir un seul laissait
l'autre en clair. Les cas à un seul voisin sont inchangés (« Il faut appeler Pierre Dupont » → « Il faut appeler [NOM_1] »). **Coût
assumé** : le mot capitalisé qui précède est masqué avec le nom (« [NOM_1] demain » pour « Appeler Pierre Dupont demain »), comme il
l'était déjà ; seul le patronyme est en plus protégé. Une mention ultérieure « Pierre Dupont » rejoint la même identité (inclusion de
segments). Tests d'abord (12 rouges sur 17) ; **comparaison sur 3 896 textes de corpus synthétiques** (`main` contre branche) : 32
textes changent, tous dans le corpus « flou adversarial », tous pour un patronyme désormais couvert (« Contacter Aïcha Gauthier »,
« Contacter Mei-Ling Vasseur »…) ; aucun changement dans les corpus témoin, réaliste ni leurres ; banc inchangé octet pour octet ; 1174
tests. **Non traité** : les noms dans les noms de fichiers, URL, logins et chemins (`Bilan_Pierre_Dupont_2024.pdf`, `pierre-dupont`,
`pierre.dupont`, `@pierre_dupont`, `C:\Users\Zorglub`) restent en clair — le séparateur `_`, `-`, `.` ou l'absence de séparation
(`BilanPierreDupont`) fait un seul mot ; « Bilan-Pierre-Dupont.pdf » masque le prénom mais pas le reste.

**Restauration d'un chemin Windows (P2-72).** Trouvé en sondant des noms dans des chemins (1ᵉʳ novembre 2026), sur un défaut introduit par P2-31
et documenté alors comme « effet de bord assumé » : `C:\Users\Jean Dupont\Documents` devient `C:\Users\[NOM_1]\Documents`, et
`Ecluse.restore` rendait `C:\UsersJean Dupont\Documents` : la tolérance à l'échappement Markdown consommait la barre oblique devant le jeton.
Le texte restauré n'était donc **pas celui de l'utilisateur** sur tout chemin Windows (poste de travail, partage réseau `\\serveur\dossier\`),
alors que la restauration exacte est un invariant du projet. L'échappement Markdown échappe les **deux** crochets (`\[NOM\_1\]`) ; une barre
oblique devant le seul crochet ouvrant est un séparateur de chemin. `tolerantTokenPattern` n'accepte plus qu'une barre oblique devant le crochet
ouvrant si la fermante est elle aussi échappée ; les formes de P2-31 (`\[NOM\_1\]`, `\[NOM_1\]`, `[NOM\_1]`, `**\[NOM\_1\]**`, `[ NOM\_1 ]`)
restent restaurées. Tests d'abord (4 rouges sur 5) ; banc inchangé octet pour octet ; 1179 tests, tous les paquets verts. **Non traité** : une
réponse de LLM qui n'échappe que le crochet ouvrant (`\[NOM_1]`) laisse désormais la barre oblique et le jeton se restaure (« \Jean Dupont »).

**Noms dans les noms de fichiers, URL, chemins et identifiants (P2-71).** Sondes (1ᵉʳ novembre 2026) : `Bilan_Pierre_Dupont_2024.pdf`,
`Dupont_Pierre_bilan.docx`, `Pierre.Dupont.pdf`, `https://exemple.fr/patient/pierre-dupont`, `/home/pierre.dupont/dossiers`,
`C:\Users\pierre.dupont\Documents`, `@pierre_dupont`, `login=pierre_dupont` restaient **en clair** (13 sur 25 formes testées) : `_` et `.`
font un seul mot, et un nom en minuscules n'a pas de majuscule pour la détection. **Deux lectures** désormais, dans le détecteur de noms.
(1) *Copie de travail* de même longueur où `_` entre deux caractères alphanumériques, et `.` entre deux mots à initiale majuscule, deviennent
une espace : `Bilan_Pierre_Dupont_2024.pdf` se lit « Bilan Pierre Dupont 2024.pdf » ; ses entités ne s'ajoutent que si elles ne chevauchent pas
celles de la lecture sur le texte d'origine, **sauf quand elles les recouvrent entièrement** (« Pierre Dupont » remplace « Pierre » seul). La
lecture d'origine reste prioritaire parce que les clés de données de P2-61 (`nom_patient`) exigent le `_`. Les valeurs sont relues dans le
texte d'origine : le texte n'est jamais réécrit. (2) *Noms en minuscules*, `pierre-dupont`, `pierre.dupont`, `pierre_dupont` : seulement dans un
contexte (après `/`, `\`, `@` ou `=`, devant une extension de fichier courante, ou derrière « identifiant : », « login = »…), avec un prénom du
gazetteer, et couvrant le prénom et ses deux voisines alphabétiques hors mots courants (documents, articles, prépositions : `bilan`, `compte`,
`rendu`, `sous`, `et`, `de`, `papier`…). Tests d'abord (13 rouges sur 25, puis 3 contre-exemples ajoutés en vérifiant) ; 13 contre-exemples
intacts (`/sous-marin`, `/pierre-et-vacances`, `/rose-des-vents`, `compte_rendu_final.docx`, `Date_Naissance`, `user_id=12345`, `pierre.js`…) ;
3 896 textes de corpus : 0 changement ; banc inchangé octet pour octet ; 1207 tests ; coût linéaire sur 9 entrées d'~1 Mo (0,2 à 5 s). **Faux
positifs connus** : un lien dont deux parties sont un prénom et un mot rare (`/louis-vuitton`, `/pierre-curie`) est masqué ; `/pierre-papier` ne l'est
que parce que `papier` est dans la liste de mots courants. **Non traité** : prénom hors gazetteer (`zorglub-quenelle`), nom sans séparateur
(`BilanPierreDupont.pdf`, `pierredupont`), nom seul (`/pierre/`), identifiants à chiffres (`pdupont42`), et le contenu des fichiers eux-mêmes.

**Nom coupé par un retour à la ligne (P2-73).** Sonde de 14 coupures (1ᵉʳ novembre 2026) : un texte extrait d'un PDF ou copié d'une mise en page coupe
les lignes n'importe où, et un nom coupé restait **en clair** — « Mme⏎Dupont », « Le Dr⏎Quenelle », « née⏎Dupont », surtout la disposition
étiquette puis valeur sur la ligne suivante (« Nom :⏎Quenelle⏎Prénom :⏎Zorglub »), très courante dans les fiches exportées en PDF. **Maintenant**, un
**seul** saut de ligne (jamais une ligne vide) est admis (1) entre une civilité et son nom, (2) entre « née », « épouse », « veuve »… et le nom de
naissance, (3) entre une étiquette « Nom : », « Prénom : », « Patient : »… (deux-points obligatoire) et sa valeur. Un mot qui ouvre ordinairement une
phrase (« Le », « Il », « Dans », « Merci »…) n'est jamais pris pour un nom derrière un saut de ligne. La règle « Nom » seul exige « Prénom » à proximité
(P2-36) : la fenêtre passe de deux à **trois** lignes, pour couvrir « Nom : / valeur / Prénom : ». Dans « Prénom : » la valeur « Nom » ou « Prénom » n'est
jamais un prénom. **Garde-fou conservé** : un nom n'est jamais prolongé au-delà de sa ligne (« Dr Martin⏎Secretaire de séance » ne masque pas
« Secretaire » : deux tests anciens l'imposent) ; un essai qui admettait le saut de ligne **entre les mots** du nom changeait 49 textes des corpus
synthétiques par des faux positifs de ce type, il est donc abandonné. Tests d'abord (8 rouges sur 18) ; 8 contre-exemples intacts (ligne vide, « Mme⏎Le
rapport », « Nom :⏎Aspirine », « Dr⏎Dans le service »…) ; 3 896 textes de corpus : 0 changement ; banc inchangé octet pour octet ; 1225 tests ; coût
linéaire sur 8 entrées d'~1 Mo (2,2 à 3,6 s). **Non traité, fuite connue** : un nom coupé **entre ses mots** (« Mme Marie⏎Dupont » masque « Marie »,
« Jean⏎Dupont est venu » masque « Jean », « Dupont⏎Jean » masque « Jean »), et une coupure par trait d'union (« Dupont-⏎Martin »). C'est le prix du
garde-fou ; une solution demande de distinguer une fin de ligne de mise en page d'une fin de phrase, ce que le texte seul ne permet pas.

**Forme « Nom, Prénom » (P2-74).** Trouvé en relisant à la main un compte rendu synthétique réaliste (1ᵉʳ novembre 2026) : « Dossier n° 2024-18 :
Marchetti, Odette » et « Marchetti, Odette (née Rossi) » donnaient « Marchetti, [NOM_1] … » — le **patronyme restait en clair**. La forme « Nom, Prénom »
est celle des listes, des fiches, des états d'effectifs et des index. Le mot capitalisé qui précède la virgule est maintenant couvert, **avec** le
prénom, quand le prénom du gazetteer qui suit est lui-même suivi d'une ponctuation (`( , ; : - — – .`), d'un chiffre ou de la fin de ligne : jamais quand
une phrase continue en minuscules (« Rappel, Odette doit venir », « Paris, Pierre est venu hier »), et jamais derrière une formule d'adresse ou de
liaison (« Bonjour, Odette », « Merci, Odette », « Cordialement, Odette », « Oui, Pierre est là », « Alors, Marie arrive »…). L'entité couvre « Marchetti,
Odette » ; la virgule est ignorée pour l'identité, donc « Marchetti, Odette » et « Odette Marchetti » reçoivent **le même jeton**. Tests d'abord (10 rouges
sur 18) ; 8 contre-exemples intacts ; 3 896 textes de corpus : 0 changement (les corpus ne contiennent pas cette forme) ; banc inchangé octet pour octet ;
1243 tests ; coût linéaire (×1,6 sur 100 000 mentions « Aa, Marie », dû aux entités en plus). **Faux positifs connus** : un mot capitalisé hors liste
suivi d'une virgule puis d'un prénom en fin de proposition (« Rappel, Odette. » → « Rappel » masqué) ; la formule « Cher Pierre » masquait déjà « Cher »
avant cette tâche (règle bidirectionnelle). **Non traité** : « Nom, Prénom » dont le prénom n'est pas au gazetteer (« Marchetti, Zorglub »), la forme à
initiales « O. Marchetti » (un nom après une initiale isolée est trop souvent une fin de phrase : « vitamine B. Le patient… »), « mme marchetti » tout en
minuscules.

#### 5.2.12 Relecture indépendante : sur-masquages, coûts et fuites

**Initiales après une civilité, variantes de « date de naissance » (P2-75, P2-76).** Premier lot issu d'une **relecture adverse par un relecteur indépendant** (un
« sage », 200 sondes synthétiques, 1ᵉʳ novembre 2026) ; chaque point est reproduit avant correction. *P2-75* : « Dr A. Faure a prescrit » donnait « [NOM_1]. Faure a
prescrit » — l'initiale masquée, le **patronyme en clair** (inversion), alors que « Dr M. Dupont », « M. J. Dupuis », « Mme M.-C. Roux » sont la forme usuelle des
soignants cités. Après une civilité, de une à trois initiales (« A. », « J.-P. », « A. B. ») font maintenant partie du nom ; sans patronyme derrière
(« Mme B. a refusé »), le comportement est inchangé ; le patronyme seul alimente la seconde passe (« Dr Faure » plus loin = même jeton). *P2-76* : « DN
12.09.1938 », « D.N. : 12/09/1938 », « Date nais. 12/09/1938 », « née 12/9/1938 » (sans « le »), « né à Lyon 12/09/1938 », « n. le 12 sept. 1938 » (mois abrégé
suivi d'un point) et « âge : 87 ans (12/09/1938) » laissaient la date **en clair** ; elles sont maintenant des contextes de naissance ; la date doit toujours
suivre (« DN 12 », « Né 3 fois », « Date nais. inconnue », « Rendez-vous le 12/09/2026 » restent intacts). **Analyse bénéfice / risque** : la fuite (patronyme d'un
soignant, date de naissance complète) est directe et fréquente ; le risque de faux positif est nul pour les initiales (ancrées sur une civilité) et borné pour
les dates (un contexte de naissance est toujours exigé, la forme de date aussi). Tests d'abord (21 rouges sur 35) ; 3 896 textes de corpus : 0 changement ; banc
inchangé octet pour octet ; 1278 tests ; coût linéaire (0,9 Mo en 2,1 à 4,0 s). **Non traité, décision motivée** : un nom en minuscules après `mme`, `mr`, `m.`
(« mme roux a chuté ») — sans majuscule, rien ne distingue un patronyme d'un mot courant (« mme est partie »), le faux positif serait massif ; les initiales
isolées sans civilité (« N. Haddad », « Girault N. ») sauf en signature — trop souvent une fin de phrase (« vitamine B. Le patient… »).

**Sur-masquages fréquents (P2-77).** Deuxième lot de la relecture adverse indépendante (un « sage » chargé des faux positifs, ~370 phrases) ; chaque cas est reproduit
avant correction. Étaient masqués à tort, au point de dégrader le prompt : (1) la **fonction** après une civilité — « Madame la Directrice a signé », « Monsieur le
Président de la République », « Madame le Maire » ; (2) un **mot de statut** — « Mme Décédée », « Madame Âgée de 82 ans », « Mme Aidante principale », « M. Bénéficiaire
du RSA » ; (3) la **situation familiale** — « Famille Monoparentale / Recomposée / Nombreuse », « Père Divorcé », « Époux Décédé » ; (4) un champ d'état civil — « Situation
familiale : **Marié**, deux enfants » (« Marié » vaut « Marie » une fois les accents ôtés) ; (5) un **jour ou un adverbe** avalé avec le prénom — « Lundi Marie viendra »
donnait « [NOM_1] viendra », la date disparaissait ; (6) les **toponymes « Saint-… »** — « Saint-Denis », « Seine-Saint-Denis », « Saint-Malo » ; (7) les **éponymes
médicaux** — « Maladie de Charcot-Marie-Tooth », « Syndrome de Gilles de la Tourette » ; (8) un **numéro de lot** au format d'une plaque — « Numéro de lot : AB-123-CD ».
**Maintenant** : (1) après une civilité, un article en minuscules (`le`, `la`, `les`) n'ouvre jamais un nom (« de la Fontaine » et « La Fontaine » restent des noms) ; (2) à
(4) une liste de 60 mots de statut est exclue de la civilité, des mots de parenté et de la règle du prénom ; (5) jours, mois, adverbes de temps (`hier`, `demain`,
`ensuite`) et formules de politesse (`merci`, `bonjour`) ne sont plus pris pour le patronyme voisin d'un prénom — le prénom reste masqué, le jour reste lisible, et
« Merci Pierre Dupont » masque toujours « Pierre Dupont » (le voisin de droite) ; (6) un mot qui commence par `Saint-` ou `Sainte-` ou contient `-Saint-` n'est pas un prénom ;
(7) un mot qui suit « maladie / syndrome / trouble / échelle / test / score / loi / indice / signe » + `de`, `de la`, `d'` n'est pas un prénom ; (8) une plaque précédée de « lot »,
« série », « référence », « modèle », « article », « code » n'en est pas une. **Analyse bénéfice / risque** : chaque exclusion retire du texte masqué un mot qui n'identifie
personne et que le LLM utilise (la fonction, la date, le statut) ; le risque est une fuite si un vrai patronyme coïncide avec un de ces mots (« Mme Seul », « Mme Cadet » sont
possibles) — il est jugé faible et borné aux seuls cas où la civilité est directement suivie du mot. **Changement de comportement à connaître** : les communes
« Saint-… » étaient masquées **par accident** (« Étienne », « Jean », « Denis » sont des prénoms) alors que toutes les autres communes restaient en clair, conformément à la
politique du projet (le lieu est un quasi-identifiant évalué par le rapport de risque, § 3, et non masqué par la détection). Elles restent maintenant en clair comme les autres :
10 textes du corpus de quasi-identifiants changent pour cette seule raison, tous « demeure à Saint-Étienne » ; le rapport de risque, qui lit le texte, est inchangé (tests verts).
Tests d'abord (32 rouges sur 46, 13 témoins qui prouvent que les vrais noms restent masqués) ; 3 896 textes de corpus : 10 changements, tous la raison ci-dessus ; banc inchangé
octet pour octet ; 1324 tests, tous les paquets verts. **Non traité** : titres de structure qui contiennent un prénom (« Foyer Jean Moulin », « Rue Victor Hugo » restent masqués
en NOM, par prudence), mots de fête (« Noël »), noms de marques (« Le Robert »), éponymes médicaux hors cues (« le docteur Alzheimer » reste un nom, il l'est).

**Coût d'une chaîne de particules et de balises ouvertes (P2-79).** Troisième lot de la relecture indépendante (le « sage » chargé du code), **défaut bloquant**
introduit par moi en P2-53 et P2-54 : une chaîne de particules en majuscules ou en minuscules prenait un temps polynomial dans les règles « nom devant `<adresse>` a
écrit » (P2-53) et « signature après une formule de clôture » (P2-54), parce que `_unite` répétait les particules **sans borne**. Mesuré avant correction : `Van Der ` × 80
(**640 octets**) = 14,8 s ; × 250 (2 Ko) = 50 s ; `de la ` × 4 000 (24 Ko) = 11 s ; 10 Ko = 53 s par `Ecluse.redact` ; 1 Mo ne se termine pas. Un seul message de
cette forme gelait l'application (déni de service local). Ma batterie de coût de P2-53 et de P2-58 ne contenait ni particules répétées ni balises ouvertes ; elle en contient
maintenant. **Correctif** : au plus **trois particules d'affilée** (`{0,3}`) — « de la », « van der », « de la Ben » tiennent en trois ; une chaîne plus longue n'est pas un nom.
Même défaut de borne ailleurs, corrigé dans la foulée : `<prenom ` sans `>` (balise XML de clé de données, P2-61) était quadratique (`[^>]*` → `[^>\n]{0,200}`) ; l'extracteur
docx/odt (`<[^>]*>`, `ecluse_ingest`) l'était aussi sur un XML mal formé : 50 000 `<` sans `>` = 20 s, 100 000 = 70 s, donc un `document.xml` mal formé gelait l'ingestion
(`<[^<>]*>`, linéaire). Mesuré après : 640 octets en 0,0 s ; 24 Ko en moins d'une seconde ; 100 000 `<` en moins de 3 s (test). Tests d'abord (7 + 2 tests de coût) ; 3 896 textes de
corpus : 0 changement ; banc inchangé octet pour octet ; redact 1285 tests, ingest 158. **Analyse bénéfice / risque** : le bénéfice est de supprimer un déni de service d'une
chaîne de 640 octets ; le risque, qu'un nom portant plus de trois particules ne soit plus reconnu en entier (aucun cas réel connu ; « de la », « van den », « von der » en font deux).
**Leçon de méthode** : toute répétition `(...)*` ou `(...)+` d'un sous-motif qui peut se recouvrir lui-même doit être bornée, et la batterie de coût d'une règle doit contenir la
répétition de son propre motif.

**Identifiants administratifs sans « n° » (P2-80).** Fuite signalée par la relecture indépendante (« sage » n° 1), reproduite avant correction : « Caisse : CPAM 49, **dossier
4900123456** », « **dossier APA 2026/0412** », « **N° résident : 000123** », « **Plan d'aide n° PA-2026-0042** » restaient en clair, alors que « dossier n° 2024-0412 »,
« N° de dossier », « adhérent n° » l'étaient depuis P2-57. Ajoutés : les étiquettes « n° de résident / usager », « Plan d'aide n° », et « dossier » **suivi directement d'une
valeur** (« dossier 4900123456 », « Référence dossier : AB-2026-00412 »). Garde-fous, plus stricts que pour les formes avec « n° » : au moins **six chiffres**, jamais une date
(`dossier du 12/03/2026`), jamais un mois d'année (`dossier 2024-04`), jamais une année seule (`Dossier 2024`), jamais un mot (`dossier en cours`, `Dossier médical complet`). Même
type `identifiant` que P2-57 (aucune API modifiée). Tests d'abord (8 rouges sur 21) ; 12 contre-exemples intacts ; 3 896 textes de corpus : 0 changement ; banc inchangé octet pour octet ;
1352 tests ; coût linéaire sur 5 entrées jusqu'à 1,1 Mo (2,2 à 3,7 s). **Analyse bénéfice / risque** : bénéfice, des numéros de dossier ou de résident qui identifient une personne
auprès d'un organisme ; risque, un nombre à six chiffres ou plus derrière le mot « dossier » qui ne serait pas un identifiant de personne (un numéro de lot de documents), masqué à
tort sans conséquence pour le sens. **Non traité** : « Réf. : 884412 » (une référence n'est pas forcément personnelle), « Numéro de sécurité : 12345 » (cinq chiffres),
identifiants sans aucune étiquette.

**Colonne « Date de naissance » d'un tableau (P2-78).** Fuite signalée par la relecture indépendante (« sage » n° 1), reproduite avant correction : dans un
tableau CSV, TSV, Word, ODT ou HTML à en-tête, la colonne « Date de naissance », « Naissance », « Né(e) le », « DDN », « DN » ou « DOB » restait **en clair**
(`Nom⇥Prénom⇥Né(e) le⇥Tél` / `ROUX⇥Hélène⇥12/03/1938⇥0612345678` donnait la date intacte) : les noms de colonnes étaient lus (P2-61), pas les dates, faute de contexte de
naissance dans la cellule. Les tableaux étant le format dominant des plannings et des fiches, c'est une fuite fréquente. **Maintenant**, le contexte de naissance est l'en-tête
de la colonne : chaque cellule de cette colonne qui est une date entière (`12/03/1938`, `12-03-1938`, `12.03.1938`, `1938-03-12`, `12 mars 1938`) est masquée comme date
de naissance ; une cellule vide ou qui n'est pas une date (« inconnue ») est laissée. Une colonne « Date de visite », « Date d'entrée » ou « Date de péremption » n'est jamais
lue. Le même refus explicite que pour les noms s'applique (`TableauAmbiguException` si une rangée n'a pas le nombre de colonnes de l'en-tête). Tests d'abord (11 rouges sur 17) ;
6 contre-exemples intacts ; 3 896 textes de corpus : 0 changement ; banc inchangé octet pour octet ; 1302 tests ; coût linéaire sur 4 entrées jusqu'à 1,8 Mo (1,5 à 4,8 s).
**Analyse bénéfice / risque** : le bénéfice est la fermeture d'une fuite directe de la date de naissance complète ; le risque est un faux positif sur une colonne nommée
« Naissance » qui contiendrait une autre date (négligeable : une colonne de ce nom contient la naissance). **Non traité** : en-tête sur une autre ligne que la première
rangée, dates abrégées sur deux chiffres d'année dans une colonne sans contexte, colonnes de naissance dans une langue autre que le français ou l'anglais.

**Signature avec initiale, nom de naissance « (ex-X) » (P2-81).** Deux fuites sûres signalées par la relecture indépendante (« sage » n° 1), reproduites avant correction : (1) la
signature « N. Haddad » (ou « Haddad N. ») derrière une formule de clôture laissait le nom en clair, l'initiale empêchant la règle de P2-54 ; (2) « Mme Roux (ex-Garnier) » masquait
« Roux » et laissait « Garnier », nom de naissance, un identifiant fort. **Maintenant** : la ligne qui suit une formule de clôture accepte de une à deux initiales devant le nom, ou
une initiale derrière (« A. B. Quenelle », « J.-P. Zxqvlorn », « Haddad N. ») ; « (ex-Garnier) », **entre parenthèses seulement**, est traité comme « née Garnier ». Hors parenthèses,
« ex-patient », « ex-fumeur », « l'ex-Yougoslavie » ne sont jamais des noms ; « Mme Roux, ex-Garnier » (sans parenthèses) reste non traité, volontairement. Tests d'abord (6 rouges sur 11) ;
contre-exemples intacts ; 3 896 textes de corpus : 0 changement ; banc inchangé octet pour octet ; 1359 tests ; coût linéaire sur 4 entrées jusqu'à 1,6 Mo (2,3 à 19 s : 100 ms par millier
de « Van Der » sur une même ligne, linéaire de 25 000 à 100 000 répétitions). **Analyse bénéfice / risque** : bénéfice direct (nom de soignant, nom de naissance) ; risque d'un faux
positif sur « (ex-Marseille) », parenthèse rare, jugé acceptable.

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

**La table de correspondance : opaque, non chiffrée, non conservée (P2-193).**
`RedactResult.mapping` est une `TableDeCorrespondance` (plus un
`Map<String, String>`) : `print`, interpolation, message d'exception ou
`toString` ne montrent que le nombre de jetons, `jsonEncode` la refuse, elle n'a
pas d'`==`, et `vider()` en efface le contenu. Ce que cela **ne** fait **pas** :
elle n'est **pas chiffrée**, et il n'y a rien à chiffrer au repos puisque rien
n'est écrit sur disque ni conservé (ni la table, ni le dossier, § ci-dessous) ;
chiffrer une structure en mémoire ne protégerait pas de quelqu'un qui lit la
mémoire du processus (décision du 15 novembre, `DECISIONS.md`). L'opacité
protège de l'affichage accidentel, pas d'un appelant qui lit volontairement
`entrees` ou `[]`. Rupture d'API assumée en 0.2.0 : `Ecluse.restore` et
`restoreAvecRapport` exigent le nouveau type ; une table construite à la main
passe par `TableDeCorrespondance.depuis(carte)`. La recopie de la carte
laisse la carte d'origine en clair chez l'appelant qui la possédait.

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
jamais `[NOM_1]`. Effet de bord de P2-31, **corrigé en P2-72** : une barre oblique
inversée placée devant un jeton exact était consommée avec lui (voir P2-72).

**Fonction courte avalée dans le nom, ligne de planning (P2-186, corrigé).**
Dans une ligne de planning relue sans séparateurs (texte issu d'un tableau à
barres disparues, ex. OCR), une fonction courte en capitales collée au
prénom (« LEFÈVRE Olivier AS 02 61 91 76 57 ») pouvait être avalée dans
l'étendue du nom : la règle bidirectionnelle prénom connu / mot capitalisé
adjacent ne distinguait pas une fonction d'un patronyme. Deux mentions de la
même personne avec une fonction différente d'une ligne à l'autre (« ASH »
puis « AS ») recevaient alors des valeurs différentes, fusionnées en une
seule identité par inclusion de segments ; la restauration réinjectait la
forme la plus longue sur la mention qui n'avait jamais perdu sa fonction —
**troisième cas** de restauration non octet-pour-octet, celui-ci une
véritable rupture (du texte apparaissait en double : « LEFÈVRE Olivier AS
ASH »), pas seulement une harmonisation de graphie. Corrigé en ajoutant `AS`
et `ASD` à la liste des sigles exclus de `NameDetector` (qui protégeait déjà
`ASH`, `AMP`, `IDE`). **Limite résiduelle** : la liste reste fermée — une
fonction courte en capitales absente d'elle (variante locale non vue,
nouvelle abréviation de poste) reproduirait le même défaut ; aucune règle
générale (longueur du mot, présence d'un nombre juste après) n'a été
retenue pour ne pas élargir à l'aveugle le risque de perdre un vrai
patronyme court.

### 5.4 Portée du rattrapage des mentions partielles

Les mentions partielles sont rattrapées **uniquement via un patronyme établi
dans le document courant** — jamais de liste externe, jamais
d'apprentissage ; seule exception, la liste que l'application donne elle-même au
`Dossier` (P2-243, § 8). Limites de cette approche :

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
- *Derrière une tournure de personne (P2-220)* : « le dossier de X », « à la
  demande de X », « l'entretien avec X » et « X a confirmé » masquent le mot
  capitalisé, avec ou sans dossier (patronyme seul : 112 manqués sur 116 avant,
  4 après, corpus de dossiers réaliste, `Ecluse.redact` document par document).
  **Coût, mesuré sur le témoin de P2-218 (400 phrases sans nom de personne) :
  80 phrases sur 400 (20 %) masquées à tort, alors que la fiche en tolérait 1 %.**
  Toutes sont un nom commun écrit avec une majuscule derrière la tournure (« le
  dossier de Presse », « Succès a confirmé »). Les mots de rôle et de parenté
  (« Madame a confirmé », « l'entretien avec Mère », « le dossier de Tuteur »)
  sont, depuis P2-227, en clair (96 sur 96 masqués à tort au témoin de P2-226
  avant, 0 après) : liste fermée de civilités, de parenté et de fonctions
  soignantes et sociales, plus les terminaisons de métier (« -thérapeute »,
  « -logue », « -iatre », « -phoniste », « -pédiste »). Un rôle hors des deux
  (« Aidant », « Veuve », « Concierge ») reste masqué ; un mot de rôle suivi
  d'un nom (« Tante Quenelle ») laisse le rôle en clair et masque le nom ; un
  patronyme identique à un mot de la liste n'est plus rattrapé par la tournure
  seule (« Parent », « Cousin » et « Neveu » en sont exclus pour cette raison).
  Les organismes de la liste
  fermée de P2-229 (« France Travail », « Emmaüs », « Assurance Maladie », les
  sigles CAF, CPAM, URSSAF, MSA…) sont en clair derrière ces tournures (86 sur
  96 masqués à tort au témoin de P2-226 avant, 43 après) ; les **marques
  commerciales** (« Doctolib », « SNCF », « Amazon »…) et tout organisme hors
  liste restent masqués, dans le doute. Un organisme suivi d'un nom (« Emmaüs
  Quenelle ») masque le nom.
  Pour les autres mots : sans dictionnaire, rien ne le
  distingue d'un patronyme. Minuscule (« dossier de presse »), organisme précédé
  de son article (« de la Mairie », « La Mairie a confirmé ») et mots neutres ne
  sont pas masqués. Une commune de **100 000 habitants et plus** (table
  `communes_grandes.dart` générée du référentiel, 58 noms, les communes sans
  population renseignée comprises : Paris, Lyon, Marseille, Mayotte) n'est
  écartée qu'après « à la demande de » (« à la demande de Paris » reste en clair,
  P2-228 ; le seuil était de 10 000 habitants, relevé par P2-239 sur décision du
  mainteneur du 20 novembre). Derrière les trois autres tournures, elle est
  masquée comme un nom, dans le doute : **coût mesuré, 60 phrases `lieu` sur 100
  du témoin de P2-218 masquées à tort** (toutes celles de ces trois tournures :
  « le dossier de Besançon », « Paris a confirmé »), plus une marque qui est aussi
  une commune (« Orange »). **Coût assumé du seuil de 100 000** : une ville de
  10 000 à 100 000 habitants est masquée derrière « à la demande de » (« à la
  demande de Vesoul » : 60 sur 60 au témoin de P2-238, 20 par tranche de
  population ; il ne contient aucune personne, c'est de la lisibilité perdue, pas
  une fuite). En échange, un patronyme qui est aussi le nom d'une commune de
  10 000 à 100 000 habitants (« à la demande de Gaillard ») est masqué : la
  fuite connue de P2-228 (24 sur 24 au témoin de P2-226 pour cette tournure) est
  supprimée. Reste en clair, et c'est alors le même défaut en sens inverse, le
  patronyme qui est aussi une commune de **100 000 habitants et plus** (« à la
  demande de Rouen » : lu comme un lieu) ; le témoin de P2-226 n'en contient pas.
  Un petit nom de commune (« Quingey »)
  est masqué, dans le doute. Un couple
  « Prénom inconnu Nom a confirmé » reste en clair (le mot capitalisé devant le
  sujet écarte la règle : « France Travail a confirmé » en est la raison) ; devant
  « dossier de », le couple de deux mots est masqué. « Le Gall a confirmé » n'est
  pas lu (article capitalisé en tête, comme « La Mairie »).
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

- Généralisation **automatique** du texte envoyé : le moteur ne généralise
  jamais de lui-même. L'application peut appliquer les suggestions du rapport
  de risque (`appliquerGeneralisations`, P2-92) ; c'est irréversible, voir § 7.
- Dictée vocale.
- Journal de l'aperçu : `Apercu.applique` ne laisse aucune entrée dans le
  journal d'audit (décision P2-08 n° 5) ; seul `Ecluse.redact` en laisse.
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
- Signal « à vérifier » de l'aperçu (P2-232) : `EntiteProposee.aVerifier`
  (et `Proposition.aVerifier`, la liste des identifiants) est vrai quand la
  **seule** preuve d'un nom est une tournure de personne (« le dossier de X »,
  « X a confirmé »), ou une autre occurrence du même mot : ni civilité, ni
  couple prénom + nom, ni champ étiqueté, ni patronyme établi ailleurs, y
  compris dans un document précédent du dossier. **C'est une information, pas
  un jugement** : « à vérifier » ne veut pas dire « probablement faux ». Sur le
  témoin des tournures (P2-226, 480 documents, une phrase par mot, chemin
  `Apercu.propose`), 307 noms sont proposés et les 307 sont signalés : 168 sont
  de vrais patronymes, 139 sont des mots qui ne sont pas des personnes. Le
  signal ne sépare donc pas le vrai du faux ; il dit seulement qu'un seul indice
  soutient le nom. Sur le corpus v3 (1 000 documents), 415 noms sont proposés,
  aucun n'est signalé (aucune tournure dans ce corpus). **Tout reste masqué par
  défaut** ; le signal ne démasque rien, et refuser à tort un nom signalé le
  laisse en clair chez le tiers. L'aperçu reste un confort, pas une garantie :
  aucun utilisateur n'a vu ce signal, et rien ne mesure qu'il aide à trier. Il
  n'entre ni dans le journal d'audit (aucun compte « à vérifier »), ni dans
  `descriptionMoteur`, ni dans la version du moteur ; `Ecluse.redact` ne change
  pas d'un octet.

Voir `ROADMAP.md` pour le calendrier de ces briques.

## 7. Estimation de ré-identification (`ecluse_reid`, `ecluse_reference`)

**Faux quasi-identifiants (P2-136).** Une durée (« signé pour 9 ans »,
« il y a 3 ans ») n'est plus lue comme un âge, et une commune homonyme d'un
mot courant (« Tours de garde ») ne compte comme lieu qu'après une
préposition de lieu. Corpus témoin de QI : 412 extractions à tort → 57.
Depuis P2-142, un lieu d'événement introduit par « aura lieu à », « se
tiendra à », « organisé à »… n'est plus compté (témoin : 57 → 0). **Reste** :
un lieu d'événement formulé autrement (« réunion à Brest jeudi ») est encore
compté comme lieu d'une personne.

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
- **Âges écrits** (P2-159) : sont lus « 72 ans », « soixante-douze ans » (2 à
  120, avec « et », trait d'union ou espace, « quatre-vingt(s) », « cent »),
  et la tranche « de 80 à 85 ans » / « entre 60 et 65 ans » (une tranche, pas
  deux âges). **Non lus**, choix de produit : « la soixantaine », « octogénaire »,
  « dans sa quatre-vingtième année », « septante / huitante / nonante ».
  Une durée précédée d'une préposition (« depuis trente ans ») ou suivie de
  « de / d' » (« de 2 à 3 ans de suivi ») n'est pas un âge ; **« Suivi de 2 à
  3 ans. »** (sans rien après) est lu comme une tranche d'âge : indiscernable
  d'un âge sans contexte.
- **Durées lues comme un âge** (P2-165) : « N ans », en chiffres ou en
  lettres, n'est pas un âge après « au bout de », « voilà », « cela fait »,
  « d'ici », après un nom d'engagement (« un contrat / bail / mandat / stage
  de trois ans ») ni devant « plus tard », « plus tôt », « auparavant » ou
  « de prison / de suivi / d'ancienneté / d'expérience… » (liste fermée).
  Corpus témoin de durées : 400 extractions à tort sur 400 documents → 53.
  **Choix assumé** : en cas de doute, la durée est lue comme un âge (le risque
  est surestimé) plutôt que l'inverse. Restent donc lus comme un âge : « le
  service fêtera ses vingt ans » (indiscernable de « fêtera ses 80 ans »),
  « 3 ans après », « 5 ans de » suivi d'un nom hors liste, et toute durée
  sans tournure reconnaissable.
- **Données embarquées** : millésimes mélangés (populations communales
  2023→2026, pyramide 2026 France entière) ; provenance et licence documentées
  dans `DATA_SOURCES.md` et `NOTICE`. Les données restent sous la Licence Ouverte
  v2.0 de leurs producteurs (non relicenciées sous Apache 2.0) ; la redistribution
  d'extraits transformés a été décidée par le mainteneur le 25 octobre 2026, sans
  avis juridique extérieur. La date de téléchargement d'origine des assets n'a pas
  été enregistrée.

### Ce qui sort à côté du texte : `toString`, messages d'erreur et trace d'audit (P2-169, P2-170, P2-172)

Une application qui appelle `ecluse_reid` ou `ecluse_reference` directement
peut écrire un de leurs objets dans un journal, ou envoyer une exception à
son outil de suivi d'erreurs. Depuis P2-170 :

- `Qi.toString` rend le type, le niveau et la longueur de la valeur ;
  `Generalization.toString` s'appuie dessus ; `BirthDate.toString` ne rend
  aucune composante ; `PathologieMention.toString` rend les bornes, la source
  et le rattachement, ni le texte ni la catégorie.
- Les `ArgumentError` de l'estimateur (âge, commune, code de profession), de
  `GeoHierarchy.populationOfDep` (département) et de `BirthDate` (date
  inexistante) ont un motif fixe, sans la valeur reçue. Le motif
  « estimation impossible : … » d'une évaluation, qui recopie ce message,
  n'en porte donc plus non plus.
- `ReidTrace.toAuditMap` (la carte destinée à une preuve conservée) ne porte
  plus de valeur depuis P2-172 : `qisInitiaux` donne, par quasi-identifiant,
  le type et le niveau de généralisation. **Le format de `qisInitiaux` a
  changé** (une carte `{type, niveau}` par QI au lieu d'une chaîne).
- **L'effectif F ne sort plus par ces canaux** (P2-176) : ils donnent la
  **tranche de risque** (élevé, moyen, faible) à sa place.
  `ReidEstimate.toString`, `Generalization.toString` et `ReidTrace.toString`
  n'écrivent plus F. Dans `toAuditMap`, **le format a changé** : la clé
  `fInitial` disparaît (`bandeInitiale` reste), `fAvant` et `fApres` de
  chaque candidat deviennent `bandeAvant` et `bandeApres`, `raisonDuChoix`
  dit « F remonte » ou « F ne remonte pas » avec les deux tranches, et la
  note de plafonnement ne cite plus la population du lieu (elle change donc
  aussi dans `ReidEstimate.notes`). Les seuls nombres de la carte sont les
  niveaux de généralisation et le seuil visé. Cette carte n'a pas de numéro
  de version de schéma, et celui d'`ecluse_audit` (§ 8) n'est pas concerné.
  **Ce que la tranche ne dit plus** : deux estimations de la même tranche ne
  se distinguent plus dans la trace ; une preuve qui doit montrer de combien
  F a remonté doit garder les champs numériques elle-même, en connaissant
  le risque ci-dessous.

**Reste** :

- Les **champs** portent toujours la valeur (`Qi.value`,
  `PathologieMention.text`, `BirthDate.year`…) : c'est leur rôle. Une
  application qui les écrit elle-même dans un journal les y met.
- Les **champs numériques** portent toujours l'effectif F
  (`ReidEstimate.f`, `fBefore` et `fAfter` d'une généralisation ou d'un
  candidat) : l'application en a besoin pour décider. Pour un lieu seul, F
  est la population légale de la commune, et ce nombre désigne souvent la
  commune : dans `geo_communes.csv.gz`, il est unique en France pour 2 964
  communes sur 34 855 (8,5 %) et unique dans son département pour 24 416
  (70,1 %). Une application qui écrit F dans un journal peut donc y écrire
  la commune.
- `ReidTrace.explainNarrative` cite **volontairement** les valeurs (commune,
  âge, profession) et l'effectif F : c'est le récit rendu à l'application
  pour un lecteur humain. L'écrire dans un journal y met ces valeurs.
- `ageOn` cite la date de **référence** (fournie par l'application, pas tirée
  du texte) quand elle précède la naissance.
- Les motifs et avertissements d'une évaluation, et les limites du rapport de
  risque, nomment volontairement un lieu ou une pathologie restés en clair :
  ils sont rendus à l'application pour l'utilisateur, pas à un journal.

### Généralisation appliquée (P2-91, P2-92)

- **Suggestions** : `RiskReport.suggestions` liste les paliers d'un cran qui
  font remonter F, positionnés dans le **texte masqué**. Ce sont des
  propositions ; rien n'est appliqué sans appel explicite.
- **Irréversible** : `appliquerGeneralisations` remplace le QI par son palier
  (« département 57 », « 70-74 ans », « médecin (toute spécialité) »). La
  valeur d'origine n'entre pas dans la table : la restauration rend la forme
  généralisée. Les jetons et la table ne changent pas.
- **Libellés envoyés tels quels** : un retrait s'écrit « (âge retiré) » ou
  « (profession retirée) » dans le texte qui part chez le tiers.
- **F recalculé, pas garanti** : le rapport est recalculé sur le texte
  généralisé. Depuis P2-102, les tranches d'âge (« 70-74 ans ») et les
  professions généralisées (« médecin (toute spécialité) ») se relisent à
  leur palier ; avant, la mesure P2-93 trouvait F inchangé ou en baisse dans
  6 documents sur 170 (réaliste), 32 documents adversariaux devenus non
  évaluables, et un bouclage sur les âges de 100 ans et plus. Le lieu
  généralisé (« département 57 ») n'était pas relu non plus (P2-103 : F
  surestimé, médiane ×157, bande « faible » au lieu de « moyen ») ; il l'est
  depuis P2-116 : sur les 24 cas mesurés, F recalculé = F simulé. Depuis P2-132,
  la préposition qui précède est réécrite avec le lieu (« habite à Rioz » →
  « habite dans le département 70 », « vient de Rioz » → « vient du
  département 70 ») ; une autre tournure garde le libellé seul. **Reste** : le
  palier France n'est pas relu, ce qui revient à l'absence de lieu.
- **Rien n'est signalé dans `warnings`** : c'est l'application qui sait
  qu'elle a généralisé.

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

**Branchement (P2-96, décisions P2-96a)** : `Ecluse.redact(journal: …)` écrit une
entrée par appel avant de rendre le résultat, et avant tout changement d'un
`Dossier` ; si l'écriture échoue, l'exception remonte et rien n'est masqué. La
description du moteur est construite par Écluse (version et noms des détecteurs
actifs). `JournalAudit` sérialise les écritures : la chaîne reste linéaire sous
appels concurrents, et un échec d'écriture ne la fait pas avancer. Un refus de
secrets (`refuseSecrets`) laisse une entrée `secrets_refused` avec le nombre de
secrets : c'est la **version 2** du schéma ; les entrées de version 1 restent
vérifiables. Ce que le branchement ne fait pas : journaliser l'aperçu, les
appels à `restore`, ni les refus d'`ecluse_ingest` (l'application peut les
écrire elle-même avec `enregistrerRefusIngestion`).

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

**Changement de moteur dans un journal (P2-202, spec P2-198).** `engine`
(version et détecteurs) reste dans l'empreinte chaînée ; un journal qui mêle
deux versions est valide, `AuditVerifier.verify` n'y change rien. C'est
l'export qui le signale : `AuditExport.moteurs` liste les valeurs distinctes
**dans l'ordre de première apparition** (pas alphabétique : `0.10.0` suit
`0.2.0`), chacune avec son rang (1, 2…) et le **jour** de sa première entrée ;
`changementsDeMoteur` compte les entrées dont `engine` diffère de la
précédente (un retour à une version antérieure compte pour un changement de
plus), et le texte dit « Le moteur a changé N fois pendant la période » dès que
N ≥ 1. **Aucun compte par version** (il serait retrouvé par soustraction,
P2-26) ni rang d'entrée. La comparaison porte sur la chaîne entière : un
changement de détecteurs sans changement de version est aussi un changement, et
une description tronquée à 200 caractères (nombre de détecteurs seul) ne voit
pas une liste qui change à nombre égal. Le journal n'écrit pas d'entrée
« changement de moteur » : le marqueur est déduit à la lecture, il n'est pas, à
lui seul, une preuve. Format de l'export passé en **version 2** (`moteurs` est
une liste d'objets `rang`/`moteur`/`depuis`, nouvelle clé
`changements_de_moteur`).

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

**Restauration sans coût quadratique (P2-82).** `Ecluse.restore` faisait un remplacement par jeton, soit « jetons × taille du
texte » : 12,5 s pour 10 000 mentions et 61,6 s pour 20 000 (mesuré avant correction). Il fait désormais un seul parcours des
segments `[...]` : 188 ms et 328 ms. Si une valeur du dictionnaire contient `[`, `]` ou `\`, l'ancien parcours est conservé, car
l'équivalence n'y est plus garantie. Équivalence vérifiée par un test différentiel contre l'ancien algorithme.

**Valeurs vides d'un champ étiqueté (P2-84).** `Prénom : Non renseigné` masquait « Non » et laissait « renseigné ». Une liste fermée de valeurs vides
(non, inconnu, néant, sans, idem, identique, anonyme, anonymisé, confidentiel, exemple, test, « à compléter »), comparées au mot entier, n'est plus prise pour un nom
derrière `Nom …` / `Prénom …` et les clés de données. Coût de fuite : un patronyme réel égal à l'un de ces mots (« Idem », « Néant »), négligeable.
**Décidé, non traité** (relecture du 1er novembre) : la clé JSON/XML nue `nom` / `name` (arbitrage du 27 octobre : elle désigne aussi un fichier ou un projet) ;
`Nom :` seul sans `Prénom` voisin (conception P2-36).

**Variantes de date de naissance (P2-83).** Trouvées par relecture indépendante, reproduites avant correction : mois français abrégés
(`janv.`, `févr.`, `fév.`, `avr.`, `juil.`, `déc.`, point facultatif), libellés `Naiss.` / `Naiss :` / `Naissance le` / `Naissance du`, et date compacte
`JJMMAAAA` après un contexte de naissance. Le contexte reste obligatoire : une date abrégée sans contexte (« réunion le 12 janv. 2027 ») n'est pas touchée.
**Non traité, décidé** : `Anniversaire :` (vœux et fêtes, faux positifs réels), année à deux chiffres séparée par des blancs (`né le 12 03 50`),
tableau aligné par espaces sans séparateur (colonne introuvable sans analyse de position).

**Quatre coûts quadratiques corrigés (P2-85).** Trouvés par relecture indépendante, mesurés avant correction : un chiffre suivi de milliers de blancs
(`_cleNommee` et adresse : deux `[ \t]*` séparés par un élément facultatif), une longue suite de minuscules suivie d'un point (regard arrière non borné du
séparateur « Prénom.Nom »), `sk-ant-` répété (clé OpenAI), `restore` avec une valeur contenant un crochet inoffensif (`jean[at]example.fr`). Tous ramenés à un coût
linéaire ; une clé OpenAI dont la première partie dépasse 512 caractères n'est plus reconnue (les clés réelles en font moins de 150).
**Mesuré, non traité** : (a) la résolution des jetons garde un coût « jetons × segments `[...]` » (5 000 téléphones + 40 000 crochets : 10 s ; un journal de 1 Mo
avec 80 000 segments : de l'ordre de la minute) ; (b) **la restauration n'est pas toujours identique au texte d'origine** quand deux noms adjacents sont fusionnés en
une seule mention (`Dr Bernard Dr Costa`, `Marie Marie Marie`), ce qui contredit en partie § 5.3 : aucun avertissement n'est émis ; (c) **entités numériques HTML et échappements
`\uXXXX`** (`jean&#46;dupont&#64;example&#46;fr`, `06&#32;12…`) ne sont pas décodés par l'ingestion : l'identifiant correspondant reste en clair, sans avertissement ;
(d) un journal d'audit importé n'est pas validé (`ts` arbitraire, clés de comptes libres) et l'export peut lever une exception.

**Liste de patronymes fournie par l'application (P2-243).** Une application qui
connaît ses patients ou ses salariés avant la première pièce peut les donner au
`Dossier` (`Dossier(patronymesConnus: PatronymesConnus([...]))`, puis
`ajouterPatronymes`). La liste amorce la deuxième passe de `NameDetector` comme un
patronyme établi par une pièce précédente. Ce qu'elle **ne fait pas**, et ce que
l'application déclenche en la fournissant :

- **Le journal ne la voit pas.** Aucun compte, aucun nombre d'entrées ni aucun
  champ ajouté : le schéma d'audit ne change pas (la taille d'une liste de
  patients est elle-même une donnée de l'application), et `descriptionMoteur`
  ne liste que des noms de détecteurs, qui ne changent pas. Une entrée de journal
  ne dit donc pas qu'une liste a servi.
- **Une liste est une liste de mots, pas de personnes.** Un nom qui est aussi un
  mot courant (« Petit », « Marchand », « Boulanger ») ou une commune (« Vesoul »)
  est masqué partout où il s'écrit avec une majuscule ou en capitales, y compris
  dans « Petit déjeuner » ; une commune fournie est masquée (décision du
  21 novembre). Mesure : 265 phrases de leurres, chacune seule dans son dossier,
  sont masquées à tort 265 fois quand la liste contient le mot, 0 fois sinon.
  Aucun budget de faux positifs ne tient pour un mot courant fourni comme nom.
- **Les minuscules ne sont pas amorcées.** La liste n'entre pas dans
  `NomMinusculesDetector` : « le marchand est venu » reste en clair. Un patronyme
  seul écrit en minuscules (texte tout en minuscules) n'est donc pas rattrapé par
  la liste seule.
- **Comparaison mot à mot, sur les formes écrites dans la liste.** Un nom à
  particule (« de La Fontaine ») ou à plusieurs mots ne correspond à rien (la
  liste l'accepte, jusqu'à quatre mots) ; un pluriel, une faute ou une variante
  d'accent ne sont pas rattrapés.
- **Deux noms de la liste côte à côte** (« Verdier Lenoir a confirmé ») donnent
  **un seul** jeton : à la restauration, c'est la forme la plus complète qui est
  écrite.
- **Entrées refusées à la construction**, avec un motif et un nombre, jamais la
  valeur : vide, un seul mot d'une lettre, un sigle exclu du détecteur de noms
  **écrit en capitales** (« EVA », « HTA »), plus de quatre mots. Tout ou rien : une
  entrée refusée et la liste n'est pas construite. **P2-253** : une entrée écrite
  avec une majuscule initiale et des minuscules (« Eva ») est acceptée même si sa
  forme en capitales est un sigle exclu : une patiente prénommée Eva ne rend plus la
  liste entière inutilisable. Dans le texte, « Eva Martin est venue » est masqué ;
  le sigle « EVA 6/10 » en capitales n'est **jamais** masqué à cause de la liste
  (le mot en capitales reste exclu de la deuxième passe). Conséquence : une
  patiente « Eva » écrite en capitales n'est pas rattrapée par la liste seule :
  mesuré, « EVA MARTIN est venue » devient « EVA [NOM_1] est venue » (le prénom
  reste en clair) et « Pour EVA » reste intact. Écrit comme sigle, « EVA » est
  indiscernable d'une échelle de douleur ; c'est le choix du sigle protégé.
- **Aucun gain mesurable sur les corpus de dossiers** : le patronyme seul manqué y
  est déjà à 0 sans liste (P2-220). Le gain existe en première mention sans
  tournure reconnue (corpus `b` : 204 noms sur 400 en clair sans liste, 0 avec la
  liste exacte ou large) ; une liste **sans la bonne personne** ne change rien.
- **Copies.** La bibliothèque n'écrit rien sur disque et efface sa copie à
  `fermer()` ; l'application garde ses propres copies de sa liste, et l'opacité de
  `PatronymesConnus` (`toString`, pas d'`==`, `jsonEncode` refusé) protège de
  l'affichage accidentel, pas de la mémoire du processus.
- **Coût linéaire en la taille de la liste, à chaque pièce** : à 10 000 noms
  distincts, une passe sur 397 documents prend environ trois fois plus de temps
  qu'avec 0 nom (voir `bench/ETAT.md`).


### IBAN à clé fausse écrit en groupes inhabituels (P2-300, 26 novembre 2026)

Un IBAN dont la clé mod 97 est fausse n'est retenu que s'il est écrit en groupes
usuels (4-4-…-4-3, ou la forme RIB 4-5-5-11-2 / 4-5-5-5-5-3) ou sans séparateur.
Écrit en autres groupes (par exemple par trois), il n'est **pas masqué** : sur le
témoin durci cette garde fait passer les faux accords de 10 à 2 documents sur 450
(`Ecluse.redact`), au prix de la sonde « trois » : 0/40 couverts. Ces 40 sont tous
**signalés** (« à vérifier », avertissement sans la valeur) ; aucun identifiant
annoté n'est perdu sur v3, libellé fort, OCR ni 200 000 documents.
Limites : un IBAN à clé fausse **précédé d'un libellé** et écrit en groupes
inhabituels n'est pas exempté de la garde.

**Les trois autres gardes de P2-272 (P2-276) signalent maintenant ce qu'elles
écartent (P2-304).** Un NIR à clé fausse ou un FINESS sans contexte suivi d'un
groupe court à lettre de confusion d'OCR (« … 85 I2 »), et un « code postal + mot
fait de chiffres et de confusions d'OCR commençant par une majuscule » (« 05214
OO1l »), sont pris pour un numéro de pièce plus long et **ne sont pas masqués** ;
`Ecluse.redact` les signale « à vérifier » (type, compte et positions, jamais la
valeur). Sonde de 118 candidats : 0 / 118 signalés avant, 118 / 118 après ; aucun
masquage ne change. Coût : 21 documents sur 5 000 du témoin durci portent cet
avertissement sans aucun identifiant (code pièce de la même forme), 1 négatif sur
1 000 du corpus à libellé fort. **Reste silencieux** (`agent/specs/P2-303.md`) : le
RPPS suivi d'une date, le SIRET et la TVA sans libellé ; chacun est une tâche à part.

**La garde `nir_coupures` signale aussi ce qu'elle écarte (P2-305).** Un NIR à clé
fausse écrit en groupes qui ne sont pas ceux d'un NIR ni cinq groupes de trois
(« 1850 5780 0608 436 ») n'est **pas masqué** ; `Ecluse.redact` le signale « à
vérifier » (compte et positions, jamais la valeur), sauf si une autre entité le
couvre en entier. Sonde de 40 NIR : 0 / 40 signalés avant, 40 / 40 après ; les 642
caractères sur 720 qui restent en clair le restent (aucun masquage ne change : 77
fichiers de prédictions identiques). Coût : 2 documents sur 5 000 du témoin durci
élargi (codes de colis) portent cet avertissement, 0 sur v3, libellé fort et
mots-nombres. Un NIR à clé juste n'est pas concerné (il est masqué).
NIR à clé fausse en groupes qui n'en sont pas (« 1850 5780 0608 436 ») et le RPPS
suivi d'une date ; chacun est une tâche à part.

**Le SIRET sans le mot « siret » et la TVA sans libellé sont signalés (P2-307).**
Quatorze chiffres de **clé de Luhn juste** sans le mot « siret » à moins de 40
caractères, et un numéro de TVA (« FR » + clé + SIREN) à clé fausse ou à lettre
sans « TVA » ni « intracommunautaire », **ne sont pas masqués** : un SIRET
d'entrepreneur individuel identifie pourtant une personne. `Ecluse.redact` les
signale « à vérifier » (type, compte et positions, jamais la valeur), sauf si une
autre entité les couvre en entier. Sonde de P2-303 (chemin `Ecluse.redact`) : 0 / 80
signalés avant, 80 / 80 après ; les 576 caractères sur 680 (SIRET) et 476 sur 520
(TVA) restent en clair : aucun masquage ne change. Quatorze chiffres de clé
**fausse** ne sont pas signalés (rien ne les distingue d'un nombre ordinaire).
Coût du signalement, et de ce que serait le masquage (un masquage porterait sur les
mêmes documents) : 0 document sur 215 080 des témoins (durci élargi 5 000,
mots-nombres durci élargi 5 600, 200 000 phrases sans personne, 480 « commune
suivie », v3 1 000, libellé fort 3 000). Ces témoins ne contiennent aucun
quatorze chiffres de Luhn juste hors libellé : le coût sur des textes naturels
(numéros de suivi, références de 14 chiffres, dont un sur dix passe Luhn) n'est
pas mesuré. La décision de masquer est au mainteneur.

**P2-309 (27 novembre 2026) : un identifiant qui finit au milieu d'une date
complète est signalé.** `DigitCompaction` écarte, pour tous les détecteurs, un
candidat dont les deux derniers chiffres ouvrent une date complète en chiffres
(« NIR 1 85 05 78 006 084 12/03/2024 ») : ses derniers chiffres sont lus comme le
jour de la date. Un NIR, un RPPS ou un FINESS de clé juste écrit ainsi **n'est pas
masqué**. `Ecluse.redact` le signale désormais « à vérifier » (type, compte et
positions, jamais la valeur), sauf si une autre entité le couvre en entier. Aucun
masquage ne change. Sonde de P2-309 (chemin `Ecluse.redact`, identifiants
fabriqués, clés calculées) : NIR 156 / 156, RPPS 160 / 160, FINESS 400 / 400
signalés après, aucun avant (l'avertissement n'existait pas). Un IBAN n'est pas
concerné par les groupements usuels (dernier groupe de trois caractères, ou
paires) : aucun cas constructible. Les candidats de clé fausse ne sont pas
signalés. Coût : 10 documents sur 4 800 du témoin « identifiant suivi » portaient
l'avertissement, tous à tort (l'identifiant réel y est déjà masqué en entier sous
un autre type ; la lecture NIR du même nombre mord sur les chiffres de la date) ;
**2 depuis P2-312** : l'avertissement n'est plus émis quand une entité à confiance
≥ 0,9 masque déjà les chiffres d'identifiant ; les 2 restants (FINESS sans libellé,
confiance 0,5) ont la forme de 16 cas de la sonde RPPS où il est le seul signe d'un
RPPS en partie en clair, et sont conservés ;
0 document sur 14 080 des autres témoins rejoués (durci élargi 5 000,
mots-nombres durci élargi 5 600, « commune suivie » 480, v3 1 000, libellé fort
3 000). Les 200 000 phrases sans personne n'ont pas été rejouées. L'ADELI, qui
passe aussi par la compaction, n'est pas couvert (hors fiche).

---

**Écluse réduit le risque, il ne l'annule pas.**
