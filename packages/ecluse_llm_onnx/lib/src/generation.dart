import 'package:ecluse_llm/ecluse_llm.dart';
import 'package:meta/meta.dart';

import 'sampler.dart';
import 'session.dart';
import 'tokenizer.dart';

@immutable
class GenerationConfig {
  const GenerationConfig({
    required this.sampler,
    this.maxNewTokens = 512,
    this.stopSequences = const <String>[],
  });

  final Sampler sampler;
  final int maxNewTokens;
  final List<String> stopSequences;
}

/// Boucle de génération autoregressive.
///
/// Structure prête : encode → boucle (forward + sample + append) →
/// stop conditions (EOS, maxNewTokens, stopSequence détectée).
///
/// La méthode dépend d'une [OnnxSession] fonctionnelle : tant que le
/// binding FFI n'est pas câblé, elle lève. Sert de contrat pour brancher
/// des tests d'intégration.
class Generator {
  Generator({
    required this.session,
    required this.tokenizer,
    required this.config,
  });

  final OnnxSession session;
  final Tokenizer tokenizer;
  final GenerationConfig config;

  Future<GenerationResult> generate(String prompt) async {
    final promptTokens = tokenizer.encode(prompt);
    final generated = <int>[];
    Object? kvCache;
    var currentInput = promptTokens;
    final sw = Stopwatch()..start();

    for (var step = 0; step < config.maxNewTokens; step++) {
      final result = await session.run(
        inputIds: currentInput,
        pastKeyValues: kvCache,
      );
      kvCache = result.pastKeyValues;

      final nextId = config.sampler.sample(result.lastTokenLogits);
      generated.add(nextId);

      if (nextId == tokenizer.eosTokenId) {
        return _finish(
            sw, generated, promptTokens.length, LlmFinishReason.stop);
      }

      // Après le premier tour, on ne réencode que le nouveau token grâce
      // au cache KV.
      currentInput = <int>[nextId];

      if (config.stopSequences.isNotEmpty) {
        final soFar = tokenizer.decode(generated);
        for (final stop in config.stopSequences) {
          if (soFar.endsWith(stop)) {
            return _finish(sw, generated, promptTokens.length,
                LlmFinishReason.stopSequence);
          }
        }
      }
    }

    return _finish(
        sw, generated, promptTokens.length, LlmFinishReason.maxTokens);
  }

  GenerationResult _finish(
    Stopwatch sw,
    List<int> generated,
    int promptTokenCount,
    LlmFinishReason finishReason,
  ) {
    sw.stop();
    return GenerationResult(
      text: tokenizer.decode(generated),
      promptTokens: promptTokenCount,
      completionTokens: generated.length,
      latency: sw.elapsed,
      finishReason: finishReason,
    );
  }
}

@immutable
class GenerationResult {
  const GenerationResult({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
    required this.latency,
    required this.finishReason,
  });

  final String text;
  final int promptTokens;
  final int completionTokens;
  final Duration latency;
  final LlmFinishReason finishReason;
}
