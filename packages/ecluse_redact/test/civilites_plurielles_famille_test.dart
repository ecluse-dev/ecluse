import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Civilités au pluriel, en minuscules ou en majuscules, et mots de parenté
/// (P2-69). Sonde de 26 formules de politesse : « Mmes Quenelle et Dupont »,
/// « MM. Quenelle et Dupont », « La famille Quenelle », « Les époux Quenelle »,
/// « le docteur Quenelle », « Sœur Marie-Pierre Quenelle », « Père Quenelle »,
/// « Mdme », « Melle », « MME QUENELLE Zorglub » laissaient le nom en clair.
void main() {
  const masques = {
    'Mmes Quenelle et Dupont ont été reçues.': ['Quenelle', 'Dupont'],
    'MM. Quenelle et Dupont sont venus.': ['Quenelle', 'Dupont'],
    'Mesdames Quenelle, Dupont et Martin': ['Quenelle', 'Dupont', 'Martin'],
    'Messieurs Quenelle ou Dupont': ['Quenelle', 'Dupont'],
    'Mlles Quenelle et Dupont': ['Quenelle', 'Dupont'],
    'La famille Quenelle': ['Quenelle'],
    'Famille Quenelle présente': ['Quenelle'],
    'Les époux Quenelle': ['Quenelle'],
    'Les consorts Quenelle': ['Quenelle'],
    'le docteur Quenelle': ['Quenelle'],
    'la doctoresse Quenelle': ['Quenelle'],
    'le professeur Quenelle': ['Quenelle'],
    'bonjour madame Quenelle': ['Quenelle'],
    'merci monsieur Quenelle': ['Quenelle'],
    'Sœur Marie-Pierre Quenelle': ['Quenelle'],
    'Soeur Quenelle': ['Quenelle'],
    'Père Quenelle': ['Quenelle'],
    'Frère Quenelle': ['Quenelle'],
    'Mdme Quenelle': ['Quenelle'],
    'Melle Quenelle': ['Quenelle'],
    'MME QUENELLE Zorglub': ['QUENELLE', 'Zorglub'],
    'MONSIEUR QUENELLE': ['QUENELLE'],
    'MLLE QUENELLE': ['QUENELLE'],
  };
  for (final MapEntry(key: texte, value: restes) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      for (final v in restes) {
        expect(r.maskedText, isNot(contains(v)), reason: r.maskedText);
      }
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('« Mmes X et Y » : une personne par nom, jamais un seul jeton',
      () async {
    final r = await Ecluse.redact('Mmes Quenelle et Dupont ont été reçues.');
    expect(r.mapping.length, 2, reason: r.maskedText);
    expect(r.maskedText, contains(' et '));
  });

  const intacts = {
    'La famille est présente': 'famille',
    'Famille d\'accueil': 'accueil',
    'la famille de la résidence': 'résidence',
    'les époux sont venus': 'époux',
    'le docteur est passé': 'docteur',
    'le professeur de sport': 'professeur',
    'madame est partie': 'madame',
    'bonjour monsieur': 'monsieur',
    'Mmes et MM. présents': 'Mmes',
    'Soeur et frère': 'Soeur',
    '10 MM. de mercure': 'MM.',
    'Père et mère': 'Père',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('[NOM_')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('un établissement derrière « famille » reste un établissement',
      () async {
    final r = await Ecluse.redact('Famille Résidence Les Lilas');
    expect(r.maskedText, isNot(contains('[NOM_')), reason: r.maskedText);
  });
}
