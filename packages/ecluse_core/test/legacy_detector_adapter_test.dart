import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

void main() {
  group('LegacyDetectorAdapter', () {
    test('produit les mêmes entités que le détecteur legacy direct', () async {
      const text = 'NIR : 1 85 05 78 006 084 91';
      const legacy = NirDetector();
      final adapter =
          LegacyDetectorAdapter(legacy, DetectorTier.structural, name: 'nir');

      final direct = legacy.detect(text);
      final wrapped = await adapter.detect(NormalizedText.identity(text));

      expect(wrapped, equals(direct));
    });

    test('expose tier et name', () {
      const adapter =
          LegacyDetectorAdapter(NirDetector(), DetectorTier.structural);

      expect(adapter.tier, DetectorTier.structural);
      expect(adapter.name, 'nir');
    });

    test('name explicite prend le pas sur EntityType.name', () {
      const adapter = LegacyDetectorAdapter(
        NirDetector(),
        DetectorTier.structural,
        name: 'nir-custom',
      );

      expect(adapter.name, 'nir-custom');
    });
  });
}
