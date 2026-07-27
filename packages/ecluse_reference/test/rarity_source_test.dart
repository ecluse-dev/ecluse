import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

void main() {
  group('RaritySource (fileAssets, sans device)', () {
    late RaritySource rarity;

    setUpAll(() async {
      rarity = RaritySource(fileAssets());
      await rarity.load();
    });

    test('medecinsCount("57","11") == 51 (Pneumologie/Moselle)', () {
      expect(rarity.medecinsCount('57', '11'), 51);
    });

    test('specialtyLabel("11") == "Pneumologie"', () {
      expect(rarity.specialtyLabel('11'), 'Pneumologie');
    });

    test('specialtyCodes contient les 14 codes', () {
      expect(rarity.specialtyCodes(), hasLength(14));
    });

    test('professionCount("pharmacien","57") == 976', () {
      expect(rarity.professionCount('pharmacien', '57'), 976);
    });

    test('professions contient pharmacien', () {
      expect(rarity.professions(), contains('pharmacien'));
    });
  });
}
