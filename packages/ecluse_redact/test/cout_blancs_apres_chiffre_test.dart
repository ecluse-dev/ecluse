import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Un chiffre suivi d'une longue suite de blancs rendait le détecteur
/// d'adresse quadratique (P2-85) : deux `[ \t]*` séparés par une virgule
/// facultative se répartissaient les blancs de toutes les façons possibles.
void main() {
  // Coût mesuré par rapport de tailles (P2-100) : voir `support/cout.dart`.
  Future<void> allerRetour(String texte) async {
    final r = await Ecluse.redact(texte);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  }

  for (final blanc in [' ', '\t']) {
    test(
        'chiffre + blancs (${blanc == ' ' ? 'espaces' : 'tabulations'}) : '
        'coût linéaire', () async {
      await expectCroissanceLineaire((n) async {
        await allerRetour('1${blanc * n}');
      }, n: 5000);
    });
  }

  test('chiffre + « clé » + blancs : coût linéaire', () async {
    await expectCroissanceLineaire((n) async {
      await allerRetour('1 clé${' ' * n}');
    }, n: 5000);
  });

  test('suite de minuscules suivie d\'un point : coût linéaire', () async {
    await expectCroissanceLineaire((n) async {
      await allerRetour('${'a' * n}.');
    }, n: 25000);
  });

  test('les points entre mots capitalisés restent des séparateurs', () async {
    for (final t in [
      'Bilan.Pierre.Dupont.pdf',
      'Pierre.Dupont.pdf',
      'envoyé à Jean.Zxqvlorn demain',
    ]) {
      final r = await Ecluse.redact(t);
      expect(r.maskedText, isNot(contains('Dupont')), reason: t);
      expect(r.maskedText, isNot(contains('Zxqvlorn')), reason: t);
    }
  });

  test('les adresses avec virgule et espaces multiples restent masquées',
      () async {
    for (final t in [
      '12, rue des Lilas, 75015 Paris',
      '12 ,  rue des Lilas, 75015 Paris',
      '12   rue des Lilas, 75015 Paris',
      '12 bis rue des Lilas 75015 Paris',
    ]) {
      final r = await Ecluse.redact(t);
      expect(r.maskedText, isNot(contains('Lilas')), reason: t);
    }
  });
}
