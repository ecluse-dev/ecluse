import 'package:meta/meta.dart';

/// Un prompt structuré à envoyer au [LlmClient].
@immutable
class LlmPrompt {
  const LlmPrompt({
    required this.system,
    required this.user,
    this.maxTokens = 512,
    this.temperature = 0.0,
    this.topP = 1.0,
    this.topK = 0,
    this.stopSequences = const <String>[],
    this.jsonSchema,
    this.seed,
  })  : assert(maxTokens > 0),
        assert(temperature >= 0.0 && temperature <= 2.0),
        assert(topP > 0.0 && topP <= 1.0),
        assert(topK >= 0);

  /// Message système : rôle et contraintes.
  final String system;

  /// Message utilisateur : la tâche à accomplir.
  final String user;

  final int maxTokens;

  /// 0.0 = déterministe (recommandé pour l'anonymisation).
  final double temperature;

  final double topP;

  /// 0 = pas de troncature.
  final int topK;

  final List<String> stopSequences;

  /// Contrainte de format optionnelle (schéma JSON attendu).
  ///
  /// L'implémentation peut, si elle le supporte, forcer la génération à
  /// respecter ce schéma (guided decoding).
  final Map<String, dynamic>? jsonSchema;

  /// Graine de RNG pour reproductibilité.
  final int? seed;

  @override
  String toString() =>
      'LlmPrompt(temp=$temperature, maxTokens=$maxTokens, seed=$seed)';
}
