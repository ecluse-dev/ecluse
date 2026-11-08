import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Initiale + patronyme après un libellé de personne (P2-147) : « Présent :
/// T. Lefèvre ». Mesure P2-89 : 402 caractères de noms en clair sur
/// l'adversarial, le premier angle mort des heuristiques.
void main() {
  Future<String> masque(String t) async => (await Ecluse.redact(t)).maskedText;

  test('présent, excusé, rédacteur : masqués', () async {
    for (final t in [
      'Présent : T. Lefèvre\nExcusé : Monsieur Jean Dupont',
      'Rédacteur : É. Mérieux',
      'Présents : S. Verdier, K. Perrot et A. Chevrier',
      'Signé : G. Gauthier',
    ]) {
      final m = await masque(t);
      expect(m, isNot(matches(RegExp(r'[A-ZÉ]\. [A-ZÉ][a-zé]'))), reason: m);
    }
  });

  test('restauration exacte', () async {
    const t = 'Présents : S. Verdier, K. Perrot\nOrdre du jour : budget.';
    final r = await Ecluse.redact(t);
    expect(Ecluse.restore(r.maskedText, r.mapping), t);
  });

  test('autre libellé ou mot commun : en clair', () async {
    for (final t in [
      'Annexe : A. Introduction générale',
      'Plan : B. Méthode',
      'Article : L. 1110-4 du code',
      'Présent : A. Le reste suit.',
    ]) {
      expect(await masque(t), t, reason: t);
    }
  });
}
