import 'package:ecluse_llm/ecluse_llm.dart';
import 'package:test/test.dart';

/// Client LLM factice pour tests hors-modèle.
class _FakeLlmClient implements LlmClient {
  _FakeLlmClient(this.responseText);
  final String responseText;
  bool closed = false;

  @override
  Future<LlmResponse> complete(LlmPrompt prompt) async {
    if (closed) throw const LlmClientClosedException();
    return LlmResponse(
      text: responseText,
      promptTokens: 100,
      completionTokens: 20,
      latency: const Duration(milliseconds: 500),
    );
  }

  @override
  void close() => closed = true;
}

void main() {
  group('LlmRedactVerifier', () {
    test('propage les leaks correctement parsées', () async {
      final fake = _FakeLlmClient('''
{"leaks": [{"start": 5, "end": 15, "kind": "coreference",
"reason": "elle", "confidence": 0.9}]}
''');
      final verifier = LlmRedactVerifier(client: fake);
      final result = await verifier.verify(
        originalText: 'Mme Dupont, née à Vesoul, est cadre.',
        redactedText: '[NOM_1], née à [LIEU_1], est cadre.',
        existingSpans: const [],
      );
      expect(result.newLeaks, hasLength(1));
      expect(result.newLeaks.single.kind, LeakKind.coreference);
      expect(result.warnings, isEmpty);
      expect(result.isClean, isFalse);
    });

    test('résultat vide + warning quand le LLM renvoie du texte libre',
        () async {
      final fake = _FakeLlmClient('Je ne peux pas t\'aider.');
      final verifier = LlmRedactVerifier(client: fake);
      final result = await verifier.verify(
        originalText: 'texte',
        redactedText: 'texte',
        existingSpans: const [],
      );
      expect(result.newLeaks, isEmpty);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, contains('JSON parse failed'));
      expect(result.isClean, isTrue);
    });

    test('isClean=true quand aucune leak', () async {
      final fake = _FakeLlmClient('{"leaks": []}');
      final verifier = LlmRedactVerifier(client: fake);
      final result = await verifier.verify(
        originalText: 'texte',
        redactedText: 'texte',
        existingSpans: const [],
      );
      expect(result.isClean, isTrue);
    });
  });
}
