import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Coût linéaire des détecteurs propres aux textes sans majuscule ou sans
/// minuscule (P2-119 à P2-124), mesuré par P2-128.
void main() {
  const minuscules = 'rdv avec m. julien chevrier au 7 impasse des '
      'charmilles, 70160 port sur saone, puis ehpad marie curie. ';
  for (final (nom, motif) in [
    ('minuscules', minuscules),
    (
      'capitales',
      'RDV AVEC M. JULIEN CHEVRIER AU 7 IMPASSE DES CHARMILLES, '
          '70160 PORT SUR SAONE, PUIS EHPAD MARIE CURIE. '
    ),
    ('faux amis', 'la plaie est rose pâle et 70000 euros hors taxes '),
    (
      'casse de phrase (P2-138)',
      'Rdv avec m. julien chevrier au ssiad de gray. Suivi par perrot '
          'olivier. '
    ),
    (
      'casse ordinaire longue sans nom propre (P2-138)',
      'Le patient va bien. La nuit a été calme. '
    ),
  ]) {
    test('texte $nom : coût linéaire', () async {
      await expectCroissanceLineaire(
        (n) => Ecluse.redact(List.filled(n, motif).join()),
        n: 300,
      );
    });
  }
}
