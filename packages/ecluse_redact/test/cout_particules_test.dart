import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Coût d'une chaîne de particules et de balises ouvertes (P2-79), trouvé par un
/// relecteur indépendant. `_unite` répétait les particules sans borne : « Van Der »
/// × 80 (640 octets) prenait 15 s dans la règle « nom devant <adresse> a écrit »
/// (P2-53), 10 Ko plus de 50 s ; « de la » × 4 000 : 11 s ; une formule de clôture
/// suivie d'une chaîne de particules (P2-54) : cubique. `<prenom ` sans `>` était
/// quadratique. Une chaîne de plus de trois particules n'est pas un nom.
void main() {
  Future<void> court(String texte, {int secondes = 4}) async {
    final sw = Stopwatch()..start();
    final r = await Ecluse.redact(texte);
    expect(sw.elapsed, lessThan(Duration(seconds: secondes)),
        reason: '${texte.length} caractères');
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  }

  test('« Van Der » × 80 (640 octets)', () => court('Van Der ' * 80));
  test('« Van Der » × 400 (3 Ko)', () => court('Van Der ' * 400));
  test('« de la » × 4 000 (24 Ko)', () => court('de la ' * 4000));
  test('formule de clôture puis chaîne de particules',
      () => court('Cordialement\n${'Van Der ' * 200}x'));
  test('balises « <firstname » sans fermeture × 12 000',
      () => court('<firstname ' * 12000));
  test('balises « <prenom » + texte sans fermeture',
      () => court('<prenom ${'x' * 50}' * 4000));

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
