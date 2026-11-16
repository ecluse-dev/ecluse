import 'dart:math';

import 'package:ecluse_core/ecluse_core.dart' show isLuhnValid;
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Une seule implémentation de la clé Luhn dans le dépôt (P2-209).
///
/// `ecluse_core` l'exporte ; `ecluse_redact` n'en garde plus de copie locale
/// (`ecluse.dart`, avertissement ADELI de P2-204, et le détecteur de clé
/// invalide). Ces tests figent le comportement des deux appelants avant et
/// après le refactor : mêmes verdicts qu'une référence écrite ici, à la main,
/// sur des chiffres fabriqués (graine fixe).
void main() {
  bool reference(String s) {
    final chiffres = s.split('').map(int.parse).toList().reversed.toList();
    var somme = 0;
    for (var i = 0; i < chiffres.length; i++) {
      var d = chiffres[i];
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      somme += d;
    }
    return somme % 10 == 0;
  }

  String fabrique(Random rng, int n) =>
      List.generate(n, (_) => rng.nextInt(10)).join();

  test('isLuhnValid est exportée par ecluse_core et suit la référence', () {
    final rng = Random(42);
    for (final n in [9, 11]) {
      var bons = 0;
      for (var i = 0; i < 2000; i++) {
        final s = fabrique(rng, n);
        expect(isLuhnValid(s), reference(s), reason: 'longueur $n');
        if (reference(s)) bons++;
      }
      expect(bons, greaterThan(100), reason: 'des clés justes sont tirées');
    }
  });

  test('avertissement ADELI : clé fausse signalée, clé juste non', () async {
    final rng = Random(42);
    var faux = 0, juste = 0;
    for (var i = 0; i < 200; i++) {
      final s = fabrique(rng, 9);
      final r = await Ecluse.redact('Identifiant ADELI : $s.');
      final avertit = r.warnings.any((w) => w.contains('à vérifier'));
      if (reference(s)) {
        juste++;
        expect(avertit, isFalse, reason: 'clé juste');
      } else {
        faux++;
        expect(avertit, isTrue, reason: 'clé fausse');
      }
    }
    expect(faux, greaterThan(50));
    expect(juste, greaterThan(5));
  });
}
