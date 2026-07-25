import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';

import 'llm_client.dart';

/// Résultat complet d'un trajet redact → LLM → restore, tel qu'affiché
/// dans les 4 panneaux de la démo.
final class ProcessResult {
  const ProcessResult({
    required this.originalText,
    required this.entities,
    required this.maskedText,
    required this.llmResponse,
    required this.restoredText,
  });

  final String originalText;
  final List<DetectedEntity> entities;
  final String maskedText;
  final String llmResponse;
  final String restoredText;
}

/// Orchestre le trajet complet : masquage local, appel LLM, restauration
/// locale. La table de correspondance jeton ↔ valeur réelle (`mapping`)
/// ne sort jamais de cette méthode.
final class RedactService {
  const RedactService(this._llmClient);

  final LlmClient _llmClient;

  Future<ProcessResult> process(
    String text, {
    required String instruction,
  }) async {
    final redacted = Ecluse.redact(text);

    final llmResponse = await _llmClient.complete(
      redacted.maskedText,
      instruction: instruction,
    );

    final restoredText = Ecluse.restore(llmResponse, redacted.mapping);

    return ProcessResult(
      originalText: text,
      entities: redacted.entities,
      maskedText: redacted.maskedText,
      llmResponse: llmResponse,
      restoredText: restoredText,
    );
  }
}
