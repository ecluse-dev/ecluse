import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

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
  test('10 000 noms distincts en moins de 10 s', () async {
    final texte = [
      for (var i = 0; i < 10000; i++) 'Mme Q${_nomUnique(i)}.',
    ].join(' ');
    final sw = Stopwatch()..start();
    final r = await Ecluse.redact(texte);
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    expect(r.mapping.length, 10000);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('20 000 mentions d\'une même personne en moins de 10 s', () async {
    final texte = 'Mme Quenelle. ' * 20000;
    final sw = Stopwatch()..start();
    final r = await Ecluse.redact(texte);
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    expect(r.mapping.length, 1);
  });

  test('un prénom très répandu ne ralentit pas : 5 000 « Marie X »', () async {
    final texte = [
      for (var i = 0; i < 5000; i++) 'Marie D${_nomUnique(i)}.',
    ].join(' ');
    final sw = Stopwatch()..start();
    final r = await Ecluse.redact(texte);
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });
}
