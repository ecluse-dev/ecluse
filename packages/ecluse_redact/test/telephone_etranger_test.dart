import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Téléphones étrangers (P2-60) : Belgique, Suisse, Luxembourg, Allemagne,
/// Espagne, Italie, Royaume-Uni, Maroc, Algérie, Tunisie. Un correspondant
/// à l'étranger restait en clair. L'indicatif (+cc ou 00cc) est obligatoire et
/// le nombre de chiffres doit être celui du pays : « +32 12 » ou un numéro trop
/// long ne sont pas masqués. Les États-Unis et les autres pays ne sont pas
/// couverts (arbitrage du 27 octobre : voisins et Maghreb).
void main() {
  const masques = [
    '+32 475 12 34 56',
    '+32475123456',
    '+32 2 123 45 67',
    '+32 (0)475 12 34 56',
    '0032 475 12 34 56',
    '+41 79 123 45 67',
    '+41 (0)79 123 45 67',
    '+352 621 123 456',
    '+352 26 12 34 56',
    '+49 151 12345678',
    '+49 30 1234567',
    '+49 (0)30 12345678',
    '+34 612 34 56 78',
    '+34 91 123 45 67',
    '+39 333 123 4567',
    '+39 06 1234 5678',
    '+44 7911 123456',
    '+44 (0)20 7946 0958',
    '+44 20 7946 0958',
    '+212 6 12 34 56 78',
    '+212 612-345678',
    '+212612345678',
    '+213 551 23 45 67',
    '+216 20 123 456',
    '(+32) 475 12 34 56',
  ];
  for (final numero in masques) {
    test('masqué : $numero', () async {
      final texte = 'Joindre au $numero demain.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, equals('Joindre au [TELEPHONE_1] demain.'),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    '+32 12',
    '+32 475 123456789',
    '+41 79 123 45',
    '+99 123 456 789',
    '+1 202 555 0143',
    '+34 12 34',
    '+216 20 123 4567',
    'ref +32/1234',
    '32 475 12 34 56',
    '+3247512345678901',
  ];
  for (final texte in intacts) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('[TELEPHONE_')),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
