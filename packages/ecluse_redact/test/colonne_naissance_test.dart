import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Colonne « Date de naissance » d'un tableau (P2-78). Les colonnes de noms d'un
/// tableau à en-tête étaient lues (P2-61), pas les dates : la cellule d'une
/// colonne « Date de naissance », « Né(e) le », « DDN »… restait en clair, faute
/// d'un contexte de naissance dans la cellule. Le contexte est l'en-tête.
void main() {
  const masques = {
    'Nom;Prénom;Date de naissance\nQuenelle;Zorglub;12/03/1938\n': '12/03/1938',
    'Nom\tPrénom\tNé(e) le\tTél\nROUX\tHélène\t12/03/1938\t0612345678\n':
        '12/03/1938',
    'Nom,Prénom,DDN\nQuenelle,Zorglub,12-03-1938\n': '12-03-1938',
    'Nom;Naissance;Service\nQuenelle;12.03.1938;Cardio\n': '12.03.1938',
    'Nom;Prénom;Date de naissance\nQuenelle;Zorglub;12 mars 1938\n':
        '12 mars 1938',
    'Nom;Prénom;Date de naissance\nQuenelle;Zorglub;1938-03-12\n': '1938-03-12',
    'Id;DN;Chambre\n1;12/03/1938;12\n': '12/03/1938',
    'Nom;Prénom;Date de naissance\n"Quenelle";"Zorglub";"12/03/1938"\n':
        '12/03/1938',
    'Nom;Date de naissance\nQuenelle;12/03/1938\nDupont;01/02/1940\n':
        '01/02/1940',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎').replaceAll('\t', '→')}',
        () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, contains('[DATE_NAISSANCE_'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    // Colonnes qui ne sont pas des naissances.
    'Nom;Prénom;Date de visite\nQuenelle;Zorglub;12/03/2026\n': '12/03/2026',
    'Id;Date d\'entrée;Service\n1;12/03/2026;Cardio\n': '12/03/2026',
    'Médicament;Date de péremption\nAspirine;12/2027\n': '12/2027',
    // Cellule de naissance qui n'est pas une date.
    'Nom;Date de naissance\nQuenelle;inconnue\n': 'inconnue',
    'Nom;Date de naissance\nQuenelle;\n': 'Date de naissance',
    // Pas un tableau.
    'Date de naissance;ou date de visite : voir ci-dessous': 'voir ci-dessous',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('[DATE_NAISSANCE_')),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('tableau HTML à en-tête <th>', () async {
    const texte = '<table><tr><th>Nom</th><th>Date de naissance</th></tr>'
        '<tr><td>Quenelle</td><td>12/03/1938</td></tr></table>';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, isNot(contains('12/03/1938')), reason: r.maskedText);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('refus explicite si la rangée est ambiguë (colonnes manquantes)',
      () async {
    await expectLater(
      Ecluse.redact(
          'Nom;Prénom;Date de naissance\nQuenelle;Zorglub;12/03/1938\nMartin;Hector\n'),
      throwsA(isA<TableauAmbiguException>()),
    );
  });
}
