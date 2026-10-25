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
        'extractLieu(Aboncourt) : nom ambigu -> le cas le plus prudent '
        '(plus petite population), jamais une liste vide', () {
      final qis = extractLieu(ref, 'Elle habite à Aboncourt.');
      final candidats = ref.geo.communesByName('Aboncourt');
      expect(candidats.length, greaterThan(1));
      final plusPetite = candidats
          .where((c) => c.pmun != null)
          .reduce((a, b) => a.pmun! <= b.pmun! ? a : b);
      expect(qis, contains(Qi(QiType.lieu, plusPetite.code)));
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

    group('communes homonymes : ambiguïté signalée', () {
      test('extractLieuAmbigu liste les candidats d\'un nom ambigu', () {
        final ambigus = extractLieuAmbigu(ref, 'Il vit à Saint-Denis.');
        expect(ambigus, isNotEmpty);
        expect(ambigus.first.nom, 'Saint-Denis');
        expect(ambigus.first.candidats.length, greaterThan(1));
        final pops = ambigus.first.candidats
            .where((c) => c.pmun != null)
            .map((c) => c.pmun!);
        expect(ambigus.first.plusPetite!.pmun,
            pops.reduce((a, b) => a < b ? a : b));
      });

      test('un nom unique n\'est pas ambigu', () {
        expect(extractLieuAmbigu(ref, 'Elle habite à Thionville.'), isEmpty);
      });

      test('Saint-Denis : F = plus petite population, jamais la France', () {
        final qis = extractQis(ref, 'Il vit à Saint-Denis.');
        final e = estimate(ref, qis);
        final plusPetite =
            extractLieuAmbigu(ref, 'Il vit à Saint-Denis.').first.plusPetite!;
        expect(e.f, plusPetite.pmun!.toDouble());
        expect(e.f, lessThan(50000000));
      });

      test('extractQisDetailed renvoie un avertissement explicite', () {
        final r = extractQisDetailed(ref, 'Il vit à Saint-Denis.');
        expect(r.avertissements, hasLength(1));
        expect(r.avertissements.single, contains('Saint-Denis'));
        expect(r.avertissements.single, contains('ambigu'));
        expect(r.qis.any((q) => q.type == QiType.lieu), isTrue);
      });

      test('sans ambiguïté : aucun avertissement', () {
        final r = extractQisDetailed(ref, 'Elle habite à Thionville.');
        expect(r.avertissements, isEmpty);
      });
    });
  });
}
