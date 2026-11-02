import 'package:ecluse_ocr/ecluse_ocr.dart';
import 'package:test/test.dart';

OcrToken _tk(String text, double conf) => OcrToken(
      text: text,
      confidence: conf,
      box: const BoundingBox(
        x: 0,
        y: 0,
        width: 100,
        height: 20,
        pageIndex: 0,
      ),
    );

OcrPage _pageFromTokens(List<OcrToken> tokens) => OcrPage(
      pageIndex: 0,
      width: 1000,
      height: 1000,
      regions: [
        OcrRegion(
          kind: OcrRegionKind.line,
          tokens: tokens,
          box: const BoundingBox(
            x: 0,
            y: 0,
            width: 1000,
            height: 20,
            pageIndex: 0,
          ),
        ),
      ],
      sourceEngine: 'test',
    );

void main() {
  group('RiskZoneReporter', () {
    final revalidator = StructuralRevalidator(
      validators: const [FakeNirValidator()],
    );
    final reporter = RiskZoneReporter(revalidator: revalidator);

    test('NIR bruité + confiance haute → correction sans zone à risque', () {
      final page = _pageFromTokens([
        _tk('155O47800000162', 0.92),
      ]);
      final report = reporter.analyze([page]);
      expect(report.corrections, hasLength(1));
      expect(report.corrections.single.corrected, '155047800000162');
      expect(report.riskZones, isEmpty);
      expect(report.isReadyForLlm, isTrue);
    });

    test('NIR bruité + confiance basse → zone à risque même si corrigeable',
        () {
      final page = _pageFromTokens([
        _tk('155O47800000162', 0.40), // OCR peu sûr
      ]);
      final report = reporter.analyze([page]);
      expect(report.corrections, isEmpty);
      expect(report.riskZones, hasLength(1));
      expect(report.riskZones.single.reason, RiskReason.lowOcrConfidence);
      expect(report.riskZones.single.suggestion, '155047800000162');
      expect(report.isReadyForLlm, isFalse);
    });

    test('token ressemble à NIR mais impossible à valider → risk zone', () {
      final page = _pageFromTokens([
        _tk('999999999999999', 0.95),
      ]);
      final report = reporter.analyze([page]);
      expect(report.riskZones, hasLength(1));
      expect(
        report.riskZones.single.reason,
        RiskReason.unrecoverableIdentifier,
      );
    });

    test('token normal (mot) → ignoré, ni correction ni zone', () {
      final page = _pageFromTokens([
        _tk('planning', 0.99),
        _tk('cadre', 0.95),
      ]);
      final report = reporter.analyze([page]);
      expect(report.corrections, isEmpty);
      expect(report.riskZones, isEmpty);
    });

    test('mélange : un NIR OK, un mot, un NIR bruité → 1 correction', () {
      final page = _pageFromTokens([
        _tk('planning', 0.99),
        _tk('155O47800000162', 0.88),
        _tk('cadre', 0.94),
      ]);
      final report = reporter.analyze([page]);
      expect(report.corrections, hasLength(1));
      expect(report.riskZones, isEmpty);
    });

    test('seuil de confiance configurable', () {
      final strict = RiskZoneReporter(
        revalidator: revalidator,
        minTokenConfidence: 0.99,
      );
      final page = _pageFromTokens([
        _tk('155O47800000162', 0.98), // sous 0.99
      ]);
      final report = strict.analyze([page]);
      expect(report.corrections, isEmpty);
      expect(report.riskZones, hasLength(1));
    });
  });
}
