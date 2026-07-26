import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur statistique. STUB : ne détecte rien pour l'instant.
///
/// Il rend le pipeline complet et testable de bout en bout, avec le NER
/// comme un trou propre à combler en phase dédiée (`flutter_onnxruntime`).
/// Absent de la composition par défaut d'`EcluseEngine` — l'ajouter ne
/// touche aucune ligne du moteur ni des autres détecteurs.
final class NerDetector implements Detector {
  NerDetector._();

  /// Chargement paresseux du modèle. No-op aujourd'hui.
  static Future<NerDetector> load() async => NerDetector._();

  @override
  DetectorTier get tier => DetectorTier.statistical;

  @override
  String get name => 'ner';

  @override
  Future<List<DetectedEntity>> detect(NormalizedText text) async => const [];
}
