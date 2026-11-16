import 'package:ecluse_core/ecluse_core.dart' show EntityType;
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// ADELI à clé fausse derrière son libellé (P2-204). `AdeliDetector` le masque
/// à confiance 0,6 (`LIMITES.md` § 2, inchangée) mais l'avertissement
/// « à vérifier » n'était donné que pour la confiance 0,3 (NIR, IBAN, RPPS à
/// clé fausse, ADELI lus par OCR). Rien ne fuyait : l'utilisateur n'était pas
/// prévenu. Identifiants fabriqués : 123456789 n'a pas une clé Luhn juste,
/// 123456782 l'a.
void main() {
  bool averti(RedactResult r) =>
      r.warnings.any((w) => w.contains('identifiant à clé invalide'));

  const clesFausses = [
    'ADELI : 123456789.',
    'N° ADELI 123456789 du praticien.',
    'ADELI 123 456 789',
  ];
  for (final texte in clesFausses) {
    test('clé fausse : masqué et averti : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.entities.any((e) => e.type == EntityType.adeli), isTrue);
      expect(r.maskedText, isNot(contains('456')));
      expect(averti(r), isTrue, reason: 'avertissement absent');
      for (final w in r.warnings) {
        expect(w, isNot(contains('123456789')));
        expect(w, isNot(contains('456')));
      }
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('deux ADELI à clé fausse : une seule mention, avec le compte', () async {
    final r = await Ecluse.redact('ADELI 123456789 puis ADELI 987654320.');
    expect(r.entities.where((e) => e.type == EntityType.adeli), hasLength(2));
    expect(r.warnings.where((w) => w.contains('à clé invalide')), hasLength(1));
  });

  const sansAvertissement = [
    'ADELI : 123456782.', // clé Luhn juste (confiance 0,95)
    'ADELI : 2A1234567.', // numéro corse : aucune règle de clé établie
  ];
  for (final texte in sansAvertissement) {
    test('pas d\'avertissement : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.entities.any((e) => e.type == EntityType.adeli), isTrue);
      expect(averti(r), isFalse);
    });
  }
}
