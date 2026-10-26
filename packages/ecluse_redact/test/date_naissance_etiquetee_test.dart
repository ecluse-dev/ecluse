import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Date de naissance séparée de son étiquette (P2-39). Dans un formulaire ou
/// un tableau, la valeur suit l'étiquette après un `|`, un `;` ou sur la ligne
/// suivante : le détecteur n'admettait que des espaces entre les deux.
void main() {
  const masques = [
    'Date de naissance :\n12/03/1950',
    'Date de naissance\n12/03/1950',
    'Date de naissance :\r\n12/03/1950',
    'Date de naissance | 12/03/1950',
    '| Date de naissance | 12/03/1950 |',
    'Date de naissance ; 12/03/1950',
    'Date de naissance;12/03/1950',
    'DDN :\n12/03/1950',
    'Né le :\n12 mars 1950',
    'Date de naissance :\n1950-03-12',
  ];
  for (final texte in masques) {
    test('masqué : ${texte.replaceAll('\n', '\\n').replaceAll('\r', '\\r')}',
        () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, contains('[DATE_NAISSANCE_1]'),
          reason: r.maskedText);
      expect(r.maskedText, isNot(contains('1950')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'Date de naissance :\n\n12/03/1950',
    'Date de naissance\nNom : Dupont\n12/03/1950',
    'Date de naissance , 12/03/1950',
    'La naissance du projet\n12/03/1950',
    'Rendez-vous le 12/03/1950',
    'Date de naissance\n\n\n12/03/1950',
  ];
  for (final texte in intacts) {
    test('inchangé : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }
}
