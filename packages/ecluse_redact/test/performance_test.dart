import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Les motifs ne doivent pas être quadratiques sur une entrée pathologique :
/// l'API de démo est monothread, un seul gros corps gelait le serveur. Coût
/// mesuré par rapport de tailles (P2-100) : voir `support/cout.dart`.
void main() {
  test('email : longue suite alphanumérique sans arobase', () async {
    await expectCroissanceLineaire((n) {
      const EmailDetector().detect('a' * n);
    }, n: 16000);
  });

  test('email : longue suite avec points', () async {
    await expectCroissanceLineaire((n) {
      const EmailDetector().detect('a.' * n);
    }, n: 8000);
  });

  test('email : adresse valide toujours détectée après le correctif', () {
    final texte = 'Écrire à ${'x' * 30}@example.fr svp';
    expect(const EmailDetector().detect(texte), hasLength(1));
  });

  test('adresse : « N rue » répété sans code postal', () async {
    await expectCroissanceLineaire((n) {
      const AdresseDetector().detect('1 rue a ' * n);
    }, n: 2000);
  });

  test('adresse : « N rue » répété (variante courte)', () async {
    await expectCroissanceLineaire((n) {
      const AdresseDetector().detect('1 rue ' * n);
    }, n: 4000);
  });

  test('adresse : adresse valide toujours détectée', () {
    const t = '12 rue des Lilas, 75015 Paris';
    expect(const AdresseDetector().detect(t), hasLength(1));
  });
}
