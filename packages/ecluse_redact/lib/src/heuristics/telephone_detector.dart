import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique de numéros de téléphone français — **v0 de
/// démonstration**.
///
/// Formats couverts : `0X XX XX XX XX`, `+33 X XX XX XX XX`,
/// `+33 (0)X ...` et `0033 X ...`, avec séparateurs espace, point, tiret,
/// espace insécable (NBSP, U+202F) ou sans séparateur. Les numéros courts
/// (15, 112, 3114…) ne sont jamais détectés : le motif exige 10 chiffres.
/// Aucune clé de contrôle n'existe pour un numéro de téléphone : confiance
/// modérée (0.8), le motif étant néanmoins très spécifique.
final class TelephoneDetector implements EntityDetector {
  const TelephoneDetector();

  @override
  EntityType get type => EntityType.telephone;

  /// Séparateur toléré entre groupes : espace, point, tiret, barre oblique,
  /// NBSP, U+202F.
  static const String _sep = r'[ .\-/\u00A0\u202F]';

  /// Préfixe national `0X`, national entre parenthèses `(0X)`, international
  /// `+33 X` / `+33 (0)X` / `0033 X` / `00 33 X`. Le chiffre significatif X
  /// va de 1 à 9 ; `(0)` n'est admis que parenthésé (un `+33 0…` nu n'est pas
  /// un format valide).
  static const String _prefixe = '(?:\\(0[1-9]\\)|0[1-9]|'
      '(?:\\+33|00$_sep?33)$_sep?(?:\\(0\\)$_sep?)?[1-9])';

  static final RegExp _pattern = RegExp(
    '(?<![0-9])(?:'
    // Dix chiffres en groupes de 2 (format courant).
    '$_prefixe(?:$_sep?[0-9]{2}){4}'
    // Format 4-3-3 (« 0612 345 678 »).
    '|0[1-9][0-9]{2}$_sep[0-9]{3}$_sep[0-9]{3}'
    ')(?![0-9])',
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
      results.add(
        DetectedEntity(
          type: EntityType.telephone,
          start: match.start,
          end: match.end,
          value: match.group(0)!,
          confidence: 0.8,
        ),
      );
    }
    return results;
  }
}
