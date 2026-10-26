import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Variantes d'écriture du contexte et de la date de naissance (P2-43) :
/// département après le lieu, abréviations, jour de semaine, année à deux
/// chiffres avec le mois en lettres, mois anglais derrière « DOB ».
void main() {
  const masques = [
    'né(e) à Lyon (69) le 12/03/1950',
    'née à Saint-Étienne (42) le 12 mars 1950',
    'né à Paris (75) le 12/03/1950',
    'Date de naiss. : 12/03/1950',
    'Date de naiss : 12/03/1950',
    'Date naiss. 12/03/1950',
    'D.D.N. : 12/03/1950',
    'D.D.N 12/03/1950',
    'né le mardi 12 mars 1950',
    'née le Jeudi 1er avril 1950',
    'née le 12 mars 50',
    'né le 12 mars 50.',
    'DOB: 12 March 1950',
    'DOB 12 Mar 1950',
    'Date of birth: 1950-03-12',
    'Date of birth: 12 March 1950',
    'Birth date: 12/03/1950',
    'born on 12/03/1950',
  ];
  for (final texte in masques) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, contains('[DATE_NAISSANCE_1]'),
          reason: r.maskedText);
      expect(r.maskedText, isNot(contains(RegExp(r'1950|\b50\b'))),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'né à Lyon (69) mais installé à Paris le 12/03/1950',
    'La naiss. du projet le 12/03/1950',
    'Rendez-vous le mardi 12 mars 1950',
    'le 12 mars 50',
    'on 12 March 1950 the board met',
    'born in Lyon',
    'né le mardi',
  ];
  for (final texte in intacts) {
    test('aucune date de naissance : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, isNot(contains('[DATE_NAISSANCE_1]')),
          reason: r.maskedText);
    });
  }
}
