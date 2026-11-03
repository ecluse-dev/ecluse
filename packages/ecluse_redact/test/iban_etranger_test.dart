import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// IBAN de l'espace SEPA dans `Ecluse.redact` (P2-62). Les IBAN d'essai sont
/// générés (clé mod 97 calculée), jamais copiés d'une source réelle.
String _avecCle(String pays, String bban) {
  var r = 0;
  for (final u in '$bban${pays}00'.codeUnits) {
    r = u >= 0x41 ? (r * 100 + u - 0x37) % 97 : (r * 10 + u - 0x30) % 97;
  }
  return '$pays${(98 - r).toString().padLeft(2, '0')}$bban';
}

void main() {
  final ibans = {
    'Belgique': _avecCle('BE', '539007547034'),
    'Allemagne': _avecCle('DE', '370400440532013000'),
    'Espagne': _avecCle('ES', '21000418450200051332'),
    'Italie': _avecCle('IT', 'X0542811101000000123456'),
    'Suisse': _avecCle('CH', '00762011623852957'),
    'Luxembourg': _avecCle('LU', '0019400644750000'),
  };
  ibans.forEach((pays, iban) {
    test('masqué : IBAN $pays', () async {
      final groupes =
          RegExp('.{1,4}').allMatches(iban).map((m) => m.group(0)).join(' ');
      final texte = 'Merci de virer sur $groupes avant vendredi.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, 'Merci de virer sur [IBAN_1] avant vendredi.');
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  });

  test('un IBAN français reste masqué', () async {
    final iban = _avecCle('FR', '30006000011234567890189');
    final r = await Ecluse.redact('IBAN $iban');
    expect(r.maskedText, 'IBAN [IBAN_1]');
  });

  test('clé fausse : rien n\'est masqué comme IBAN', () async {
    final r = await Ecluse.redact('IBAN BE00 5390 0754 7034');
    expect(r.maskedText, isNot(contains('[IBAN_')));
  });
}
