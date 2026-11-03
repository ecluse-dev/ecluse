import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Diversité des prénoms du gazetteer (P2-68). La liste ne couvrait que
/// 61 de 143 prénoms courants d'origines variées (Maghreb, Afrique de l'Ouest,
/// Europe du Sud et de l'Est, Asie, prénoms anciens et récents) : « Il a vu
/// Rachid Zxqvlorn » laissait le prénom en clair, faute de contexte. Un prénom
/// ajouté ne se déclenche jamais seul sur un mot courant : la liste exclut les
/// prénoms qui sont aussi des mots (voir les mots écartés).
const _ajoutes = [
  // Maghreb et Moyen-Orient
  'Mohammed', 'Rachid', 'Nabil', 'Farid', 'Kamel', 'Mustapha', 'Brahim',
  'Hakim', 'Aicha', 'Khadija', 'Salima', 'Naima',
  // Afrique de l'Ouest et centrale
  'Moussa', 'Ousmane', 'Ibrahima', 'Abdoulaye', 'Cheikh', 'Seydou', 'Fatou',
  'Aminata', 'Awa', 'Mariama', 'Kadidja', 'Oumou', 'Binta',
  // Europe du Sud et de l'Est
  'Giuseppe', 'Antonio', 'Luigi', 'Francesco', 'Marco', 'Carlos', 'Jose',
  'Miguel', 'Pedro', 'Joao', 'Paulo', 'Piotr', 'Andrzej', 'Krzysztof',
  'Dmitri', 'Vladimir', 'Sergei', 'Nikolai', 'Olga', 'Natalia', 'Svetlana',
  'Ioana',
  // Asie
  'Linh', 'Hoa', 'Mei', 'Wei', 'Hiroshi', 'Kenji', 'Sakura', 'Ayumi',
  'Priya', 'Raj', 'Anil', 'Sunita', 'Ravi',
  // Prénoms anciens et récents
  'Mauricette', 'Ginette', 'Huguette', 'Lucette', 'Dylan', 'Oceane',
  'Maelys', 'Nolan',
];

/// Prénoms écartés parce que le mot a un autre sens courant : l'ajouter
/// masquerait un mot ordinaire (mois abrégé, verbe anglais, adjectif…).
const _ecartes = ['Jan', 'Jun', 'Lou', 'Said', 'Manuel', 'Li', 'Thi', 'Mario'];

void main() {
  for (final p in _ajoutes) {
    test('masqué : $p', () async {
      final r = await Ecluse.redact('Il a vu $p Zxqvlorn hier.');
      expect(r.maskedText, contains('[NOM_'), reason: r.maskedText);
      expect(r.maskedText, isNot(contains(p)), reason: r.maskedText);
    });
  }

  test('forme accentuée : « Océane », « Maëlys »', () async {
    for (final p in ['Océane', 'Maëlys']) {
      final r = await Ecluse.redact('Il a vu $p Zxqvlorn hier.');
      expect(r.maskedText, isNot(contains(p)), reason: r.maskedText);
    }
  });

  for (final mot in _ecartes) {
    test('mot ordinaire non masqué seul : $mot', () async {
      final r = await Ecluse.redact('Le rapport du mois : $mot.');
      expect(r.maskedText, contains(mot), reason: r.maskedText);
    });
  }

  test('phrases ordinaires intactes', () async {
    const phrases = [
      'Le dossier sera revu en Jan et en Jun prochains.',
      'Manuel d\'utilisation du fauteuil roulant.',
      'Said-il, il a dit que tout allait bien.',
      'Le Mario Kart de la salle commune.',
    ];
    for (final p in phrases) {
      final r = await Ecluse.redact(p);
      expect(r.maskedText, p, reason: r.maskedText);
    }
  });
}
