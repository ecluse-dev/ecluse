import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// SIRET nommé (P2-259) : quatorze chiffres près du mot « SIRET ». Nombres
/// fabriqués : 73282932000124 a une clé de Luhn juste, 73282932000127 fausse.
void main() {
  const detector = FinessDetector();

  Future<List<DetectedEntity>> detect(String text) =>
      detector.detect(NormalizedText.identity(text));

  test('clé juste : siren, confiance 0,9, empan entier, positions exactes',
      () async {
    const texte = 'Le SIRET est 73282932000124.';
    final e = (await detect(texte)).single;
    expect(e.type, EntityType.siren);
    expect(e.confidence, 0.9);
    expect(texte.substring(e.start, e.end), '73282932000124');
  });

  test('clé fausse : siren, confiance 0,3', () async {
    final e = (await detect('SIRET 73282932000127')).single;
    expect(e.type, EntityType.siren);
    expect(e.confidence, FinessDetector.confianceSiretCleFausse);
  });

  test('groupé 3-3-3-5, casse indifférente, mot après le nombre', () async {
    expect(await detect('siret : 732 829 320 00124'), hasLength(1));
    expect(await detect('73282932000124 (Siret)'), hasLength(1));
  });

  test('rejets : sans le mot, 13 ou 15 chiffres, collé à un chiffre', () async {
    // Sans le mot, la clé juste est masquée depuis P2-323 (voir
    // siret_tva_sans_libelle_masque_test.dart) ; la clé fausse ne l'est pas.
    expect(await detect('Référence 73282932000127'), isEmpty);
    expect(await detect('SIRET 7328293200012'), isEmpty);
    expect(await detect('SIRET 732829320001245'), isEmpty);
    expect(await detect('SIRET 173282932000124'), isEmpty);
  });

  test('SIRET et SIREN de neuf chiffres : le SIREN reste détecté seul',
      () async {
    final e = await detect('SIRET 732829320');
    expect(e.single.value, '732829320');
  });
}
