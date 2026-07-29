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
  pas confondre une posologie du type « 10000 UI » avec un code postal) se
  fonde sur une liste finie d'unités courantes (SI, pharmacologie) : une
  unité absente de cette liste pourrait encore être mal classée comme
  adresse.
- Une même personne mentionnée d'abord par son nom complet puis par son
  seul prénom (usage courant dans un compte rendu) reçoit deux jetons
  distincts : les deux mentions sont masquées, mais rien ne signale au
  LLM qu'il s'agit de la même personne.

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
