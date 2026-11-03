import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Coût de la détection de noms sur un texte à milliers de mentions (P2-48).
/// Le mot capitalisé précédant un prénom candidat était cherché dans une copie
/// de tout le texte qui le précède : coût proportionnel à la position, donc
/// quadratique (4 000 mentions : 11 s). La recherche est maintenant bornée à une
/// fenêtre. Coût mesuré par rapport de tailles (P2-100) : voir
/// `support/cout.dart`.
void main() {
  for (final motif in [
    'Mme Dupont ben Ali ter ten ',
    'Zorglub Martin et Paul '
  ]) {
    test('mentions « $motif » répétées : coût linéaire', () async {
      await expectCroissanceLineaire((n) async {
        final r = await Ecluse.redact(motif * n);
        expect(r.mapping, isNotEmpty);
      }, n: 1000);
    });
  }

  // P2-50 : un « Nom : » sans « Prénom » proche cherchait la fin de ligne dans
  // tout le reste du texte ; sans saut de ligne, chaque occurrence le parcourait
  // en entier. Mesures de référence (poste de développement) : 160 000 « Nom : »
  // (960 Ko) prenaient 43,6 s avant la correction et 1,8 s après. Le test
  // compare deux tailles plutôt qu'une borne en secondes (P2-100).
  for (final entree in {
    'Nom : ': 40000,
    'Nom : Aspirine ': 16000,
  }.entries) {
    test('« ${entree.key}» sans saut de ligne : coût linéaire', () async {
      await expectCroissanceLineaire((n) async {
        await Ecluse.redact(entree.key * n);
      }, n: entree.value, raison: entree.key);
    });
  }
}
