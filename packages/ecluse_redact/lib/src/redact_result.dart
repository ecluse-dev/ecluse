import 'package:ecluse_core/ecluse_core.dart';

/// Résultat d'un appel à `Ecluse.redact`.
final class RedactResult {
  const RedactResult({
    required this.maskedText,
    required this.mapping,
    required this.entities,
  });

  /// Texte à envoyer à l'IA — les entités personnelles sont remplacées par
  /// des jetons typés (`[NOM_1]`, `[NIR_1]`, …).
  final String maskedText;

  /// Table de correspondance jeton ↔ valeur réelle.
  ///
  /// **Ne quitte jamais le processus local** : ni envoyée, ni journalisée,
  /// ni écrite sur disque. Elle ne sert qu'à l'appel à `Ecluse.restore`.
  final Map<String, String> mapping;

  /// Entités détectées dans le texte d'origine, triées par position,
  /// sans chevauchement (voir `resolveOverlaps`).
  final List<DetectedEntity> entities;
}
