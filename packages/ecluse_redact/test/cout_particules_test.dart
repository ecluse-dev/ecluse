import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Coût d'une chaîne de particules et de balises ouvertes (P2-79), trouvé par un
/// relecteur indépendant. `_unite` répétait les particules sans borne : « Van Der »
/// × 80 (640 octets) prenait 15 s dans la règle « nom devant <adresse> a écrit »
/// (P2-53), 10 Ko plus de 50 s ; « de la » × 4 000 : 11 s ; une formule de clôture
/// suivie d'une chaîne de particules (P2-54) : cubique. `<prenom ` sans `>` était
/// quadratique. Une chaîne de plus de trois particules n'est pas un nom.
void main() {
  // Coût mesuré par rapport de tailles (P2-100) : voir `support/cout.dart`.
  Future<void> lineaire(String Function(int n) texte, {required int n}) async {
    await expectCroissanceLineaire((k) async {
      final t = texte(k);
      final r = await Ecluse.redact(t);
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    }, n: n);
  }

  test('« Van Der » répété : coût linéaire', () async {
    await lineaire((n) => 'Van Der ' * n, n: 100);
  });
  test('« de la » répété : coût linéaire', () async {
    await lineaire((n) => 'de la ' * n, n: 1000);
  });
  test('formule de clôture puis chaîne de particules', () async {
    await lineaire((n) => 'Cordialement\n${'Van Der ' * n}x', n: 50);
  });
  test('balises « <firstname » sans fermeture', () async {
    await lineaire((n) => '<firstname ' * n, n: 3000);
  });
  test('balises « <prenom » + texte sans fermeture', () async {
    await lineaire((n) => '<prenom ${'x' * 50}' * n, n: 1000);
  });

  test('un nom à particules reste masqué', () async {
    for (final nom in [
      'Mme de la Fontaine',
      'M. Van Der Berg',
      'Mme Le Gall'
    ]) {
      final r = await Ecluse.redact('$nom est venue.');
      expect(r.maskedText, contains('[NOM_'), reason: r.maskedText);
    }
    final r = await Ecluse.redact(
        'Le 12 mars, Jean de la Fontaine <j@exemple.fr> a écrit :');
    expect(r.maskedText, isNot(contains('Fontaine')), reason: r.maskedText);
  });
}
