import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  test('band5(89) == (85, 89)', () => expect(band5(89), (85, 89)));
  test('band10(89) == (80, 89)', () => expect(band10(89), (80, 89)));
  test('seniorBand(89) == (65, 130)', () => expect(seniorBand(89), (65, 130)));
  test('seniorBand(30) == (0, 64)', () => expect(seniorBand(30), (0, 64)));

  group('shareForRange (fileAssets, sans device)', () {
    late AgeRarity age;
    setUpAll(() async {
      age = AgeRarity(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await age.load();
    });

    test('shareForRange(89,89) == shareAtAge(89)', () {
      expect(shareForRange(age, 89, 89), age.shareAtAge(89));
    });

    test('shareForRange(85,89) >= shareAtAge(89)', () {
      expect(
          shareForRange(age, 85, 89), greaterThanOrEqualTo(age.shareAtAge(89)));
    });
  });
}
