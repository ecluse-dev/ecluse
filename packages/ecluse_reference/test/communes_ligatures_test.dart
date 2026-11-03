import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: 'assets'));
    await ref.preload();
  });

  for (final nom in [
    'Nœux-les-Mines',
    'Noeux-les-Mines',
    'NŒUX-LES-MINES',
    'Schœlcher',
    'Vandœuvre-lès-Nancy',
    'Marcq-en-Barœul',
  ]) {
    test('commune « $nom » retrouvée par son nom', () {
      expect(ref.geo.communesByName(nom), isNotEmpty);
    });
  }

  test('sans ligature : inchangé', () {
    expect(ref.geo.communesByName('Thionville'), isNotEmpty);
  });
}
