import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-186 : dans une ligne de planning relue sans séparateurs (nom en
/// capitales + prénom + fonction courte en capitales), la fonction était
/// parfois avalée dans l'étendue du nom (« LEFÈVRE Olivier AS » au lieu de
/// « LEFÈVRE Olivier »). Deux mentions d'une même personne recevaient alors
/// des valeurs différentes, fusionnées par inclusion de segments en un seul
/// jeton — dont la restauration réinjectait la forme la plus longue sur
/// *toutes* les mentions, y compris celle qui n'avait jamais perdu sa
/// fonction : rupture de l'invariant de réversibilité (restauration non
/// byte-exacte), plus grave qu'un défaut de score.
void main() {
  Future<(RedactResult, String)> aller(String texte) async {
    final r = await Ecluse.redact(texte);
    return (r, Ecluse.restore(r.maskedText, r.mapping));
  }

  test('reproduction exacte : LEFÈVRE Olivier AS/ASH, deux lignes', () async {
    const texte = 'LEFÈVRE Olivier ASH 03 53 01 83 08 | RTT\n'
        'LEFÈVRE Olivier AS 02 61 91 76 57 | M\n';
    final (r, restaure) = await aller(texte);
    expect(restaure, texte, reason: 'restauration non byte-exacte');
    // La fonction ne doit plus jamais faire partie de la valeur masquée.
    for (final valeur in r.mapping.entrees.map((e) => e.$2)) {
      expect(valeur, isNot(contains('ASH')));
      expect(valeur, isNot(contains(RegExp(r'\bAS\b'))));
    }
  });

  group('témoin : lignes de planning sans séparateurs', () {
    // Nom en capitales + prénom + fonction courte en capitales, avec des
    // homonymes (même nom + prénom sur plusieurs lignes, fonction
    // différente), restauration comparée octet pour octet.
    const lignes = [
      'LEFÈVRE Olivier ASH 03 53 01 83 08 | RTT',
      'LEFÈVRE Olivier AS 02 61 91 76 57 | M',
      'DURAND Marie IDE 04 12 34 56 78 | J',
      'DURAND Marie ASD 01 98 76 54 32 | S',
      'MARTIN Julien AMP 06 11 22 33 44 | N',
      'MARTIN Julien AS 07 55 66 77 88 | RTT',
    ];

    for (final ligne in lignes) {
      test('aller-retour exact : $ligne', () async {
        final (_, restaure) = await aller('$ligne\n');
        expect(restaure, '$ligne\n');
      });
    }

    test('document complet, aller-retour exact', () async {
      final texte = '${lignes.join('\n')}\n';
      final (r, restaure) = await aller(texte);
      expect(restaure, texte);
      // Deux patronymes distincts par couple nom+prénom (Lefèvre/Olivier,
      // Durand/Marie, Martin/Julien), jamais un jeton qui engloberait la
      // fonction.
      expect(r.mapping.length, greaterThanOrEqualTo(3));
    });
  });
}
