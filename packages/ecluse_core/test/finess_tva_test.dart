import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// Numéro de TVA intracommunautaire (P2-260). Nombres fabriqués : SIREN
/// 247510795, clé juste 16.
void main() {
  const detector = FinessDetector();

  Future<List<DetectedEntity>> detect(String text) =>
      detector.detect(NormalizedText.identity(text));

  test('clé juste : siren, confiance 0,9, « FR » compris, positions exactes',
      () async {
    const texte = 'TVA FR16247510795 ok';
    final e = (await detect(texte)).where((x) => x.value.startsWith('FR'));
    expect(e, hasLength(1));
    expect(e.single.type, EntityType.siren);
    expect(e.single.confidence, 0.9);
    expect(texte.substring(e.single.start, e.single.end), 'FR16247510795');
  });

  test('blancs : groupé, clé séparée, insécable, minuscules', () async {
    for (final t in [
      'FR 16 247 510 795',
      'FR16 247 510 795',
      'FR16 247 510 795',
      'fr16247510795',
    ]) {
      final e = (await detect(t)).where((x) => x.value.length >= 13);
      expect(e, hasLength(1), reason: t);
      expect(e.single.value, t);
    }
  });

  test('clé fausse : seulement avec TVA ou intracommunautaire à moins de 40',
      () async {
    final avec = (await detect('TVA : FR99247510795')).single;
    expect(avec.confidence, FinessDetector.confianceTvaCleFausse);
    expect(await detect('n° intracommunautaire FR99247510795'), hasLength(1));
    expect(await detect('Référence FR99247510795'), isEmpty);
    expect(await detect('ACTIVATION FR99247510795'), isEmpty,
        reason: 'le mot TVA doit être entier');
  });

  test('rejets : trop court, trop long, collé à une lettre', () async {
    expect(await detect('TVA FR1624751079'), isEmpty);
    expect(await detect('TVA FR162475107951'), isEmpty);
    expect(await detect('TVA XFR16247510795'), isEmpty);
  });
}
