import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Coût de la détection de noms sur un texte à milliers de mentions (P2-48).
/// Le mot capitalisé précédant un prénom candidat était cherché dans une copie
/// de tout le texte qui le précède : coût proportionnel à la position, donc
/// quadratique (4 000 mentions : 11 s). La recherche est maintenant bornée à une
/// fenêtre ; la borne du test est large pour rester stable en CI.
void main() {
  for (final motif in [
    'Mme Dupont ben Ali ter ten ',
    'Zorglub Martin et Paul '
  ]) {
    test('4000 mentions « $motif » en moins de 4 s', () async {
      final sw = Stopwatch()..start();
      final r = await Ecluse.redact(motif * 4000);
      expect(r.mapping, isNotEmpty);
      expect(sw.elapsed, lessThan(const Duration(seconds: 4)));
    });
  }
}
