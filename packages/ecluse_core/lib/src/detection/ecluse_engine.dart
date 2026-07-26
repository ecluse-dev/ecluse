import '../entity.dart';
import '../resolver.dart';
import 'detection_result.dart';
import 'detector.dart';
import 'normalized_text.dart';

/// Compose une liste de [Detector], exécute chacun sur le même texte,
/// fusionne via `resolveOverlaps`.
///
/// Le NER n'est qu'un `Detector` de plus — absent par défaut. L'ajouter à
/// [detectors] ne touche aucune ligne de cette classe.
class EcluseEngine {
  EcluseEngine(this._detectors);

  final List<Detector> _detectors;

  Future<DetectionResult> run(String raw) async {
    final text = _normalize(raw);

    final all = <DetectedEntity>[];
    for (final detector in _detectors) {
      final results = await detector.detect(text);
      all.addAll(
        results.map(
          (e) => DetectedEntity(
            type: e.type,
            start: e.start,
            end: e.end,
            value: e.value,
            confidence: e.confidence,
            tier: detector.tier,
          ),
        ),
      );
    }

    final resolved = resolveOverlaps(all);
    return DetectionResult(resolved, text);
  }

  /// Identité pour ce jalon (voir `NormalizedText`) : `DigitCompaction`
  /// reste interne aux détecteurs qui en ont besoin.
  NormalizedText _normalize(String raw) => NormalizedText.identity(raw);
}
