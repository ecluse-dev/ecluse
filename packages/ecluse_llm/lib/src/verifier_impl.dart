import 'json_parser.dart';
import 'llm_client.dart';
import 'response.dart';
import 'prompt_builder.dart';
import 'span.dart';
import 'verifier.dart';

/// Implémentation par défaut du [RedactVerifier], déléguant à un
/// [LlmClient] injecté.
class LlmRedactVerifier implements RedactVerifier {
  LlmRedactVerifier({
    required this.client,
    VerifierPromptBuilder? promptBuilder,
  }) : promptBuilder = promptBuilder ?? const VerifierPromptBuilder();

  final LlmClient client;
  final VerifierPromptBuilder promptBuilder;

  @override
  Future<VerificationResult> verify({
    required String originalText,
    required String redactedText,
    required List<Span> existingSpans,
  }) async {
    final prompt = promptBuilder.buildVerificationPrompt(
      originalText: originalText,
      redactedText: redactedText,
      existingSpans: existingSpans,
    );

    final stopwatch = Stopwatch()..start();
    final response = await client.complete(prompt);
    stopwatch.stop();

    // Motifs de non-vérification (P2-109) : la fin du texte n'a pas été
    // soumise, ou la réponse a été coupée avant la fin.
    final max = promptBuilder.maxOriginalChars;
    final motifs = <String>[
      if (originalText.length > max || redactedText.length > max)
        'texte tronqué à $max caractères : la suite n\'a pas été vérifiée',
      if (response.finishReason == LlmFinishReason.maxTokens)
        'réponse du LLM coupée (limite de jetons atteinte)',
      if (response.finishReason == LlmFinishReason.error)
        'réponse du LLM en erreur',
    ];

    try {
      final parsed = parseLeakSpansJson(
        response.text,
        textLength: originalText.length,
      );
      return VerificationResult(
        newLeaks: parsed.leaks,
        latency: stopwatch.elapsed,
        rawResponse: response.text,
        warnings: parsed.warnings,
        status: motifs.isEmpty
            ? VerificationStatus.verifie
            : VerificationStatus.nonVerifie,
        motif: motifs.isEmpty ? null : motifs.join(' ; '),
      );
    } on LlmJsonParseException catch (e) {
      // Pas d'exception remontée : les couches structurelle et NER restent
      // valables. Mais le résultat est **non vérifié**, jamais « propre » :
      // une liste vide laissait `isClean` à vrai sur un texte non lu (P2-107).
      return VerificationResult(
        newLeaks: const [],
        latency: stopwatch.elapsed,
        rawResponse: response.text,
        warnings: [
          'JSON parse failed: ${e.message} — verification skipped',
        ],
        status: VerificationStatus.nonVerifie,
        motif: [
          'réponse du LLM illisible (${e.message})',
          ...motifs,
        ].join(' ; '),
      );
    }
  }
}
