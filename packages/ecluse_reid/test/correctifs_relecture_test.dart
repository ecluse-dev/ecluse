import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Défauts relevés à la relecture d'octobre 2026 (P1-27), chacun reproduit
/// avant correction. Données synthétiques ou publiques embarquées.
void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  group('paliers d\'âge : la classe contient toujours la personne', () {
    test('67 ans : 65-69, 60-69, puis retrait (jamais « 0-64 »)', () {
      final r1 = nextRung(ref, const Qi(QiType.age, '67'))!;
      expect(r1, const Qi(QiType.age, '65-69', level: 1));
      final r2 = nextRung(ref, r1)!;
      expect(r2, const Qi(QiType.age, '60-69', level: 2));
      final r3 = nextRung(ref, r2)!;
      // 60-69 chevauche le seuil de 65 ans : ni « senior » ni « non-senior »
      // ne contient à coup sûr la personne -> retrait.
      expect(r3, const Qi(QiType.age, qiRetraitValue, level: 4));
    });

    test('62 ans : 60-64, 60-69, puis retrait', () {
      final r1 = nextRung(ref, const Qi(QiType.age, '62'))!;
      final r2 = nextRung(ref, r1)!;
      expect(r2, const Qi(QiType.age, '60-69', level: 2));
      expect(nextRung(ref, r2)!.value, qiRetraitValue);
    });

    test('30 ans : 30-39 -> non-senior 0-64', () {
      final r2 = nextRung(ref, nextRung(ref, const Qi(QiType.age, '30'))!)!;
      expect(r2, const Qi(QiType.age, '30-39', level: 2));
      expect(nextRung(ref, r2), const Qi(QiType.age, '0-64', level: 3));
    });

    test('89 ans inchangé : 80-89 -> 65-130', () {
      final r2 = nextRung(ref, nextRung(ref, const Qi(QiType.age, '89'))!)!;
      expect(nextRung(ref, r2), const Qi(QiType.age, '65-130', level: 3));
    });
  });

  group('population des départements incomplète : refus explicite', () {
    for (final dep in ['75', '13', '69', '976']) {
      test('département $dep -> ArgumentError, pas F = 0', () {
        expect(
          () => estimate(ref, [
            Qi(QiType.lieu, dep, level: 1),
            const Qi(QiType.age, '89'),
          ]),
          throwsArgumentError,
        );
      });
    }

    test('département complet (57) inchangé', () {
      final e = estimate(ref, const [
        Qi(QiType.lieu, '57', level: 1),
        Qi(QiType.age, '89'),
      ]);
      expect(e.f, greaterThan(0));
    });

    test('département inconnu -> ArgumentError', () {
      expect(
        () => estimate(ref, const [Qi(QiType.lieu, 'ZZ', level: 1)]),
        throwsArgumentError,
      );
    });
  });

  group('Cas A : la borne haute ne dépasse pas la population du lieu', () {
    test('pharmacien dans une commune de 320 habitants', () {
      final e = estimate(ref, const [
        Qi(QiType.profession, 'pharmacien'),
        Qi(QiType.lieu, '57001'), // Aboncourt
      ]);
      expect(e.f, lessThanOrEqualTo(ref.geo.population('57001')!.toDouble()));
      expect(e.notes.join(' '), contains('population du lieu'));
    });

    test('grande commune : borne inchangée (effectif du département)', () {
      final e = estimate(ref, const [
        Qi(QiType.profession, '11'),
        Qi(QiType.lieu, '57672'), // Thionville
      ]);
      expect(e.f, 51);
    });
  });

  group('entrées invalides : ArgumentError, jamais une exception brute', () {
    for (final entree in {
      'âge non numérique': const Qi(QiType.age, 'abc'),
      'âge négatif': const Qi(QiType.age, '-5'),
      'âge démesuré': const Qi(QiType.age, '200'),
      'tranche sans tiret au niveau 1': const Qi(QiType.age, '89', level: 1),
      'niveau de lieu négatif': const Qi(QiType.lieu, '57001', level: -1),
    }.entries) {
      test(entree.key, () {
        expect(() => estimate(ref, [entree.value]), throwsArgumentError);
      });
    }
  });

  group('une « généralisation » qui fait baisser F n\'est jamais retenue', () {
    test('professionnel de santé à Paris : aucun candidat retenu', () {
      const qis = [
        Qi(QiType.profession, professionnelDeSante, level: 2),
        Qi(QiType.lieu, '75', level: 1),
      ];
      final baseline = estimate(ref, qis);
      final candidates = simulateOneStep(ref, qis, baseline);
      for (final c in candidates.where((c) => c.retenu)) {
        expect(c.fAfter, greaterThan(c.fBefore),
            reason: 'candidat retenu alors que F baisse : ${c.raison}');
      }
    });
  });
}
