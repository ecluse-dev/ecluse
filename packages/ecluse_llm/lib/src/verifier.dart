import 'package:meta/meta.dart';

import 'leak_span.dart';
import 'span.dart';

/// Vérificateur post-redact.
///
/// Prend le texte original, le texte anonymisé, et les spans déjà détectés
/// par les couches précédentes (structurel, NER, heuristiques). Retourne
/// des [LeakSpan] supplémentaires — jamais moins, jamais de réécriture.
abstract interface class RedactVerifier {
  Future<VerificationResult> verify({
    required String originalText,
    required String redactedText,
    required List<Span> existingSpans,
  });
}

/// Résultat d'une passe de vérification.
@immutable
class VerificationResult {
  const VerificationResult({
    required this.newLeaks,
    required this.latency,
    this.rawResponse,
    this.warnings = const <String>[],
  });

  /// Fuites supplémentaires proposées. **Offsets exprimés dans le texte
  /// d'origine** (pas dans le texte redacté).
  final List<LeakSpan> newLeaks;

  final Duration latency;

  /// Réponse brute du LLM (utile pour audit / debug).
  final String? rawResponse;

  /// Warnings non bloquants (parsing tolérant, offset ajusté, etc.).
  final List<String> warnings;

  bool get isClean => newLeaks.isEmpty;

  @override
  String toString() => 'VerificationResult(${newLeaks.length} leaks, '
      '${latency.inMilliseconds} ms, ${warnings.length} warnings)';
}
