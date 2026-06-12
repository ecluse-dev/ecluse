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

export 'src/detector.dart';
export 'src/detectors/iban_detector.dart';
export 'src/detectors/nir_detector.dart';
export 'src/detectors/rpps_detector.dart';
export 'src/entity.dart';
