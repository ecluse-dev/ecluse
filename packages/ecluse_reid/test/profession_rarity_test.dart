import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('profession_rarity (fileAssets, sans device)', () {
    late RaritySource rarity;
    setUpAll(() async {
      rarity =
          RaritySource(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await rarity.load();
    });

    test('medecinTouteSpecialite("57") == 2894', () {
      expect(medecinTouteSpecialite(rarity, '57'), 2894);
    });

    test('professionnelDeSanteCount("57") == 5107', () {
      expect(professionnelDeSanteCount(rarity, '57'), 5107);
    });
  });
}
