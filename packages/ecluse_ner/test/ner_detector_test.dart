import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_ner/ecluse_ner.dart';
import 'package:test/test.dart';

void main() {
  group('NerDetector', () {
    test('stub : tier statistical, name "ner"', () async {
      final detector = await NerDetector.load();

      expect(detector.tier, DetectorTier.statistical);
      expect(detector.name, 'ner');
    });

    test('stub : ne détecte rien', () async {
      final detector = await NerDetector.load();
      final result = await detector
          .detect(NormalizedText.identity('Jean Dupont habite à Paris.'));

      expect(result, isEmpty);
    });
  });
}
