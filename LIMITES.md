# Limites connues d'Écluse (v0)

**Écluse réduit le risque, il ne l'annule pas.** Ce document liste ce que la
version actuelle ne fait pas ou ne fait qu'imparfaitement — pour que
personne ne se fie à une couverture que le produit n'offre pas encore.
Afficher une limite est une mesure de sécurité à part entière : un faux
sentiment de protection est pire qu'une absence de protection connue.

## Deux familles de détecteurs, deux niveaux de confiance

- **Validation structurelle** (NIR, RPPS, IBAN, FINESS) : chaque candidat
  est vérifié par sa clé de contrôle (mod 97, Luhn, ISO 7064). Un candidat
  syntaxiquement plausible mais à clé invalide est rejeté. Le taux de faux
  positifs est proche de zéro, et un identifiant détecté est presque
  toujours réel.
- **Heuristiques v0** (nom, adresse, date de naissance, téléphone, email,
  établissement) : aucune structure vérifiable n'existe pour ces types — la
  détection repose sur des motifs et du contexte (civilité, prénom connu,
  mot-clé de voie ou d'établissement), pas sur une clé de contrôle. Ce sont
  des approximations volontairement prudentes (« en cas de doute, on
  masque »), pas des preuves. Elles seront remplacées par un modèle NER
  local en phase 2 (voir `ROADMAP.md`).

Ne pas confondre les deux : un `[NIR_1]` masqué est une quasi-certitude, un
`[NOM_1]` masqué est une estimation.

## Identifiants non couverts

- **BIC** : non détecté (seul l'IBAN l'est).
- Les identifiants professionnels autres que RPPS/FINESS (numéro ADELI,
  identifiants d'établissement autres que FINESS, etc.) ne sont pas
  couverts en v0.

## Lieux et quasi-identifiants

Une adresse postale complète (numéro + type de voie + code postal +
commune) est masquée. Un simple nom de ville ou de lieu, mentionné sans
cette structure (« reçu à Nantes »), ne l'est pas : ce n'est pas un oubli,
c'est que la généralisation géographique (remplacer un lieu trop précis par
une zone plus large) est un traitement différent du masquage, prévu en
phase 2 — voir `ROADMAP.md`. En attendant, un lieu isolé reste un
quasi-identifiant en clair dans le texte envoyé au LLM.

## Fichiers pris en charge (`ecluse_ingest`)

Seuls `.txt`, `.md` et `.docx` sont ingérés en v1. **Le PDF est refusé
explicitement, systématiquement** — y compris un PDF avec une couche de
texte lisible : ce n'est pas encore implémenté, et un fichier refusé vaut
mieux qu'un fichier mal lu. Aucune image, aucun scan, aucun manuscrit
n'est traité : un OCR ou une reconnaissance manuscrite introduirait des
erreurs de lecture qui feraient échouer silencieusement la validation
structurelle (un chiffre mal reconnu dans un NIR le fait rejeter comme
invalide — et donc fuir en clair). C'est une posture assumée, pas une
limite technique temporaire.

## Limites résiduelles connues des heuristiques nom/adresse

- Le détecteur de noms applique une règle symétrique (nom avant ou après
  le prénom reconnu, quelle que soit la casse) : un mot capitalisé non
  nominal mais adjacent à un prénom connu — une salutation ou un
  connecteur en tout début de phrase, par exemple — peut être masqué à
  tort. C'est un compromis délibéré (mieux vaut un faux positif qu'une
  fuite), pas un bug.
- L'exclusion des unités de mesure dans le détecteur d'adresse (pour ne
  pas confondre une posologie du type « 10000 UI » avec un code postal),
  et l'exclusion des sigles cliniques/administratifs dans le détecteur de
  noms (pour ne pas masquer une échelle comme « EVA » qui coïncide avec un
  prénom), reposent chacune sur une liste finie et documentée, pas une
  détection générale : un sigle ou une unité absents de ces listes
  pourraient encore être mal classés.
- Une même personne mentionnée d'abord par son nom complet puis par son
  seul prénom (usage courant dans un compte rendu) reçoit deux jetons
  distincts : les deux mentions sont masquées, mais rien ne signale au
  LLM qu'il s'agit de la même personne.
- **Aucun span détecté (nom, adresse, date de naissance, établissement) ne
  traverse un saut de ligne**, même quand l'entité réelle est
  légitimement coupée par un retour à la ligne du document (une adresse
  ou un nom d'établissement qui continue sur la ligne suivante, par
  exemple). Ce choix évite qu'un span engloutisse par erreur le début
  d'une ligne sans rapport (c'était un bug réel, corrigé), mais il a un
  coût symétrique : dans un document où la mise en forme coupe une entité
  en plein milieu, seule une partie peut être détectée (ou aucune). En
  cas de doute entre « fusionner deux lignes à tort » et « rater une
  entité coupée par la mise en forme », le second risque est jugé
  préférable — mais les deux méritent une vigilance humaine sur des
  documents à la mise en page inhabituelle.
- **La cohérence des pseudonymes a un coût sur la fidélité de la
  restauration.** Quand une même personne est nommée avec un ordre
  nom/prénom différent d'une mention à l'autre (« Dubreuil Thomas » puis
  « Thomas Dubreuil »), les deux mentions reçoivent le même jeton — sans
  quoi le LLM croirait à deux personnes distinctes. Mais la restauration
  ne peut restituer qu'**une seule graphie** par jeton (remplacement
  global dans la réponse du LLM, sans notion de position) : l'ordre de la
  deuxième mention est donc harmonisé sur la première lors de la
  restauration. Aucun caractère n'est perdu ni déplacé ailleurs dans le
  document — seul l'ordre stylistique de cette re-mention change. C'est
  le seul cas connu où le texte restauré n'est pas un octet-pour-octet
  exact du texte d'origine, et c'est un choix assumé (cohérence
  d'identité pour le LLM > fidélité mot-à-mot d'une re-mention).

## Hors périmètre v0

- Pas de score de ré-identification, pas de boucle
  risque → généralise → re-mesure (phase 2).
- Pas de dictée vocale.
- Pas de journal d'audit chaîné et horodaté.
- Le mode par défaut est automatique et invisible ; l'aperçu avec
  validation manuelle avant envoi est une option de confort, pas une
  garantie de contrôle a priori sur chaque détection.

---

**Écluse réduit le risque, il ne l'annule pas.**
