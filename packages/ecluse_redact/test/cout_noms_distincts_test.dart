import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Coût de la résolution des pseudonymes avec beaucoup d'identités distinctes
/// (P2-64). Le coût dépend du nombre d'identités, non du nombre de mentions :
/// `_freshToken` appliquait un motif à tout le texte pour chaque nouveau jeton.
/// La borne est large pour rester stable en CI mais détecte le retour du coût
/// quadratique (10 000 noms distincts : 43 s avant correction).
void main() {
  String noms(int n) => [
        for (var i = 0; i < n; i++) 'Mme ${_mot(i)} ${_mot(i + 7919)}.'
      ].join('\n');

  test('10000 noms distincts en moins de 15 s', () async {
    final sw = Stopwatch()..start();
    final r = await Ecluse.redact(noms(10000));
    expect(r.mapping.length, greaterThan(5000));
    expect(sw.elapsed, lessThan(const Duration(seconds: 15)));
  });
}

String _mot(int i) {
  const l = 'bcdfglmnprstvz';
  const v = 'aeiou';
  final b = StringBuffer();
  var n = i + 1;
  for (var k = 0; k < 5; k++) {
    b.write(k.isEven ? l[n % l.length] : v[n % v.length]);
    n ~/= k.isEven ? l.length : v.length;
    if (n == 0) n = i * 31 + k + 1;
  }
  final s = b.toString();
  return s[0].toUpperCase() + s.substring(1) + String.fromCharCode(97 + i % 26);
}
