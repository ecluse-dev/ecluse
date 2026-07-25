import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique de numéros de téléphone français — **v0 de
/// démonstration**.
///
/// Formats couverts : `0X XX XX XX XX` (avec séparateurs espace, point ou
/// tiret, ou sans séparateur) et le préfixe international `+33 X ...`.
/// Aucune clé de contrôle n'existe pour un numéro de téléphone : confiance
/// modérée (0.8), le motif étant néanmoins très spécifique.
final class TelephoneDetector implements EntityDetector {
  const TelephoneDetector();

  @override
  EntityType get type => EntityType.telephone;

  static final RegExp _pattern = RegExp(
    r'(?<![0-9])(?:0[1-9]|\+33[ .\-]?[1-9])(?:[ .\-]?[0-9]{2}){4}(?![0-9])',
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
