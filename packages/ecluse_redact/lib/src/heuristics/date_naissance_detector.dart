import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique de dates de naissance — **v0 de démonstration**.
///
/// Une date seule (`12/03/1985`) n'indique pas qu'il s'agit d'une naissance :
/// ce détecteur exige un contexte explicite (« né(e) le », « date de
/// naissance », « DDN ») immédiatement avant la date pour limiter les faux
/// positifs. Confiance modérée (0.7) : le contexte est un indice textuel,
/// pas une validation structurelle.
///
/// Formats couverts : `JJ/MM/AAAA`, `JJ-MM-AAAA`, `JJ.MM.AAAA`, et la forme
/// textuelle française `12 mars 1985`.
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
  static final RegExp _pattern = RegExp(
    r'(?:né(?:e)?(?:\(e\))?[ \t]+le|date[ \t]+de[ \t]+naissance[ \t]*:?'
    r'|DDN[ \t]*:?)[ \t]+'
    r'(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{4}'
    '|\\d{1,2}[ \\t]+(?:${_months.join('|')})[ \\t]+\\d{4})',
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
