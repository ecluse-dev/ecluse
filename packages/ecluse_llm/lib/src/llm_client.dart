import 'prompt.dart';
import 'response.dart';

/// Client LLM abstrait.
///
/// Implémentations fournies séparément :
///   - `ecluse_llm_onnx.OnnxLlmClient` : ONNX Runtime via FFI Dart.
///   - (à venir) `OllamaLlmClient` : HTTP local, pour prototypage.
abstract interface class LlmClient {
  /// Complète le prompt et retourne la réponse.
  Future<LlmResponse> complete(LlmPrompt prompt);

  /// Libère les ressources (session ORT, fichiers mappés, etc.).
  ///
  /// Après `close()`, tout appel à `complete` doit lever [StateError].
  void close();
}

/// Levée par un [LlmClient] quand la génération dépasse un budget de temps
/// configuré côté implémentation.
class LlmTimeoutException implements Exception {
  const LlmTimeoutException(this.budget);
  final Duration budget;
  @override
  String toString() => 'LlmTimeoutException(budget: $budget)';
}

/// Levée quand la session est fermée ou le modèle inaccessible.
class LlmClientClosedException implements Exception {
  const LlmClientClosedException();
  @override
  String toString() => 'LlmClientClosedException()';
}
