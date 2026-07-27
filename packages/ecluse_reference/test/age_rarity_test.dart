import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

void main() {
  group('AgeRarity (fileAssets, sans device)', () {
    late AgeRarity age;

    setUpAll(() async {
      age = AgeRarity(fileAssets());
      await age.load();
    });

    test('countAtAge(94) == 105253', () {
      expect(age.countAtAge(94), 105253);
    });

    test('totalPopulation ~= 69 M', () {
      expect(age.totalPopulation, 69079962);
    });

    test('shareAtAge : cohérent avec countAtAge/total', () {
      expect(age.shareAtAge(94), age.countAtAge(94)! / age.totalPopulation);
    });

    test('shareAtAge : 0.0 pour un âge inconnu', () {
      expect(age.shareAtAge(999), 0.0);
    });
  });
}
