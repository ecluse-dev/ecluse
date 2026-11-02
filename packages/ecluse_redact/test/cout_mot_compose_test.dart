import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Coût sur un mot composé très long (P2-58). Un mot en majuscule initiale
/// fait de segments reliés par des tirets (« Aa-Aa-Aa-… », « AB-123-AB-123-… »)
/// était traité en temps cubique par la règle « nom devant <adresse> a écrit »
/// (P2-53) : le motif repartait de chaque segment du mot. 12 000 segments
/// (36 Ko) prenaient plus de 15 s ; le motif exige maintenant un début de mot.
void main() {
  // Coût mesuré par rapport de tailles (P2-100) : voir `support/cout.dart`.
  final motifs = {'Aa-': 3000, 'AB-123-': 1500, "A'a": 3000};
  for (final MapEntry(key: motif, value: n) in motifs.entries) {
    test('mot composé « $motif » répété : coût linéaire', () async {
      await expectCroissanceLineaire((k) async {
        final texte = motif * k;
        final r = await Ecluse.redact(texte);
        expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      }, n: n);
    });
  }

  test('« a écrit » après un nom composé reste détecté', () async {
    const texte = 'Jean-Zorglub Quenelle <z@exemple.fr> a écrit :';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, isNot(contains('Quenelle')), reason: r.maskedText);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });
}
