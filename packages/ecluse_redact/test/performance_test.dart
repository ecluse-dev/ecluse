import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Les motifs ne doivent pas être quadratiques sur une entrée pathologique :
/// l'API de démo est monothread, un seul gros corps gelait le serveur.
void main() {
  Duration mesure(void Function() f) {
    final sw = Stopwatch()..start();
    f();
    return sw.elapsed;
  }

  const budget = Duration(milliseconds: 800);

  test('email : longue suite alphanumérique sans arobase', () {
    final texte = 'a' * 16000;
    expect(mesure(() => const EmailDetector().detect(texte)), lessThan(budget));
  });

  test('email : longue suite avec points', () {
    final texte = 'a.' * 8000;
    expect(mesure(() => const EmailDetector().detect(texte)), lessThan(budget));
  });

  test('email : adresse valide toujours détectée après le correctif', () {
    final texte = 'Écrire à ${'x' * 30}@example.fr svp';
    expect(const EmailDetector().detect(texte), hasLength(1));
  });

  test('adresse : « N rue » répété sans code postal', () {
    final texte = '1 rue a ' * 2000;
    expect(
        mesure(() => const AdresseDetector().detect(texte)), lessThan(budget));
  });

  test('adresse : « N rue » répété (variante courte)', () {
    final texte = '1 rue ' * 4000;
    expect(
        mesure(() => const AdresseDetector().detect(texte)), lessThan(budget));
  });

  test('adresse : adresse valide toujours détectée', () {
    const t = '12 rue des Lilas, 75015 Paris';
    expect(const AdresseDetector().detect(t), hasLength(1));
  });
}
