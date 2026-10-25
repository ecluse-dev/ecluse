import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique de dates de naissance — **v0 de démonstration**.
///
/// Une date seule (`12/03/1985`) n'indique pas qu'il s'agit d'une naissance :
/// ce détecteur exige un contexte explicite (« né(e) le », « date de
/// naissance », « DDN ») immédiatement avant la date pour limiter les faux
/// positifs. Confiance modérée (0.7) : le contexte est un indice textuel,
/// pas une validation structurelle.
///
/// Formats couverts : `JJ/MM/AAAA`, `JJ-MM-AAAA`, `JJ.MM.AAAA` (année sur 2 ou
/// 4 chiffres), ISO `AAAA-MM-JJ`, et la forme textuelle française
/// `12 mars 1985` (dont l'ordinal `1er mars 1985`).
final class DateNaissanceDetector implements EntityDetector {
  const DateNaissanceDetector();

  @override
  EntityType get type => EntityType.dateNaissance;

  static const _months = [
    'janvier', 'février', 'fevrier', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'aout', 'septembre', 'octobre', 'novembre',
    'décembre', 'decembre', //
  ];

  // `[ \t]` plutôt que `\s` partout : une date de naissance (ou son
  // contexte déclencheur « né(e) le ») ne traverse jamais un saut de
  // ligne dans un document réel — `\s` matcherait aussi le saut de ligne,
  // au risque de fusionner deux lignes sans rapport en une fausse date.
  // Les espaces insécables (U+00A0, U+202F) comptent comme des espaces :
  // fréquents dans les exports de traitement de texte.
  static const String _b = '[ \\t\\u00A0\\u202F]';

  /// Lieu de naissance facultatif entre « né(e) » et « le » (« né à Paris
  /// le … ») : 1 à 3 mots, pour ne pas ouvrir la porte à une phrase entière.
  static const String _lieu =
      "(?:$_b+(?:à|au|aux|en)$_b+[\\wÀ-ÿ'’-]+(?:$_b+[\\wÀ-ÿ'’-]+){0,2})?";

  /// Contexte déclencheur : « né(e) [à lieu] le [:] », « date de naissance
  /// [:] », « naissance : » (deux-points obligatoire, sinon « la naissance
  /// du projet »), « DDN [:] », « DOB [:] ».
  static final String _contexte =
      '(?<![\\wÀ-ÿ])(?:né(?:e)?(?:\\(e\\))?$_lieu$_b+le$_b*:?'
      '|date$_b+de$_b+naissance$_b*:?'
      '|naissance$_b*:'
      '|DDN$_b*:?'
      '|DOB$_b*:?)';

  static final RegExp _pattern = RegExp(
    '$_contexte$_b+'
    '(\\d{1,2}[\\/\\-.]\\d{1,2}[\\/\\-.](?:\\d{4}|\\d{2}(?!\\d))'
    '|\\d{4}-\\d{2}-\\d{2}'
    '|\\d{1,2}(?:er|ᵉʳ)?$_b+(?:${_months.join('|')})$_b+\\d{4})',
    caseSensitive: false,
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
      final group = match.group(1)!;
      final start = match.end - group.length;
      results.add(
        DetectedEntity(
          type: EntityType.dateNaissance,
          start: start,
          end: match.end,
          value: group,
          confidence: 0.7,
        ),
      );
    }
    return results;
  }
}
