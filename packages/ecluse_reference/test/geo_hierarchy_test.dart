import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

void main() {
  group('GeoHierarchy (fileAssets, sans device)', () {
    late GeoHierarchy geo;

    setUpAll(() async {
      geo = GeoHierarchy(fileAssets());
      await geo.load();
    });

    test('communeByCode("57672") == Thionville, pmun == 42658', () {
      final commune = geo.communeByCode('57672');
      expect(commune, isNotNull);
      expect(commune!.libelle, 'Thionville');
      expect(commune.pmun, 42658);
    });

    test('communesByName("thionville") non vide', () {
      expect(geo.communesByName('thionville'), isNotEmpty);
    });

    test('regionOfDep + regionLabel : 57 -> Grand Est', () {
      final reg = geo.regionOfDep('57');
      expect(reg, isNotNull);
      expect(geo.regionLabel(reg!), 'Grand Est');
    });

    test('generalize : commune -> dep -> région -> zone -> France', () {
      expect(geo.generalize('57672', 0), 'Thionville');
      expect(geo.generalize('57672', 1), '57');
      expect(geo.generalize('57672', 2), 'Grand Est');
      expect(geo.generalize('57672', 3), 'Est');
      expect(geo.generalize('57672', 4), 'France');
    });

    test('population nulle pour Marseille (arrondissements)', () {
      expect(geo.population('13055'), isNull);
    });

    test('populationOfDep("57") == 1051309 (population totale de la Moselle)',
        () {
      expect(geo.populationOfDep('57'), 1051309);
    });
  });

  test('accès avant load() lève une StateError', () {
    final geo = GeoHierarchy(fileAssets());
    expect(() => geo.communeByCode('57672'), throwsStateError);
  });
}
