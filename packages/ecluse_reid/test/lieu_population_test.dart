import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('lieu_population (fileAssets, sans device)', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
    });

    test('populationForLieu niveau 0 (commune 57001) == 320', () {
      expect(populationForLieu(ref, const Qi(QiType.lieu, '57001')), 320);
    });

    test('populationForLieu niveau 1 (département 57) == 1051309', () {
      expect(
        populationForLieu(ref, const Qi(QiType.lieu, '57', level: 1)),
        1051309,
      );
    });

    test('populationForLieu niveau 4 (France) == totalPopulation', () {
      expect(
        populationForLieu(ref, const Qi(QiType.lieu, lieuFrance, level: 4)),
        ref.age.totalPopulation,
      );
    });

    test('populationForLieu niveau 2 (région) lève ArgumentError', () {
      expect(
        () => populationForLieu(ref, const Qi(QiType.lieu, '44', level: 2)),
        throwsArgumentError,
      );
    });

    test('depForLieu niveau 0 (commune 57001) == "57"', () {
      expect(depForLieu(ref, const Qi(QiType.lieu, '57001')), '57');
    });

    test('depForLieu niveau 1 (département 57) == "57"', () {
      expect(depForLieu(ref, const Qi(QiType.lieu, '57', level: 1)), '57');
    });

    test('depForLieu niveau 2 lève ArgumentError', () {
      expect(
        () => depForLieu(ref, const Qi(QiType.lieu, '44', level: 2)),
        throwsArgumentError,
      );
    });
  });
}
