import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Numéro de voie suivi d'une lettre (P2-37) : « 12 B rue des Lilas ». Seuls
/// « bis », « ter »… étaient admis ; le numéro et la lettre restaient en clair
/// devant l'adresse masquée.
void main() {
  const masques = [
    'Adresse : 12 B rue des Lilas, 75011 Paris',
    'Adresse : 12B rue des Lilas, 75011 Paris',
    'Adresse : 3 A avenue du Général Leclerc, 69003 Lyon',
    'Adresse : 7 C, impasse des Fleurs 33000 Bordeaux',
  ];
  for (final texte in masques) {
    test('adresse en entier : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, 'Adresse : [ADRESSE_1]', reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'Le groupe B rue vite.',
    'Annexe 12 B : voir page 3.',
    'Lot 4 C du marché.',
  ];
  for (final texte in intacts) {
    test('aucune adresse : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }
}
