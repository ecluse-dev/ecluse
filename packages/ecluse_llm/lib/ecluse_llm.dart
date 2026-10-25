/// Interfaces Dart pures pour l'usage d'un petit LLM local dans la couche
/// d'anonymisation d'Ecluse.
///
/// Voir [LlmClient], [RedactVerifier], [LeakSpan].
library;

export 'src/leak_span.dart';
export 'src/llm_client.dart';
export 'src/prompt.dart';
export 'src/prompt_builder.dart';
export 'src/response.dart';
export 'src/span.dart';
export 'src/verifier.dart';
export 'src/verifier_impl.dart';
export 'src/json_parser.dart' show parseLeakSpansJson, LlmJsonParseException;
