/// Mots qui ne commencent jamais un nom de commune ni un nom propre ici :
/// mots outils, unités, monnaie, noms de comptage. Partagés par
/// `MinusculesRecapitaliseDetector` (texte d'ombre, P2-120) et
/// `AdresseDetector` (texte en capitales, P2-122) : écrits « 70000 euros » ou
/// « 70000 EUROS », ils prenaient la forme d'un code postal suivi d'une
/// commune (mesures P2-120 et P2-121 sur le corpus témoin).
///
/// Interne au paquet : non exporté par `ecluse_redact.dart`.
const Set<String> motsNeutres = {
  'le', 'la', 'les', 'l', 'de', 'du', 'des', 'd', 'au', 'aux', 'et', //
  'ou', 'à', 'en', 'sur', 'sous', 'pour', 'par', 'avec', 'sans', 'chez', //
  'vers', 'dans', 'un', 'une', 'ce', 'cet', 'cette', 'ces', 'son', 'sa', //
  'ses', 'leur', 'leurs', 'qui', 'que', 'est', 'sont', //
  'euro', 'euros', 'eur', 'centimes', 'habitants', 'personnes', //
  'patients', 'ans', 'mois', 'jours', 'heures', 'minutes', //
  // Noms de comptage courants après un grand nombre (« 21000 dossiers »,
  // « 39100 numéros », ponctuation perdue) : mesure P2-120, témoin sans
  // ponctuation.
  'dossier', 'dossiers', 'numéro', 'numéros', 'lits', 'places', //
  'agents', 'salariés', 'résidents', 'appels', 'actes', //
  'ui', 'iu', 'mg', 'mcg', 'ng', 'pg', 'ml', 'cl', 'dl', 'kg', 'mol', //
  'mmol', 'meq', 'cm', 'mm', 'km', 'kcal', //
};
