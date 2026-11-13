import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// Non-fuite hors du trajet du texte (P2-170, voie F5 de
/// `agent/specs/P2-169.md`) : le code de département reçu est souvent déduit
/// d'une commune du texte ; il ne sort pas dans le message d'erreur.
void main() {
  late GeoHierarchy geo;
  setUpAll(() async {
    geo = GeoHierarchy(fileAssets());
    await geo.load();
  });

  test('département inconnu : motif fixe, sans le code reçu', () {
    expect(
      () => geo.populationOfDep('ZZ'),
      throwsA(isA<ArgumentError>()
          .having((e) => e.toString(), 'texte', isNot(contains('ZZ')))
          .having((e) => e.toString(), 'texte', contains('inconnu'))),
    );
  });

  test('population incomplète : motif fixe, sans le code reçu', () {
    expect(
      () => geo.populationOfDep('976'),
      throwsA(isA<ArgumentError>()
          .having((e) => e.toString(), 'texte', isNot(contains('976')))
          .having((e) => e.toString(), 'texte', contains('incomplète'))),
    );
  });
}
