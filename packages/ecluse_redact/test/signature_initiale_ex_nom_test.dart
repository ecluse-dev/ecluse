import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Signature avec initiale (« N. Haddad ») et nom de naissance précédé de « ex- »
/// (P2-81), relevés par la relecture indépendante. La ligne qui suit une formule
/// de clôture est une signature : une initiale devant le nom ne l'empêche pas
/// d'être un nom. « (ex-Garnier) » est un nom de naissance comme « née Garnier ».
void main() {
  const masques = {
    'Bien cordialement,\nN. Haddad\nCoordinatrice': 'Haddad',
    'Cordialement,\nJ.-P. Zxqvlorn': 'Zxqvlorn',
    'Cordialement,\nA. B. Quenelle': 'Quenelle',
    'Cordialement,\nHaddad N.': 'Haddad',
    'Mme Roux (ex-Garnier)': 'Garnier',
    'Mme Dupont (ex-Martin) est venue': 'Martin',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Cordialement,\nN. B.': 'N. B.',
    'Cordialement,\nLe service': 'service',
    'Situation de l\'ex-Yougoslavie': 'Yougoslavie',
    'Un ex-patient est venu': 'ex-patient',
    'Il est ex-fumeur': 'ex-fumeur',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
