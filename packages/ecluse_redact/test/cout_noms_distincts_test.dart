import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Coût de la résolution des pseudonymes sur des milliers d'identités
/// distinctes (P2-64). Chaque mention était comparée à toutes les identités
/// déjà établies, et chaque nouveau jeton était cherché dans tout le texte :
/// 10 000 noms distincts (≈ 330 Ko) prenaient plus de 40 s. Les identités sont
/// maintenant indexées par segment et la recherche de jetons littéraux ne porte
/// que sur les segments `[...]`. Mesure de référence : 20 000 noms en ≈ 3 s,
/// contre ≈ 26 s avant ; la borne est large pour rester stable en CI.
void main() {
  const syllabes = [
    'Bel', 'Mor', 'Tan', 'Vor', 'Lis', 'Dur', //
    'Pen', 'Kar', 'Sol', 'Ruf', 'Gal', 'Nem'
  ];
  String mot(int i) {
    final b = StringBuffer(syllabes[i % syllabes.length]);
    for (var n = i ~/ syllabes.length; n > 0; n ~/= syllabes.length) {
      b.write(syllabes[n % syllabes.length].toLowerCase());
    }
    return b.toString();
  }

  test('10000 noms distincts en moins de 15 s', () async {
    final b = StringBuffer();
    for (var i = 0; i < 10000; i++) {
      b.write('Mme ${mot(i)} ${mot(i * 7 + 3)}ar\n');
    }
    final sw = Stopwatch()..start();
    final r = await Ecluse.redact(b.toString());
    expect(r.mapping.length, 10000);
    expect(sw.elapsed, lessThan(const Duration(seconds: 15)));
  });
}
