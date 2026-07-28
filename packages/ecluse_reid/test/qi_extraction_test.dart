import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('qi_extraction (fileAssets, sans device)', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
    });

    test('extractAge("Le patient a 89 ans.") -> [Qi(age, "89")]', () {
      expect(extractAge('Le patient a 89 ans.'), [const Qi(QiType.age, '89')]);
    });

    test('extractLieu("Elle habite à Thionville.") -> [Qi(lieu, "57672")]', () {
      final qis = extractLieu(ref, 'Elle habite à Thionville.');
      expect(qis, contains(const Qi(QiType.lieu, '57672')));
    });

    test(
        'extractLieu("Elle habite à Aboncourt.") -> liste vide '
        '(homonyme Moselle/Meurthe-et-Moselle, ignoré, cf. limitation '
        'documentée)', () {
      expect(extractLieu(ref, 'Elle habite à Aboncourt.'), isEmpty);
    });

    test('extractLieu sans commune -> liste vide, pas d\'exception', () {
      expect(extractLieu(ref, 'Il fait beau aujourd\'hui.'), isEmpty);
    });

    test('extractProfession("Il est pneumologue.") -> [Qi(profession, "11")]',
        () {
      expect(
        extractProfession(ref, 'Il est pneumologue.'),
        contains(const Qi(QiType.profession, '11')),
      );
    });

    test('extractProfession("Elle est pharmacienne.") -> pharmacien', () {
      expect(
        extractProfession(ref, 'Elle est pharmacienne.'),
        contains(const Qi(QiType.profession, 'pharmacien')),
      );
    });

    test('extractQis combine les trois extractions', () {
      final qis = extractQis(
        ref,
        'Le patient, pneumologue à Thionville, a 89 ans.',
      );
      expect(qis, contains(const Qi(QiType.profession, '11')));
      expect(qis, contains(const Qi(QiType.lieu, '57672')));
      expect(qis, contains(const Qi(QiType.age, '89')));
    });
  });
}
