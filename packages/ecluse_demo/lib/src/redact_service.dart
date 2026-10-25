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
    required this.maskedInstruction,
    required this.llmResponse,
    required this.restoredText,
  });

  final String originalText;
  final List<DetectedEntity> entities;
  final String maskedText;

  /// Consigne telle qu'envoyée au LLM : masquée avec la même table que le
  /// texte (une consigne peut citer un nom : « résume le cas de M. X »).
  final String maskedInstruction;
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
    // La consigne est masquée avec le texte, en un seul passage : mêmes
    // jetons pour la même personne, aucune collision de numérotation. Le
    // séparateur NUL ne peut appartenir à aucune entité détectée.
    const separator = '\u0000';
    if (text.contains(separator) || instruction.contains(separator)) {
      throw const LlmError(
        'Texte ou consigne contenant un caractère NUL : requête refusée.',
      );
    }
    final combined = '$instruction$separator$text';
    final redacted = await Ecluse.redact(combined);
    final cut = redacted.maskedText.indexOf(separator);
    final maskedInstruction = redacted.maskedText.substring(0, cut);
    final maskedText = redacted.maskedText.substring(cut + 1);

    // Seules les entités du texte sont rendues à l'interface, positions
    // ramenées au texte d'origine (la consigne précède le texte).
    final offset = instruction.length + 1;
    final entities = [
      for (final e in redacted.entities)
        if (e.start >= offset)
          DetectedEntity(
            type: e.type,
            start: e.start - offset,
            end: e.end - offset,
            value: e.value,
            confidence: e.confidence,
            tier: e.tier,
          ),
    ];

    final llmResponse = await _llmClient.complete(
      maskedText,
      instruction: maskedInstruction,
    );

    final restoredText = Ecluse.restore(llmResponse, redacted.mapping);

    return ProcessResult(
      originalText: text,
      entities: entities,
      maskedText: maskedText,
      maskedInstruction: maskedInstruction,
      llmResponse: llmResponse,
      restoredText: restoredText,
    );
  }
}
