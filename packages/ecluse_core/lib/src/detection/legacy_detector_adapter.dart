import '../detector.dart';
import '../entity.dart';
import 'detector.dart';
import 'detector_tier.dart';
import 'normalized_text.dart';

/// Enveloppe un `EntityDetector` existant derrière l'interface `Detector`,
/// sans toucher sa logique interne.
///
/// `NormalizedText` est identité pour ce jalon (voir sa documentation) :
/// le détecteur legacy reçoit `text.raw`, exactement le texte qu'il aurait
/// reçu via `EntityDetector.detect` avant ce refactor — y compris pour
/// `NirDetector`/`IbanFrDetector`, qui gèrent déjà eux-mêmes leur propre
/// `DigitCompaction` et reprojettent vers le texte brut avant de renvoyer
/// une `DetectedEntity`.
final class LegacyDetectorAdapter implements Detector {
  const LegacyDetectorAdapter(this._legacy, this.tier, {String? name})
      : _name = name;

  final EntityDetector _legacy;

  @override
  final DetectorTier tier;

  final String? _name;

  @override
  String get name => _name ?? _legacy.type.name;

  @override
  Future<List<DetectedEntity>> detect(NormalizedText text) async =>
      _legacy.detect(text.raw);
}
