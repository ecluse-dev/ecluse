import 'package:meta/meta.dart';

import 'bounding_box.dart';
import 'revalidation_outcome.dart';

/// Raison pour laquelle une zone doit être portée à l'attention de
/// l'humain avant envoi au LLM tiers.
enum RiskReason {
  /// Confiance OCR sous seuil, tokenisation floue.
  lowOcrConfidence,

  /// Le token ressemble à un identifiant mais aucune variante ne valide.
  unrecoverableIdentifier,

  /// Plusieurs corrections plausibles → choix humain requis.
  ambiguousCorrection,
}

/// Une zone à risque : contexte suffisant pour que l'humain décide
/// (rectangle dans l'image, texte lu, motif).
@immutable
class RiskZone {
  const RiskZone({
    required this.box,
    required this.text,
    required this.reason,
    this.suggestion,
    this.outcome,
  });

  final BoundingBox box;
  final String text;
  final RiskReason reason;

  /// Suggestion textuelle à afficher à l'humain (optionnelle).
  final String? suggestion;

  /// Issue technique associée (utile pour le debug et l'audit).
  final RevalidationOutcome? outcome;

  @override
  String toString() => 'RiskZone($reason @ $box, "$text")';
}
