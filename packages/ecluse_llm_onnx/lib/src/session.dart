import 'package:meta/meta.dart';

/// Options de configuration d'une session ONNX Runtime.
@immutable
class OnnxSessionOptions {
  const OnnxSessionOptions({
    this.intraOpNumThreads = 4,
    this.interOpNumThreads = 1,
    this.enableCpuFallback = true,
    this.executionProvider = ExecutionProvider.cpu,
  });

  final int intraOpNumThreads;
  final int interOpNumThreads;
  final bool enableCpuFallback;
  final ExecutionProvider executionProvider;
}

enum ExecutionProvider { cpu, cuda, directML, coreML }

/// Wrapper de session ORT.
///
/// **Statut : stub.** Les appels FFI vers `onnxruntime_c_api.h` sont à
/// générer via `ffigen`. Cette classe existe pour figer la surface API
/// consommée par `OnnxLlmClient` et `generation.dart`.
///
/// Convention : toute allocation native (`OrtEnv`, `OrtSession`,
/// `OrtValue`) est libérée dans `close()` ou immédiatement après usage
/// dans un `try/finally`.
class OnnxSession {
  OnnxSession._(this.modelPath, this.options);

  final String modelPath;
  final OnnxSessionOptions options;
  bool _closed = false;

  /// Ouvre une session sur le fichier ONNX pointé par [modelPath].
  ///
  /// TODO(ffi): appeler `OrtCreateEnv` puis `OrtCreateSession`.
  static Future<OnnxSession> open(
    String modelPath, {
    OnnxSessionOptions options = const OnnxSessionOptions(),
  }) async {
    // Marker FFI. À remplacer par un vrai appel natif.
    throw UnimplementedError(
      'OnnxSession.open : bindings ORT à générer via ffigen. '
      'Voir README.md et ffigen.yaml.',
    );
  }

  /// Exécute une passe forward.
  ///
  /// - [inputIds] : tokens du prompt (int64).
  /// - [pastKeyValues] : cache KV de la passe précédente (null au premier tour).
  ///
  /// Retourne les logits du dernier token et le nouveau cache KV.
  ///
  /// TODO(ffi): remplir. Pour l'instant, lève.
  Future<RunResult> run({
    required List<int> inputIds,
    Object? pastKeyValues,
  }) async {
    if (_closed) throw StateError('session closed');
    throw UnimplementedError('OnnxSession.run : FFI à câbler');
  }

  void close() {
    _closed = true;
    // TODO(ffi): OrtReleaseSession + OrtReleaseEnv.
  }

  bool get isClosed => _closed;
}

/// Résultat d'un `run` : logits du dernier token + cache KV mis à jour.
@immutable
class RunResult {
  const RunResult({required this.lastTokenLogits, required this.pastKeyValues});
  final List<double> lastTokenLogits;
  final Object pastKeyValues;
}
