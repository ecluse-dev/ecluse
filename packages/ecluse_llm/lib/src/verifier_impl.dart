import 'json_parser.dart';
import 'llm_client.dart';
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
      );
    } on LlmJsonParseException catch (e) {
      // Ligne éditoriale : en cas d'échec de parsing, on ne fait PAS
      // remonter d'exception au caller — on retourne un résultat vide avec
      // warning. Le pipeline `EcluseEngine` continue avec les couches
      // structurel + NER, qui restent fiables.
      return VerificationResult(
        newLeaks: const [],
        latency: stopwatch.elapsed,
        rawResponse: response.text,
        warnings: [
          'JSON parse failed: ${e.message} — verification skipped',
        ],
      );
    }
  }
}
