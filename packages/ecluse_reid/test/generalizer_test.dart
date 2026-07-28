import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('generalizer (fileAssets, sans device)', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
    });

    test('nextRung lieu : commune -> département', () {
      final rung = nextRung(ref, const Qi(QiType.lieu, '57001'));
      expect(rung, const Qi(QiType.lieu, '57', level: 1));
    });

    test('nextRung lieu : département -> France', () {
      final rung = nextRung(ref, const Qi(QiType.lieu, '57', level: 1));
      expect(rung, const Qi(QiType.lieu, lieuFrance, level: 4));
    });

    test('nextRung lieu : France -> null (dernier palier)', () {
      final rung = nextRung(ref, const Qi(QiType.lieu, lieuFrance, level: 4));
      expect(rung, isNull);
    });

    test(
        'nextRung age : exact -> tranche 5 ans -> tranche 10 ans -> senior -> retrait',
        () {
      final r1 = nextRung(ref, const Qi(QiType.age, '89'))!;
      expect(r1, const Qi(QiType.age, '85-89', level: 1));
      final r2 = nextRung(ref, r1)!;
      expect(r2, const Qi(QiType.age, '80-89', level: 2));
      final r3 = nextRung(ref, r2)!;
      expect(r3, const Qi(QiType.age, '65-130', level: 3));
      final r4 = nextRung(ref, r3)!;
      expect(r4, const Qi(QiType.age, qiRetraitValue, level: 4));
      expect(nextRung(ref, r4), isNull);
    });

    test(
        'nextRung profession : spécialité -> toute spécialité -> professionnel de santé -> retrait',
        () {
      final r1 = nextRung(ref, const Qi(QiType.profession, '11'))!;
      expect(r1,
          const Qi(QiType.profession, professionToutesSpecialites, level: 1));
      final r2 = nextRung(ref, r1)!;
      expect(r2, const Qi(QiType.profession, professionnelDeSante, level: 2));
      final r3 = nextRung(ref, r2)!;
      expect(r3, const Qi(QiType.profession, qiRetraitValue, level: 3));
      expect(nextRung(ref, r3), isNull);
    });

    test(
        'simulateOneStep Cas B Aboncourt : lieu retenu, fAfter ≈ 3520 '
        '(le spec illustre ≈1760 en supposant un facteur sexe ×0,5 hors '
        'périmètre §1 ce jalon)', () {
      final qis = const [Qi(QiType.age, '89'), Qi(QiType.lieu, '57001')];
      final baseline = estimate(ref, qis);
      final candidates = simulateOneStep(ref, qis, baseline);

      final lieuCandidate = candidates.firstWhere((c) => c.type == QiType.lieu);
      expect(lieuCandidate.retenu, isTrue);
      expect(lieuCandidate.fAfter, closeTo(3519.56, 1));

      final ageCandidate = candidates.firstWhere((c) => c.type == QiType.age);
      expect(ageCandidate.retenu, isFalse);
    });

    test(
        'simulateOneStep Cas A : profession retenu, fAfter == 2894 ; lieu '
        'non exploitable (généraliser au-delà du département casse la '
        'résolution du département requise par le Cas A)', () {
      final qis = const [
        Qi(QiType.profession, '11'),
        Qi(QiType.lieu, '57', level: 1),
      ];
      final baseline = estimate(ref, qis);
      final candidates = simulateOneStep(ref, qis, baseline);

      final professionCandidate =
          candidates.firstWhere((c) => c.type == QiType.profession);
      expect(professionCandidate.retenu, isTrue);
      expect(professionCandidate.fAfter, 2894);

      final lieuCandidate = candidates.firstWhere((c) => c.type == QiType.lieu);
      expect(lieuCandidate.fAfter, isNull);
      expect(lieuCandidate.retenu, isFalse);
    });

    test(
        'QI déjà totalement généralisé (lieu France seul) -> aucun candidat retenu',
        () {
      final qis = const [Qi(QiType.lieu, lieuFrance, level: 4)];
      final baseline = estimate(ref, qis);
      final candidates = simulateOneStep(ref, qis, baseline);
      expect(candidates.single.to, isNull);
      expect(candidates.single.fAfter, isNull);
      expect(candidates.single.retenu, isFalse);
    });
  });
}
