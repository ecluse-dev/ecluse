import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Adresse sans code postal (P2-56) : « 12 rue des Lilas » restait en clair, la
/// détection exigeait un code postal. Numéro + type de voie en toutes lettres
/// (ou `av`, `bd`, `rte`, `fbg`) + nom de voie en majuscule initiale : la
/// structure suffit, comme pour la forme avec code postal.
void main() {
  const masques = {
    'Elle habite 12 rue des Lilas.': 'Lilas',
    'Domicile : 12 bis, rue des Lilas': 'Lilas',
    'Elle vit à Bordeaux, 12 cours Victor Hugo.': 'Victor',
    'Il demeure 8, Av. Jean Jaurès à Lyon': 'Jaurès',
    'Adresse : 3 impasse du Moulin': 'Moulin',
    'Adresse : 1 place de la République': 'République',
    'Adresse : 27 boulevard Haussmann': 'Haussmann',
    'Adresse : 45 Rue du Faubourg Saint-Honoré': 'Honoré',
    'habite au 5 chemin de la Source, chez sa fille': 'Source',
    'Adresse : 14 allée des Roses': 'Roses',
    'Adresse : 2 rue de l\'Église': 'Église',
    'Adresse : 10 rue du 8 Mai 1945': 'Mai',
    'Adresse : 6 route de Lyon': 'Lyon',
    'Adresse : 9 Bd Voltaire': 'Voltaire',
    'Adresse : 12 RUE DES LILAS': 'LILAS',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(
          r.maskedText,
          isNot(matches(RegExp(
              r'\d+\s*(bis,?\s*)?(rue|cours|Av|impasse|place|boulevard|chemin|allée|Bd|route)\b',
              caseSensitive: false))),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Il a pris 3 places libres': 'places',
    'Il reste 2 cours à suivre': 'cours',
    'Rendez-vous le 12 rue': 'rue',
    'Il a 3 route': 'route',
    'Annexe 12 B : voir page 3': 'Annexe',
    '3 chemin de fer': 'chemin',
    '12 place disponible': 'place',
    'Chapitre 3 Cours de biologie': 'Cours',
    'Article 12 Rue': 'Rue',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
