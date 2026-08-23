/// Interfaces et outils Dart purs pour l'ingestion OCR dans Ecluse,
/// avec revalidation structurelle post-extraction.
///
/// Voir [OcrEngine], [StructuralRevalidator], [RiskZoneReporter].
library;

export 'src/ambiguity_resolver.dart';
export 'src/bounding_box.dart';
export 'src/ocr_engine.dart';
export 'src/ocr_page.dart';
export 'src/revalidation_outcome.dart';
export 'src/risk_zone.dart';
export 'src/risk_zone_reporter.dart';
export 'src/structural_revalidator.dart';
export 'src/structural_validator.dart';
