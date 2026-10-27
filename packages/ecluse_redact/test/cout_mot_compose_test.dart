import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Coût sur un mot composé très long (P2-58). Un mot en majuscule initiale
/// fait de segments reliés par des tirets (« Aa-Aa-Aa-… », « AB-123-AB-123-… »)
/// était traité en temps cubique par la règle « nom devant <adresse> a écrit »
/// (P2-53) : le motif repartait de chaque segment du mot. 12 000 segments
/// (36 Ko) prenaient plus de 15 s ; le motif exige maintenant un début de mot.
void main() {
  final entrees = {
    'Aa- × 12 000': 'Aa-' * 12000,
    'AB-123- × 6 000': 'AB-123-' * 6000,
    "A'a × 12 000": "A'a" * 12000,
  };
  for (final MapEntry(key: nom, value: texte) in entrees.entries) {
    test('mot composé : $nom en moins de 5 s', () async {
      final sw = Stopwatch()..start();
      final r = await Ecluse.redact(texte);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('« a écrit » après un nom composé reste détecté', () async {
    const texte = 'Jean-Zorglub Quenelle <z@exemple.fr> a écrit :';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, isNot(contains('Quenelle')), reason: r.maskedText);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });
}
