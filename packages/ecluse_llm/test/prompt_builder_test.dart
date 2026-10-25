import 'package:ecluse_llm/ecluse_llm.dart';
import 'package:test/test.dart';

void main() {
  const builder = VerifierPromptBuilder();

  group('VerifierPromptBuilder', () {
    test('produit un prompt déterministe (temperature=0)', () {
      final prompt = builder.buildVerificationPrompt(
        originalText: 'Mme Dupont, née en 1974, cadre à Vesoul.',
        redactedText: '[NOM_1], née en [DATE_1], cadre à [LIEU_1].',
        existingSpans: const [],
      );
      expect(prompt.temperature, 0.0);
      expect(prompt.jsonSchema, isNotNull);
    });

    test('inclut l\'original, l\'anonymisé et la liste des spans', () {
      final prompt = builder.buildVerificationPrompt(
        originalText: 'ORIG',
        redactedText: 'REDAC',
        existingSpans: const [
          Span(start: 0, end: 4, label: 'NOM', source: 'ner'),
        ],
      );
      expect(prompt.user, contains('ORIG'));
      expect(prompt.user, contains('REDAC'));
      expect(prompt.user, contains('NOM'));
      expect(prompt.user, contains('source=ner'));
    });

    test('tronque le texte au-delà de maxOriginalChars', () {
      const truncBuilder = VerifierPromptBuilder(maxOriginalChars: 20);
      final long = 'a' * 100;
      final prompt = truncBuilder.buildVerificationPrompt(
        originalText: long,
        redactedText: long,
        existingSpans: const [],
      );
      expect(prompt.user, contains('tronqué'));
    });

    test('indique la version du prompt (audit)', () {
      const versioned = VerifierPromptBuilder(promptVersion: 'v42');
      final prompt = versioned.buildVerificationPrompt(
        originalText: 'x',
        redactedText: 'x',
        existingSpans: const [],
      );
      expect(prompt.user, contains('PROMPT_VERSION=v42'));
    });

    test('résumé des spans limité à 50 entrées', () {
      final many = List.generate(
        60,
        (i) => Span(
          start: i,
          end: i + 1,
          label: 'X',
          source: 'ner',
        ),
      );
      final prompt = builder.buildVerificationPrompt(
        originalText: 'x' * 100,
        redactedText: 'x' * 100,
        existingSpans: many,
      );
      expect(prompt.user, contains('et 10 autres'));
    });

    test('système précise qu\'on ne réécrit jamais', () {
      final prompt = builder.buildVerificationPrompt(
        originalText: 'x',
        redactedText: 'x',
        existingSpans: const [],
      );
      expect(prompt.system.toLowerCase(), contains('jamais'));
      expect(prompt.system, contains('JSON'));
    });
  });
}
