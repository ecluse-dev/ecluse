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

/// Formes sans accent des mots neutres (P2-212) : « a », « numero »,
/// « numeros », « salaries », « residents ». Un courrier ou un export en
/// capitales perd souvent l'accent (« 39314 NUMEROS EN ATTENTE ») ; P2-211
/// mesurait 628 / 1 000 phrases masquées en trop à la forme sans accent, 0
/// à la forme accentuée. Calculées depuis [motsNeutres] : une seule liste à
/// tenir. Aucune n'est un premier mot de commune du référentiel versionné
/// (vérifié le 17 novembre) ; `tools/build_communes_nom_exact.py` lit
/// toujours [motsNeutres] seul.
final Set<String> _motsNeutresSansAccent = {
  for (final mot in motsNeutres)
    if (_sansAccent(mot) != mot) _sansAccent(mot),
};

String _sansAccent(String mot) => mot
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

/// Vrai si [bas] (déjà en minuscules) est un mot neutre, avec ou sans accent.
bool estMotNeutre(String bas) =>
    motsNeutres.contains(bas) || _motsNeutresSansAccent.contains(bas);
