import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

void main() {
  group('EcluseEngine', () {
    test('compose plusieurs détecteurs et fusionne via resolveOverlaps',
        () async {
      final engine = EcluseEngine([
        const LegacyDetectorAdapter(NirDetector(), DetectorTier.structural,
            name: 'nir'),
        const LegacyDetectorAdapter(RppsDetector(), DetectorTier.structural,
            name: 'rpps'),
        const LegacyDetectorAdapter(IbanFrDetector(), DetectorTier.structural,
            name: 'iban'),
      ]);

      const text = 'NIR : 1 85 05 78 006 084 91';
      final result = await engine.run(text);

      final direct = resolveOverlaps([
        ...const NirDetector().detect(text),
        ...const RppsDetector().detect(text),
        ...const IbanFrDetector().detect(text),
      ]);

      expect(result.entities.length, direct.length);
      for (var i = 0; i < result.entities.length; i++) {
        expect(result.entities[i].type, direct[i].type);
        expect(result.entities[i].start, direct[i].start);
        expect(result.entities[i].end, direct[i].end);
        expect(result.entities[i].value, direct[i].value);
        expect(result.entities[i].confidence, direct[i].confidence);
      }
    });

    test('attache le tier du détecteur à chaque entité produite', () async {
      final engine = EcluseEngine([
        const LegacyDetectorAdapter(NirDetector(), DetectorTier.structural,
            name: 'nir'),
      ]);

      const text = 'NIR : 1 85 05 78 006 084 91';
      final result = await engine.run(text);

      expect(result.entities, isNotEmpty);
      expect(result.entities.single.tier, DetectorTier.structural);
    });

    test('text.raw et text.normalized identiques à ce jalon', () async {
      final engine = EcluseEngine(const []);
      const text = 'un texte quelconque';
      final result = await engine.run(text);

      expect(result.text.raw, text);
      expect(result.text.normalized, text);
      expect(result.text.toRawOffset(3), 3);
    });
  });
}
