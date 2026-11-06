import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Coût linéaire du repérage des pathologies (P2-128). Avant la fenêtre
/// bornée, chaque mention relisait tout le texte qui la précède : 2,7 s pour
/// 2 000 mentions, 46 s pour 8 000.
void main() {
  test('beaucoup de mentions : coût linéaire', () async {
    await expectCroissanceLineaire(
      (n) => extrairePathologies(
          List.filled(n, 'Antécédents : diabète, BPCO, cirrhose, lupus ')
              .join()),
      n: 500,
    );
  });

  test('longue phrase sans point : coût linéaire', () async {
    await expectCroissanceLineaire(
      (n) => extrairePathologies(
          'atteinte de ${List.filled(n, 'mot ').join()}diabète'),
      n: 20000,
    );
  });
}
