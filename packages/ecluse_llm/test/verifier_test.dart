import 'package:ecluse_llm/ecluse_llm.dart';
import 'package:test/test.dart';

/// Client LLM factice pour tests hors-modèle.
class _FakeLlmClient implements LlmClient {
  _FakeLlmClient(this.responseText, {this.finishReason = LlmFinishReason.stop});
  final String responseText;
  final LlmFinishReason finishReason;
  bool closed = false;

  @override
  Future<LlmResponse> complete(LlmPrompt prompt) async {
    if (closed) throw const LlmClientClosedException();
    return LlmResponse(
      text: responseText,
      promptTokens: 100,
      completionTokens: 20,
      latency: const Duration(milliseconds: 500),
      finishReason: finishReason,
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
      // P2-109 : un échec d'analyse n'est pas un texte propre (condition D
      // de P2-104).
      expect(result.status, VerificationStatus.nonVerifie);
      expect(result.isClean, isFalse);
      expect(result.motif, isNotNull);
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

    test('texte tronqué : non vérifié, fuites trouvées conservées (P2-109)',
        () async {
      final fake = _FakeLlmClient('''
{"leaks": [{"start": 0, "end": 3, "kind": "coreference",
"reason": "elle", "confidence": 0.9}]}
''');
      final verifier = LlmRedactVerifier(
          client: fake,
          promptBuilder: const VerifierPromptBuilder(maxOriginalChars: 10));
      final result = await verifier.verify(
        originalText: 'Elle habite la seule maison bleue du village.',
        redactedText: 'Elle habite la seule maison bleue du village.',
        existingSpans: const [],
      );
      expect(result.status, VerificationStatus.nonVerifie);
      expect(result.isClean, isFalse);
      expect(result.newLeaks, hasLength(1));
      expect(result.motif, contains('tronqué'));
    });

    test('réponse coupée (maxTokens) : non vérifié même si le JSON passe',
        () async {
      final fake = _FakeLlmClient('{"leaks": []}',
          finishReason: LlmFinishReason.maxTokens);
      final result = await LlmRedactVerifier(client: fake).verify(
        originalText: 'texte',
        redactedText: 'texte',
        existingSpans: const [],
      );
      expect(result.status, VerificationStatus.nonVerifie);
      expect(result.isClean, isFalse);
    });

    test('vérifié et sans fuite : propre', () async {
      final result =
          await LlmRedactVerifier(client: _FakeLlmClient('{"leaks": []}'))
              .verify(
                  originalText: 'texte',
                  redactedText: 'texte',
                  existingSpans: const []);
      expect(result.status, VerificationStatus.verifie);
      expect(result.motif, isNull);
      expect(result.isClean, isTrue);
    });
  });
}
