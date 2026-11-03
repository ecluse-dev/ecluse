import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Coût de la résolution des pseudonymes avec beaucoup de noms distincts (P2-64).
/// Chaque mention de nom était comparée à toutes les identités déjà établies :
/// 10 000 noms distincts (110 Ko) prenaient 40 s. Un index des identités par
/// segment ne compare plus que les identités qui partagent un segment avec la
/// mention.
String _nomUnique(int i) => String.fromCharCodes([
      65 + i % 26,
      97 + (i ~/ 26) % 26,
      97 + (i ~/ 676) % 26,
      97 + (i ~/ 17576) % 26,
    ]);

void main() {
  // Coût mesuré par rapport de tailles (P2-100) : voir `support/cout.dart`.
  test('noms distincts : coût linéaire, un jeton par nom', () async {
    await expectCroissanceLineaire((n) async {
      final texte = [
        for (var i = 0; i < n; i++) 'Mme Q${_nomUnique(i)}.',
      ].join(' ');
      final r = await Ecluse.redact(texte);
      expect(r.mapping.length, n);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    }, n: 2500);
  });

  test('même personne répétée : coût linéaire, un seul jeton', () async {
    await expectCroissanceLineaire((n) async {
      final r = await Ecluse.redact('Mme Quenelle. ' * n);
      expect(r.mapping.length, 1);
    }, n: 5000);
  });

  test('un prénom très répandu ne ralentit pas : « Marie X »', () async {
    await expectCroissanceLineaire((n) async {
      final texte = [
        for (var i = 0; i < n; i++) 'Marie D${_nomUnique(i)}.',
      ].join(' ');
      final r = await Ecluse.redact(texte);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    }, n: 1250);
  });
}
