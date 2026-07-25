import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique d'adresses postales simples — **v0 de
/// démonstration**.
///
/// Reconnaît le motif `numéro + type de voie + nom de voie + code postal
/// (5 chiffres) + commune`, par exemple :
/// `12 rue des Lilas, 75015 Paris`. Aucune validation possible (pas
/// d'annuaire des voies embarqué) : confiance modérée (0.7).
///
/// Ne couvre pas les adresses sans code postal, les boîtes postales, ni les
/// formats étrangers. Sera affiné en phase 2 (NER + table INSEE).
final class AdresseDetector implements EntityDetector {
  const AdresseDetector();

  @override
  EntityType get type => EntityType.adresse;

  static const _voies = [
    'rue',
    'avenue',
    'boulevard',
    'chemin',
    'impasse',
    'allée',
    'allee',
    'place',
    'route',
    'quai',
    'square',
    'passage',
    'cours',
    'lotissement',
  ];

  static final RegExp _pattern = RegExp(
    "\\d{1,4}\\s*,?\\s*(?:${_voies.join('|')})"
    "\\s+[A-ZÀ-ÖØ-Þa-zà-öø-ÿ0-9'’\\- ]+?,?\\s*"
    "\\d{5}\\s+[A-ZÀ-ÖØ-Þ][\\wÀ-ÖØ-Þà-öø-ÿ'’-]*"
    "(?:[ -][A-ZÀ-ÖØ-Þ][\\wÀ-ÖØ-Þà-öø-ÿ'’-]*){0,3}",
    caseSensitive: false,
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
      final raw = match.group(0)!;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: match.start,
          end: match.end,
          value: raw,
          confidence: 0.7,
        ),
      );
    }
    return results;
  }
}
