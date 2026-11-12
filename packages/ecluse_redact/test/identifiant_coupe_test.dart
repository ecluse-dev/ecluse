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

  // P2-152 : coupure après la lettre d'un groupe (lettre de compte d'un IBAN,
  // `2A`/`2B` d'un NIR corse) ou bordée d'espaces insécables. Clés calculées,
  // identifiants synthétiques.
  const coupesLettreOuInsecable = {
    'compte FR76 4347 9463 461K\n4056 8299 690.': 'IBAN',
    'compte FR76 4347 9463\n461K 4056 8299 690.': 'IBAN',
    'IBAN FR16\u00A08202\u00A03337\u00A07460\n\u00A08432\u00A05621\u00A0686.':
        'IBAN',
    'IBAN FR16 8202 3337 7460\u202F\n8432 5621 686.': 'IBAN',
    'NIR 2  41  01  2A \n073  561  75, ce jour': 'NIR',
    'NIR 2\u00A056\u00A007\u00A016\u00A0561\n\u00A0259\u00A020, ce jour': 'NIR',
  };
  for (final MapEntry(key: texte, value: type)
      in coupesLettreOuInsecable.entries) {
    test('masqué (P2-152) : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, contains('[${type}_1]'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // P2-158 : coupure juste avant un groupe qui commence par **une** lettre
  // suivie d'un chiffre (« …0270⏎D932… » : le groupe d'un IBAN peut porter
  // une lettre de compte). Clé calculée, identifiant synthétique.
  const coupesAvantLettre = {
    'compte FR45 4347 9463 0270\nD932 8299 690.': 'IBAN',
    'compte FR45 4347 9463 0270\n D932 8299 690.': 'IBAN',
    'compte FR45 4347 9463 0270 \r\nD932 8299 690.': 'IBAN',
  };
  for (final MapEntry(key: texte, value: type) in coupesAvantLettre.entries) {
    test('masqué (P2-158) : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, contains('[${type}_1]'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intactsLettre = [
    'Chambre 12B\n34 lits',
    'Bâtiment 3A\n12 logements',
    'Vol AF12\nB7 porte',
    'Salle 4\nA2 fermée',
    // P2-158 : une lettre isolée suivie d'un chiffre après un chiffre.
    'Vol 12\nB7 porte',
    'le 3\nC4 du plan',
    'Étage 2\nA1 : bureaux',
  ];
  for (final texte in intactsLettre) {
    test('inchangé (P2-152) : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte);
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
