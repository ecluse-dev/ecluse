import 'dart:math';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_redact/src/tokenizer.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Ancien algorithme de `Ecluse.restore` (un `replaceAll` par jeton) : la
/// référence du test différentiel de P2-64. Le nouveau parcours en un seul
/// passage doit rendre exactement le même texte.
String _reference(String text, Map<String, String> mapping) {
  var result = text;
  for (final e in mapping.entries) {
    result = result.replaceAll(tolerantTokenPattern(e.key), e.value);
  }
  return result;
}

const _formes = [
  '[NOM_1]',
  '[nom_1]',
  '[ NOM_1 ]',
  '[NOM 1]',
  '[NOM1]',
  '\\[NOM\\_1\\]',
  '\\[ NOM_2 \\]',
  '[NOM_2]',
  '[NOM_10]',
  '[NOM_11]',
  '[TEL_1]',
  '[TEL_ 1]',
  '[NIR_1]',
  '[PIECE_IDENTITE_1]',
  '[PIECE IDENTITE 1]',
  '[NOM_3',
  'NOM_1]',
  '[[NOM_1]]',
  '\\[NOM_1]',
  '[NOM_1\\]',
  '[AUTRE_1]',
  'Mme Dupont',
  ' ',
  '\n',
  '[',
  ']',
  '\\',
  'texte libre',
];

void main() {
  final valeursSures = {
    '[NOM_1]': 'Alice',
    '[NOM_2]': 'Bob',
    '[NOM_10]': 'Dix',
    '[NOM_11]': 'Onze',
    '[TEL_1]': '0612345678',
    '[NIR_1]': '2550814168025',
    '[PIECE_IDENTITE_1]': 'X123',
  };

  test('restore ≡ ancien algorithme sur 2 000 textes tirés (graines fixes)',
      () {
    for (var seed = 0; seed < 2000; seed++) {
      final r = Random(seed);
      final texte = [
        for (var i = 0; i < 1 + r.nextInt(20); i++)
          _formes[r.nextInt(_formes.length)]
      ].join(r.nextBool() ? ' ' : '');
      expect(
          Ecluse.restore(texte, valeursSures), _reference(texte, valeursSures),
          reason: 'graine $seed : $texte');
    }
  });

  test('restore ≡ ancien algorithme quand une valeur contient un jeton', () {
    final pieges = {
      '[NOM_1]': 'voir [NOM_2]',
      '[NOM_2]': 'Bob',
      '[TEL_1]': 'a\\',
      '[NIR_1]': ']',
    };
    for (var seed = 0; seed < 500; seed++) {
      final r = Random(seed);
      final texte = [
        for (var i = 0; i < 1 + r.nextInt(12); i++)
          _formes[r.nextInt(_formes.length)]
      ].join(' ');
      expect(Ecluse.restore(texte, pieges), _reference(texte, pieges),
          reason: 'graine $seed : $texte');
    }
  });

  // Coût mesuré par rapport de tailles (P2-100) : voir `support/cout.dart`.
  // Seule la restauration est chronométrée : construire la table et le texte,
  // puis comparer le résultat, ajoutait du travail mémoire au chrono (rapport
  // de 8,8 mesuré en CI le 5 novembre 2026, sans régression). `restore`
  // compile un motif par jeton : le seuil est porté à 10, un coût quadratique
  // (rapport d'environ 16) reste détecté.
  test('jetons distincts : restauration de coût linéaire', () async {
    Map<String, String> table(int n) {
      return {for (var i = 1; i <= n; i++) '[NOM_$i]': 'Nom$i'};
    }

    String texte(int n) {
      return [for (var i = 1; i <= n; i++) '[NOM_$i]'].join(' ');
    }

    final entrees = {
      2500: (table(2500), texte(2500)),
      10000: (table(10000), texte(10000)),
    };
    final sorties = <int, String>{};
    await expectCroissanceLineaire((n) {
      final (t, x) = entrees[n]!;
      sorties[n] = Ecluse.restore(x, t);
    }, n: 2500, seuil: 10);
    final attendu = [for (var i = 1; i <= 10000; i++) 'Nom$i'].join(' ');
    expect(sorties[10000], attendu);
  });
}
