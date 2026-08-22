import 'package:meta/meta.dart';

/// Réponse retournée par un [LlmClient].
@immutable
class LlmResponse {
  const LlmResponse({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
    required this.latency,
    this.finishReason = LlmFinishReason.stop,
  })  : assert(promptTokens >= 0),
        assert(completionTokens >= 0);

  final String text;
  final int promptTokens;
  final int completionTokens;
  final Duration latency;
  final LlmFinishReason finishReason;

  int get totalTokens => promptTokens + completionTokens;

  /// Tokens de complétion générés par seconde (utile pour bench).
  double get tokensPerSecond {
    final micros = latency.inMicroseconds;
    if (micros <= 0 || completionTokens == 0) return 0;
    return completionTokens * 1e6 / micros;
  }

  @override
  String toString() =>
      'LlmResponse(${text.length} chars, $completionTokens tok, '
      '${latency.inMilliseconds} ms, $finishReason)';
}

enum LlmFinishReason { stop, maxTokens, stopSequence, error }
