import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('estimate (fileAssets, sans device)', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
    });

    test('Cas A : pneumologue ("11") + département 57 -> f == 51', () {
      final e = estimate(ref, const [
        Qi(QiType.profession, '11'),
        Qi(QiType.lieu, '57', level: 1),
      ]);
      expect(e.f, 51);
      expect(e.upperBound, isTrue);
      expect(e.dominant, QiType.profession);
      expect(e.notes, contains(honestyContract));
      expect(e.notes, contains(honestyUpperBoundAddendum));
    });

    test('Cas A via lieu de niveau commune (Thionville, dep 57) -> f == 51',
        () {
      final e = estimate(ref, const [
        Qi(QiType.profession, '11'),
        Qi(QiType.lieu, '57672'),
      ]);
      expect(e.f, 51);
    });

    test('Cas A, sentinelle professionnelDeSante -> f == 5107', () {
      final e = estimate(ref, const [
        Qi(QiType.profession, professionnelDeSante, level: 2),
        Qi(QiType.lieu, '57', level: 1),
      ]);
      expect(e.f, 5107);
    });

    test('Cas B : Aboncourt (57001) + 89 ans -> f ≈ 1,07, bande eleve', () {
      final e = estimate(ref, const [
        Qi(QiType.age, '89'),
        Qi(QiType.lieu, '57001'),
      ]);
      expect(e.f, closeTo(1.0713, 0.001));
      expect(e.band, RiskBand.eleve);
      expect(e.dominant, QiType.lieu);
      expect(e.upperBound, isFalse);
    });

    test('Cas B, âge seul (89 ans, pas de lieu)', () {
      final e = estimate(ref, const [Qi(QiType.age, '89')]);
      expect(e.f, closeTo(ref.age.totalPopulation * ref.age.shareAtAge(89), 1));
      expect(e.notes.any((n) => n.contains('Aucun lieu')), isTrue);
    });

    test('Cas B, lieu seul (Aboncourt, pas d\'âge) -> f == 320', () {
      final e = estimate(ref, const [Qi(QiType.lieu, '57001')]);
      expect(e.f, 320);
      expect(e.notes.any((n) => n.contains('Aucun âge')), isTrue);
    });

    test('liste vide -> f == totalPopulation, dominant == null', () {
      final e = estimate(ref, const []);
      expect(e.f, ref.age.totalPopulation.toDouble());
      expect(e.dominant, isNull);
      expect(e.band, RiskBand.faible);
    });

    test('type en double lève ArgumentError', () {
      expect(
        () => estimate(ref, const [Qi(QiType.age, '10'), Qi(QiType.age, '20')]),
        throwsArgumentError,
      );
    });

    test('profession sans lieu lève ArgumentError', () {
      expect(
        () => estimate(ref, const [Qi(QiType.profession, '11')]),
        throwsArgumentError,
      );
    });

    test('code profession inconnu lève ArgumentError', () {
      expect(
        () => estimate(ref, const [
          Qi(QiType.profession, '99'),
          Qi(QiType.lieu, '57', level: 1),
        ]),
        throwsArgumentError,
      );
    });
  });
}
