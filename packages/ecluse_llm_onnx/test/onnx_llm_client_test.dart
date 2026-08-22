import 'package:ecluse_llm/ecluse_llm.dart';
import 'package:ecluse_llm_onnx/ecluse_llm_onnx.dart';
import 'package:test/test.dart';

void main() {
  group('OnnxLlmClient.mock', () {
    test('propage la réponse renvoyée par la fonction de mock', () async {
      final client = OnnxLlmClient.mock(
        respond: (_) => '{"leaks": []}',
      );
      final response = await client.complete(
        const LlmPrompt(system: 'sys', user: 'usr'),
      );
      expect(response.text, '{"leaks": []}');
      expect(response.finishReason, LlmFinishReason.stop);
      expect(response.promptTokens, greaterThan(0));
      expect(response.completionTokens, greaterThan(0));
      client.close();
    });

    test('close() rend le client inutilisable', () async {
      final client = OnnxLlmClient.mock(respond: (_) => '{}');
      client.close();
      expect(
        () => client.complete(const LlmPrompt(system: 's', user: 'u')),
        throwsA(isA<LlmClientClosedException>()),
      );
    });

    test('intégration avec LlmRedactVerifier', () async {
      final client = OnnxLlmClient.mock(
        respond: (prompt) => '''
{"leaks": [{"start": 0, "end": 4, "kind": "coreference",
"reason": "elle", "confidence": 0.9}]}
''',
      );
      final verifier = LlmRedactVerifier(client: client);
      final result = await verifier.verify(
        originalText: 'elle est cadre à Vesoul',
        redactedText: 'elle est cadre à [LIEU_1]',
        existingSpans: const [],
      );
      expect(result.newLeaks, hasLength(1));
      expect(result.newLeaks.single.kind, LeakKind.coreference);
      client.close();
    });

    test('chatFormatter par défaut concatène système + user', () async {
      String? seen;
      final client = OnnxLlmClient.mock(
        respond: (p) {
          seen = p;
          return '{"leaks": []}';
        },
      );
      await client.complete(
        const LlmPrompt(system: 'SYS', user: 'USR'),
      );
      expect(seen, contains('SYS'));
      expect(seen, contains('USR'));
      client.close();
    });

    test('chatFormatter ChatML utilisable pour Qwen', () async {
      String? seen;
      final client = OnnxLlmClient.mock(
        respond: (p) {
          seen = p;
          return '{"leaks": []}';
        },
        chatFormatter: chatMlFormatter,
      );
      await client.complete(
        const LlmPrompt(system: 'sys', user: 'usr'),
      );
      expect(seen, contains('<|im_start|>system'));
      expect(seen, contains('<|im_start|>assistant'));
      client.close();
    });
  });
}
