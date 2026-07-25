/// Pseudonymisation réversible pour Écluse.
///
/// ```dart
/// import 'package:ecluse_redact/ecluse_redact.dart';
///
/// void main() {
///   final result = Ecluse.redact('M. Jean Dupont, né le 1 janvier 1980.');
///   print(result.maskedText); // '[NOM_1], [DATE_NAISSANCE_1].'
///   print(Ecluse.restore(result.maskedText, result.mapping));
/// }
/// ```
library;

export 'src/ecluse.dart';
export 'src/heuristics/adresse_detector.dart';
export 'src/heuristics/date_naissance_detector.dart';
export 'src/heuristics/email_detector.dart';
export 'src/heuristics/etablissement_detector.dart';
export 'src/heuristics/name_detector.dart';
export 'src/heuristics/telephone_detector.dart';
export 'src/redact_result.dart';
export 'src/samples.dart';
export 'src/tokenizer.dart' show entityTypeLabel;
