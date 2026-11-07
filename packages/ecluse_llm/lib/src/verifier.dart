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

/// Statut d'une passe de vérification (P2-109).
///
/// Pourquoi un statut explicite : une liste de fuites vide ne dit pas si le
/// texte a été lu. Sur un échec d'analyse de la réponse ou un texte tronqué,
/// rendre « aucune fuite » serait un échec silencieux (règle 4 de
/// `CLAUDE.md`, condition D de P2-104).
enum VerificationStatus {
  /// Tout le texte a été soumis et la réponse a été lue en entier.
  verifie,

  /// Le résultat ne couvre pas tout le texte, ou la réponse n'a pas pu être
  /// lue : voir [VerificationResult.motif].
  nonVerifie,
}

/// Résultat d'une passe de vérification.
@immutable
class VerificationResult {
  const VerificationResult({
    required this.newLeaks,
    required this.latency,
    this.rawResponse,
    this.warnings = const <String>[],
    this.status = VerificationStatus.verifie,
    this.motif,
  }) : assert(status == VerificationStatus.verifie || motif != null,
            'un résultat non vérifié porte un motif');

  /// [VerificationStatus.nonVerifie] si le texte a été tronqué ou si la
  /// réponse du LLM est inexploitable ou coupée.
  final VerificationStatus status;

  /// Pourquoi la vérification n'est pas complète, ou `null` si elle l'est.
  final String? motif;

  /// Fuites supplémentaires proposées. **Offsets exprimés dans le texte
  /// d'origine** (pas dans le texte redacté).
  final List<LeakSpan> newLeaks;

  final Duration latency;

  /// Réponse brute du LLM (utile pour audit / debug).
  final String? rawResponse;

  /// Warnings non bloquants (parsing tolérant, offset ajusté, etc.).
  final List<String> warnings;

  /// Vrai seulement si la vérification est complète **et** sans fuite.
  bool get isClean => status == VerificationStatus.verifie && newLeaks.isEmpty;

  @override
  String toString() => 'VerificationResult(${status.name}, '
      '${newLeaks.length} leaks, '
      '${latency.inMilliseconds} ms, ${warnings.length} warnings)';
}
