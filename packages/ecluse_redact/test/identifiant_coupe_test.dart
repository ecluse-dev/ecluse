import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Identifiant coupé par une fin de ligne (P2-38). L'extraction d'un PDF ou le
/// retour automatique d'un traitement de texte coupent souvent un IBAN, un NIR
/// ou un téléphone entre deux groupes de chiffres : aucun détecteur ne le
/// voyait. La coupure n'est neutralisée que dans la vue de détection, entre deux
/// chiffres (ou après `/ . -`) : le texte n'est jamais réécrit et un span n'a
/// toujours aucune raison de traverser une ligne de texte ordinaire.
void main() {
  const coupes = {
    'Tél : 01 99 00\n12 34': 'TELEPHONE',
    'Tél : 01 99\n00 12 34': 'TELEPHONE',
    'Tél : 01 99 00 12-\n34': 'TELEPHONE',
    'Tél : 01 99 00 \n 12 34': 'TELEPHONE',
    'Tél : 01 99 00\r\n12 34': 'TELEPHONE',
    'NIR : 2 55 08 14\n168 025 38': 'NIR',
    'NIR : 2 55 08\n14 168 025 38': 'NIR',
    'IBAN : FR76 3000 6000\n0112 3456 7890 189': 'IBAN',
    'IBAN : FR76 3000 6000 0112\n3456 7890 189': 'IBAN',
    'Né le 12/03/\n1950': 'DATE_NAISSANCE',
    'Né le 12 03\n1950': 'DATE_NAISSANCE',
  };
  for (final MapEntry(key: texte, value: type) in coupes.entries) {
    test('masqué : ${texte.replaceAll('\n', '\\n').replaceAll('\r', '\\r')}',
        () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, contains('[${type}_1]'), reason: r.maskedText);
      expect(r.maskedText, isNot(contains(RegExp(r'\d{2}'))),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'Total : 150\nPage 12',
    'Chambre 12\nLit 3\nÉtage 4',
    'Facture n° 2024\n0012 articles',
    'Tableau\n12\n34\n56',
  ];
  for (final texte in intacts) {
    test('inchangé : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }

  test('deux numéros sur deux lignes restent deux numéros', () async {
    final r = await Ecluse.redact('Tél : 01 99 00 12 34\n01 99 00 56 78');
    expect(r.maskedText, 'Tél : [TELEPHONE_1]\n[TELEPHONE_2]');
  });
}
