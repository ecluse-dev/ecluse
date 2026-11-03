import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Une entité qui en chevauche partiellement une autre ne doit jamais la
/// faire disparaître : `resolveOverlaps` garde la plus longue et supprime
/// l'autre en entier, donc tout ce qui est supprimé reste en clair (fuite).
void main() {
  Future<String> masque(String texte) async =>
      (await Ecluse.redact(texte)).maskedText;

  group('adresse puis entité voisine', () {
    test('email après une adresse', () async {
      final m = await masque(
          '12 rue des Lilas, 75015 Paris et jean.dupont@example.fr');
      expect(m, isNot(contains('dupont')));
      expect(m, isNot(contains('example.fr')));
      expect(m, contains('[EMAIL_1]'));
    });

    test('nom après une adresse', () async {
      final m =
          await masque('12 rue des Lilas, 75015 Paris et Mme Sophie Lambert');
      expect(m, isNot(contains('Lambert')));
      expect(m, isNot(contains('Sophie')));
    });

    test('nom avec titre après une commune', () async {
      final m =
          await masque('Habite 75015 Paris puis a rencontré Dr Nadia Costa');
      expect(m, isNot(contains('Costa')));
      expect(m, isNot(contains('Nadia')));
    });
  });

  group('nom puis établissement', () {
    const cas = {
      'civilité + nom + Foyer': 'M. Marc Herbin Foyer Les Tilleuls',
      'titre + nom + Foyer': 'Dr Nadia Costa Foyer Les Tilleuls',
      'civilité + nom + Clinique': 'Mme Sophie Lambert Clinique du Parc',
      'civilité + nom + Foyer 2': 'Mme Sophie Lambert Foyer Les Pins',
    };
    cas.forEach((nom, texte) {
      test(nom, () async {
        final m = await masque(texte);
        // Aucun mot du nom ni de l'établissement ne doit rester en clair.
        for (final mot in texte.split(' ')) {
          if (const {'M.', 'Mme', 'Dr', 'du', 'Les'}.contains(mot)) continue;
          expect(m, isNot(contains(mot)), reason: '$texte -> $m');
        }
      });
    });
  });
}
