import '../entity.dart';
import 'detector_tier.dart';
import 'normalized_text.dart';

/// Un détecteur d'entités sensibles. Contrat unique pour le déterministe
/// (structurel, référence, motif) comme pour le statistique (NER).
abstract interface class Detector {
  /// Origine des détections produites (départage + pondération).
  DetectorTier get tier;

  /// Identifiant court pour les logs/tests (« nir », « iban », « ner »…).
  String get name;

  /// Détecte sur le texte normalisé. Async pour un contrat uniforme :
  /// les déterministes renvoient immédiatement, le NER pourra tourner
  /// dans un isolate sans changer l'interface.
  Future<List<DetectedEntity>> detect(NormalizedText text);
}
