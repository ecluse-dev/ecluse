import 'prompt.dart';
import 'span.dart';

/// Construit les prompts utilisés par [LlmRedactVerifier].
///
/// Extrait dans une classe dédiée pour permettre :
///   - le versionnage des prompts (chaque évolution = nouvelle version) ;
///   - le remplacement facile en tests ;
///   - l'inspection en audit.
class VerifierPromptBuilder {
  const VerifierPromptBuilder({
    this.promptVersion = 'v1',
    this.maxOriginalChars = 4000,
  });

  final String promptVersion;

  /// Tronque le texte original pour éviter de saturer le contexte d'un
  /// petit LLM (3B/4B typiquement 4-8k tokens).
  final int maxOriginalChars;

  static const String _systemV1 = '''
Tu es un vérificateur d'anonymisation pour un système de traitement de
documents de santé français. Tu ne réécris JAMAIS le texte. Ton rôle est
uniquement de signaler des fuites résiduelles dans un texte déjà anonymisé.

Types de fuites à chercher :
- semantic_quasi_identifier : quasi-identifiant sémantique (« la seule
  pédiatre de la ville », « le chef de service qui a démissionné en mars »).
- coreference : pronoms ou expressions référentielles qui réintroduisent
  une identification (« elle », « ce dernier », « son frère aîné »).
- ambiguity_resolved_to_pii : token qui semblait bénin mais devient
  identifiant en contexte.
- contextual_leak : combinaison de contexte qui rend identifiable.

Si aucune fuite : retourne {"leaks": []}.

Réponds UNIQUEMENT en JSON strict, sans texte avant ni après, selon le
schéma :
{
  "leaks": [
    {"start": <int>, "end": <int>, "kind": "<type>", "reason": "<court>",
     "confidence": <float 0..1>}
  ]
}

Les offsets `start` et `end` sont exprimés dans le TEXTE ORIGINAL (celui
étiqueté ORIGINAL), pas dans le texte anonymisé.
''';

  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'properties': {
      'leaks': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'start': {'type': 'integer', 'minimum': 0},
            'end': {'type': 'integer', 'minimum': 1},
            'kind': {
              'type': 'string',
              'enum': [
                'semantic_quasi_identifier',
                'coreference',
                'ambiguity_resolved_to_pii',
                'contextual_leak',
              ],
            },
            'reason': {'type': 'string', 'maxLength': 200},
            'confidence': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
            },
          },
          'required': ['start', 'end', 'kind', 'reason'],
        },
      },
    },
    'required': ['leaks'],
  };

  LlmPrompt buildVerificationPrompt({
    required String originalText,
    required String redactedText,
    required List<Span> existingSpans,
  }) {
    final trimmedOriginal = _truncate(originalText, maxOriginalChars);
    final trimmedRedacted = _truncate(redactedText, maxOriginalChars);
    final spansSummary = _summarizeSpans(existingSpans);

    final userPart = StringBuffer()
      ..writeln('PROMPT_VERSION=$promptVersion')
      ..writeln()
      ..writeln('ORIGINAL:')
      ..writeln('---')
      ..writeln(trimmedOriginal)
      ..writeln('---')
      ..writeln()
      ..writeln('ANONYMISÉ:')
      ..writeln('---')
      ..writeln(trimmedRedacted)
      ..writeln('---')
      ..writeln()
      ..writeln('SPANS DÉJÀ DÉTECTÉS (${existingSpans.length}) :')
      ..writeln(spansSummary)
      ..writeln()
      ..writeln('Signale les fuites résiduelles en JSON strict.');

    return LlmPrompt(
      system: _systemV1,
      user: userPart.toString(),
      maxTokens: 512,
      temperature: 0.0,
      jsonSchema: _schema,
      stopSequences: const ['\n\n\n'],
    );
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}\n[…texte tronqué à $max caractères]';
  }

  String _summarizeSpans(List<Span> spans) {
    if (spans.isEmpty) return '(aucun)';
    final sb = StringBuffer();
    for (final s in spans.take(50)) {
      sb.writeln('  - [${s.start}-${s.end}] ${s.label} '
          '(source=${s.source}, conf=${s.confidence.toStringAsFixed(2)})');
    }
    if (spans.length > 50) {
      sb.writeln('  … et ${spans.length - 50} autres');
    }
    return sb.toString();
  }
}
