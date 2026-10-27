import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Tableaux et blocs HTML (P2-63). Une étiquette et sa valeur dans deux cellules
/// (`<td>Date de naissance</td><td>12/03/1950</td>`) ou deux blocs voisins
/// laissaient la valeur en clair : les balises s'interposaient. Dans la vue de
/// détection seulement, les balises de structure sans attribut libre sont
/// retirées et remplacées par un séparateur (`:` entre deux cellules, saut de
/// ligne entre deux blocs, espace pour `&nbsp;`). Le texte n'est jamais réécrit.
void main() {
  const masques = {
    '<tr><th>Date de naissance</th><td>12/03/1950</td></tr>': '12/03/1950',
    '<tr><td>Date de naissance :</td><td>12/03/1950</td></tr>': '12/03/1950',
    '<td class="x">Date de naissance</td><td style="a:b">12/03/1950</td>':
        '12/03/1950',
    '<p>Né le&nbsp;12/03/1950</p>': '12/03/1950',
    '<td>Né le</td><td>12/03/1950</td>': '12/03/1950',
    '<td>Téléphone</td><td>06 12 34 56 78</td>': '06 12 34 56 78',
    '<div>12 rue des Lilas</div><div>75011 Paris</div>': 'Lilas',
    '<p>12 rue des Lilas<br>75011 Paris</p>': 'Lilas',
    '<td>Prénom</td><td>Zorglub</td><td>Nom</td><td>Quenelle</td>': 'Quenelle',
    '<table><tr><td>Nom</td><td>Quenelle</td></tr><tr><td>Prénom</td>'
        '<td>Zorglub</td></tr></table>': 'Quenelle',
    '<tr><th>Nom</th><th>Prénom</th></tr><tr><td>Quenelle</td>'
        '<td>Zorglub</td></tr>': 'Zorglub',
    '<td>IPP</td><td>12345678</td>': '12345678',
    '<a href="mailto:z@exemple.fr">écrire</a>': 'z@exemple.fr',
    '<z@exemple.fr>': 'z@exemple.fr',
    '<td title="Mme Dupont">x</td>': 'Dupont',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('l\'en-tête d\'un tableau n\'est pas pris pour un nom', () async {
    const texte = '<tr><th>Nom</th><th>Prénom</th></tr><tr><td>Quenelle</td>'
        '<td>Zorglub</td></tr>';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, contains('<th>Nom</th>'));
    expect(r.maskedText, contains('<th>Prénom</th>'));
  });

  const intacts = {
    '2 < 3 et 4 > 1': '2 < 3 et 4 > 1',
    '<td>Aspirine</td><td>100 mg</td>': 'Aspirine',
    '<td>Nom</td><td>Aspirine</td>': 'Aspirine',
    '<tr><td>Service</td><td>Cardiologie</td></tr>': 'Cardiologie',
    '<p>Rendez-vous le 12/03/1950</p>': '12/03/1950',
    'a&nbsp;b': 'a&nbsp;b',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
