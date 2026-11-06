import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Durées et communes-mots courants (P2-136) : 412 extractions à tort sur le
/// corpus témoin de QI avant, 57 après.
void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  List<QiType> types(String t) =>
      [for (final s in extractQiSpans(ref, t).spans) s.type];

  test('durée : pas un âge', () {
    for (final texte in [
      'Le contrat est signé pour 9 ans, renouvelable.',
      "La dernière évaluation date d'il y a 3 ans.",
      'Le service existe depuis 23 ans.',
      'Les locaux seront refaits dans 2 ans.',
      'Elle travaille ici depuis plus de 10 ans.',
    ]) {
      expect(types(texte), isNot(contains(QiType.age)), reason: texte);
    }
  });

  test('âge : toujours lu', () {
    for (final texte in [
      'Mme Verdier, 74 ans, est arrivée.',
      'Elle a 74 ans.',
      'Patient âgé de 74 ans.',
    ]) {
      expect(types(texte), contains(QiType.age), reason: texte);
    }
  });

  test('commune-mot courant sans préposition de lieu : pas un lieu', () {
    expect(types('Tours de garde : le planning est affiché.'), isEmpty);
    expect(types('Nuits de garde à revoir.'), isEmpty);
    expect(
        extractLieu(ref, 'Tours de garde : le planning est affiché.'), isEmpty);
  });

  test('commune-mot courant après « à », « habite » : un lieu', () {
    expect(types('Elle habite à Tours.'), [QiType.lieu]);
    expect(types('M. Faure est né à Orange.'), [QiType.lieu]);
  });
}
