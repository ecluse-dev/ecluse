import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

void main() {
  group('FirstNameGazetteer (fileAssets, sans device)', () {
    late FirstNameGazetteer firstNames;

    setUpAll(() async {
      firstNames = FirstNameGazetteer(fileAssets());
      await firstNames.load();
    });

    test('isKnownFirstName("Hélène") == true', () {
      expect(firstNames.isKnownFirstName('Hélène'), isTrue);
    });

    test('isKnownFirstName renvoie false pour un mot inconnu', () {
      expect(firstNames.isKnownFirstName('Zzzxxxqqq'), isFalse);
    });
  });
}
