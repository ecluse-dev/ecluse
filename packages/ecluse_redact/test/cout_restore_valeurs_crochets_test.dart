import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_redact/src/tokenizer.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// `restore` retombait sur l'ancien algorithme (un remplacement par jeton)
/// dès qu'une valeur contenait un crochet, donc pour le courriel obfusqué
/// `jean[at]example.fr` (P2-85) : 10 000 jetons, 9 s.
void main() {
  // Coût mesuré par rapport de tailles (P2-100) : voir `support/cout.dart`.
  String telephones(int n) => [
        for (var i = 0; i < n; i++)
          'Tél 06 ${10 + i % 90} ${10 + i ~/ 90 % 90} ${10 + i ~/ 8100} ${i % 100 + 10}',
        'jean[at]example.fr',
      ].join('\n');

  test('jetons avec une valeur « [at] » : restauration de coût linéaire',
      () async {
    final masques = {
      for (final n in [2500, 10000]) n: await Ecluse.redact(telephones(n)),
    };
    expect(masques[10000]!.mapping.length, greaterThan(5000));
    await expectCroissanceLineaire((n) {
      Ecluse.restore(masques[n]!.maskedText, masques[n]!.mapping);
    }, n: 2500);
    final r = masques[10000]!;
    expect(Ecluse.restore(r.maskedText, r.mapping), telephones(10000));
  });

  test('valeurs piégées : même résultat que l\'ancien algorithme', () {
    String ancien(String t, Map<String, String> m) {
      var r = t;
      for (final e in m.entries) {
        r = r.replaceAll(tolerantTokenPattern(e.key), e.value);
      }
      return r;
    }

    final cas = <Map<String, String>>[
      {'[NOM_1]': 'a[at]b.fr', '[NOM_2]': 'Zed'},
      {'[NOM_1]': '[at]', '[NOM_2]': 'x'},
      {'[NOM_1]': '[NOM_2]', '[NOM_2]': 'Zed'},
      {'[NOM_1]': '[ nom_2 ]', '[NOM_2]': 'Zed'},
      {'[NOM_1]': '[NOM_', '[NOM_2]': 'Zed'},
      {'[NOM_1]': 'x]', '[NOM_2]': 'Zed'},
      {'[NOM_1]': r'a\', '[NOM_2]': 'Zed'},
      {'[NOM_1]': '[x][NOM_2]', '[NOM_2]': 'Zed'},
    ];
    const textes = [
      '[NOM_1] et [NOM_2]',
      '[[NOM_1]NOM_2]',
      '[NOM_[NOM_1]2]',
      r'\[NOM_1] \[NOM_2\]',
      '[NOM_1][NOM_2]',
    ];
    for (final m in cas) {
      for (final t in textes) {
        expect(Ecluse.restore(t, m), ancien(t, m), reason: '$m sur $t');
      }
    }
  });
}
