/// Écluse Core — détection d'entités personnelles françaises et
/// européennes, 100 % on-device.
///
/// Point d'entrée public du package. Exemple minimal :
///
/// ```dart
/// import 'package:ecluse_core/ecluse_core.dart';
///
/// void main() {
///   const detector = NirDetector();
///   final entities = detector.detect('NIR : 1 85 05 78 006 084 91');
///   print(entities); // [DetectedEntity(nir, [6, 28), confidence: 1.0)]
/// }
/// ```
library;

export 'src/detection/detection_result.dart';
export 'src/detection/detector.dart';
export 'src/detection/detector_tier.dart';
export 'src/detection/ecluse_engine.dart';
export 'src/detection/legacy_detector_adapter.dart';
export 'src/detection/normalized_text.dart';
export 'src/detector.dart';
export 'src/detectors/finess_detector.dart';
export 'src/detectors/iban_detector.dart';
export 'src/detectors/nir_detector.dart';
export 'src/detectors/rpps_detector.dart';
export 'src/entity.dart';
export 'src/resolver.dart';
