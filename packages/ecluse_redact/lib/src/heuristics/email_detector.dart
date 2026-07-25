import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique d'adresses email — **v0 de démonstration**.
///
/// Motif standard `local@domaine.tld`. Une adresse email bien formée est un
/// indice très spécifique (peu de faux positifs) mais reste un motif, pas
/// une validation structurelle (pas de vérification DNS/MX) : confiance
/// haute (0.85).
final class EmailDetector implements EntityDetector {
  const EmailDetector();

  @override
  EntityType get type => EntityType.email;

  static final RegExp _pattern = RegExp(
    r'[A-Za-z0-9][A-Za-z0-9._%+-]*@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
      results.add(
        DetectedEntity(
          type: EntityType.email,
          start: match.start,
          end: match.end,
          value: match.group(0)!,
          confidence: 0.85,
        ),
      );
    }
    return results;
  }
}
