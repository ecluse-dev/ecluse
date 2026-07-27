import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

void main() {
  test('EcluseReference.preload() réchauffe les 4 chargeurs', () async {
    final ref = EcluseReference(fileAssets());
    await ref.preload();

    expect(ref.geo.communeByCode('57672')!.libelle, 'Thionville');
    expect(ref.rarity.medecinsCount('57', '11'), 51);
    expect(ref.age.countAtAge(94), 105253);
    expect(ref.firstNames.isKnownFirstName('Hélène'), isTrue);
  });

  test('chargement paresseux : load() individuel suffit sans preload()',
      () async {
    final ref = EcluseReference(fileAssets());
    await ref.rarity.load();

    expect(ref.rarity.professionCount('pharmacien', '57'), 976);
  });
}
