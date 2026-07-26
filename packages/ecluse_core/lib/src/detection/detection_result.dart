import '../entity.dart';
import 'normalized_text.dart';

/// Résultat d'une exécution d'`EcluseEngine`.
class DetectionResult {
  const DetectionResult(this.entities, this.text);

  /// Entités finales, sans chevauchement, triées par position de début
  /// croissante. Offsets dans le texte brut (`text.raw`).
  final List<DetectedEntity> entities;

  /// Le texte normalisé + projection, pour l'étape de redaction.
  final NormalizedText text;
}
