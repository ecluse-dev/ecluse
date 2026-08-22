import 'package:ecluse_llm/ecluse_llm.dart';

import 'generation.dart';
import 'sampler.dart';
import 'session.dart';
import 'tokenizer.dart';

/// Implémentation [LlmClient] via ONNX Runtime.
class OnnxLlmClient implements LlmClient {
  OnnxLlmClient._({
    required Generator? generator,
    required _MockGenerate? mockGenerate,
    required this.chatFormatter,
  })  : _generator = generator,
        _mockGenerate = mockGenerate;

  final Generator? _generator;
  final _MockGenerate? _mockGenerate;

  /// Fonction qui compose system + user en une seule string de prompt,
  /// selon la convention du modèle (ChatML pour Qwen, Gemma template,
  /// Phi-3 template...).
  final ChatFormatter chatFormatter;

  bool _closed = false;

  /// Ouvre un client sur un fichier ONNX.
  ///
  /// Bloque tant que les bindings FFI ne sont pas câblés
  /// (voir [OnnxSession.open]).
  static Future<OnnxLlmClient> open({
    required String modelPath,
    required Tokenizer tokenizer,
    required ChatFormatter chatFormatter,
    OnnxSessionOptions sessionOptions = const OnnxSessionOptions(),
  }) async {
    final session = await OnnxSession.open(modelPath, options: sessionOptions);
    final generator = Generator(
      session: session,
      tokenizer: tokenizer,
      config: GenerationConfig(sampler: const GreedySampler()),
    );
    return OnnxLlmClient._(
      generator: generator,
      mockGenerate: null,
      chatFormatter: chatFormatter,
    );
  }

  /// Client factice pour tests d'intégration sans modèle ONNX.
  ///
  /// [respond] reçoit le prompt formaté (system + user assemblés) et
  /// retourne le texte à renvoyer, comme le ferait un modèle.
  factory OnnxLlmClient.mock({
    required String Function(String prompt) respond,
    ChatFormatter? chatFormatter,
  }) {
    return OnnxLlmClient._(
      generator: null,
      mockGenerate: respond,
      chatFormatter: chatFormatter ?? plainConcatFormatter,
    );
  }

  @override
  Future<LlmResponse> complete(LlmPrompt prompt) async {
    if (_closed) throw const LlmClientClosedException();

    final formatted = chatFormatter(system: prompt.system, user: prompt.user);

    if (_mockGenerate != null) {
      final sw = Stopwatch()..start();
      final text = _mockGenerate(formatted);
      sw.stop();
      // Approximation cheap pour le compte de tokens en mode mock.
      final promptToks = (formatted.length / 4).round();
      final compToks = (text.length / 4).round();
      return LlmResponse(
        text: text,
        promptTokens: promptToks,
        completionTokens: compToks,
        latency: sw.elapsed,
      );
    }

    // Utiliser sampler et stopSequences selon prompt.
    final sampler = prompt.temperature == 0.0
        ? const GreedySampler()
        : TopKPSampler(
            temperature: prompt.temperature,
            topP: prompt.topP,
            topK: prompt.topK,
            seed: prompt.seed,
          );
    final gen = Generator(
      session: _generator!.session,
      tokenizer: _generator.tokenizer,
      config: GenerationConfig(
        sampler: sampler,
        maxNewTokens: prompt.maxTokens,
        stopSequences: prompt.stopSequences,
      ),
    );

    final result = await gen.generate(formatted);
    return LlmResponse(
      text: result.text,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      latency: result.latency,
      finishReason: result.finishReason,
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _generator?.session.close();
    _generator?.tokenizer.close();
  }
}

/// Signature d'un formatteur de chat, spécifique au modèle.
typedef ChatFormatter = String Function({
  required String system,
  required String user,
});

/// Formatteur ChatML (Qwen, plusieurs modèles récents).
String chatMlFormatter({required String system, required String user}) {
  return '<|im_start|>system\n$system<|im_end|>\n'
      '<|im_start|>user\n$user<|im_end|>\n'
      '<|im_start|>assistant\n';
}

/// Formatteur Gemma 3 (approximation — à valider avec le tokenizer réel).
String gemmaFormatter({required String system, required String user}) {
  return '<start_of_turn>user\n$system\n\n$user<end_of_turn>\n'
      '<start_of_turn>model\n';
}

/// Formatteur Phi-3.
String phi3Formatter({required String system, required String user}) {
  return '<|system|>\n$system<|end|>\n'
      '<|user|>\n$user<|end|>\n'
      '<|assistant|>\n';
}

/// Formatteur trivial (pour mock et tests).
String plainConcatFormatter({required String system, required String user}) {
  return '$system\n\n$user';
}

typedef _MockGenerate = String Function(String prompt);
