import 'ocr_page.dart';
import 'revalidation_outcome.dart';
import 'risk_zone.dart';
import 'structural_revalidator.dart';

/// Résultat combiné : texte propre + carte des corrections + zones à
/// arbitrer par l'humain.
class OcrIngestReport {
  const OcrIngestReport({
    required this.pages,
    required this.corrections,
    required this.riskZones,
  });

  final List<OcrPage> pages;

  /// Corrections structurelles appliquées, indexées par texte d'origine.
  /// Utile pour reconstituer le mapping restore.
  final List<Corrected> corrections;

  /// Zones nécessitant une décision humaine avant envoi au LLM tiers.
  final List<RiskZone> riskZones;

  bool get isReadyForLlm => riskZones.isEmpty;
}

/// Orchestre la revalidation structurelle et la détection de zones à
/// risque sur une ou plusieurs pages OCR.
class RiskZoneReporter {
  const RiskZoneReporter({
    required this.revalidator,
    this.minTokenConfidence = 0.75,
  }) : assert(minTokenConfidence >= 0.0 && minTokenConfidence <= 1.0);

  final StructuralRevalidator revalidator;

  /// En dessous de ce seuil de confiance OCR, un token qui ressemble à
  /// un identifiant est automatiquement placé en zone à risque, même si
  /// la revalidation structurelle réussit — parce qu'on ne veut pas
  /// faire confiance à un checksum vérifié sur du texte que l'OCR
  /// n'a pas su lire.
  final double minTokenConfidence;

  OcrIngestReport analyze(List<OcrPage> pages) {
    final corrections = <Corrected>[];
    final riskZones = <RiskZone>[];

    for (final page in pages) {
      for (final region in page.regions) {
        for (final token in region.tokens) {
          final outcome = revalidator.tryRevalidate(token.text);
          if (outcome == null) continue;

          switch (outcome) {
            case Corrected():
              if (token.confidence < minTokenConfidence) {
                riskZones.add(RiskZone(
                  box: token.box,
                  text: token.text,
                  reason: RiskReason.lowOcrConfidence,
                  suggestion: outcome.corrected,
                  outcome: outcome,
                ));
              } else {
                corrections.add(outcome);
              }
            case Ambiguous():
              riskZones.add(RiskZone(
                box: token.box,
                text: token.text,
                reason: RiskReason.ambiguousCorrection,
                suggestion: outcome.candidates
                    .map((c) => c.candidate)
                    .toSet()
                    .join(' | '),
                outcome: outcome,
              ));
            case Unrecoverable():
              riskZones.add(RiskZone(
                box: token.box,
                text: token.text,
                reason: RiskReason.unrecoverableIdentifier,
                suggestion: 'suspecté ${outcome.suspectedKind}',
                outcome: outcome,
              ));
          }
        }
      }
    }

    return OcrIngestReport(
      pages: pages,
      corrections: corrections,
      riskZones: riskZones,
    );
  }
}
