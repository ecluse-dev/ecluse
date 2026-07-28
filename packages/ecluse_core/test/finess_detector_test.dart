import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

void main() {
  const detector = FinessDetector();

  Future<List<DetectedEntity>> detect(String text) =>
      detector.detect(NormalizedText.identity(text));

  group('FinessDetector — FINESS valides', () {
    test('570000125 (Moselle)', () async {
      final entities = await detect('570000125');
      expect(entities, hasLength(1));
      expect(entities.single.type, EntityType.finess);
      expect(entities.single.value, '570000125');
      expect(entities.single.confidence, 0.5);
    });

    test('750123408 (Paris)', () async {
      expect(await detect('750123408'), hasLength(1));
    });

    test('973000557 (DOM)', () async {
      expect(await detect('973000557'), hasLength(1));
    });

    test('130550114', () async {
      expect(await detect('130550114'), hasLength(1));
    });

    test('les positions start/end correspondent au texte source', () async {
      const text = 'FINESS=570000125;';
      final e = (await detect(text)).single;
      expect(text.substring(e.start, e.end), e.value);
    });
  });

  group('FinessDetector — rejets', () {
    test('570000126 : clé Luhn cassée', () async {
      expect(await detect('570000126'), isEmpty);
    });

    test('750123409 : clé Luhn cassée', () async {
      expect(await detect('750123409'), isEmpty);
    });

    test('texte vide', () async {
      expect(await detect(''), isEmpty);
    });

    test('ne matche pas à l\'intérieur d\'une séquence plus longue (NIR)',
        () async {
      expect(await detect('1 85 05 78 006 084 91'), isEmpty);
    });

    test('ne matche pas à l\'intérieur d\'une séquence plus longue (RPPS)',
        () async {
      expect(await detect('10001234565'), isEmpty);
    });
  });

  group('FinessDetector — contexte -> confiance HAUTE', () {
    test('Établissement CH de Metz, FINESS 570000125', () async {
      final entities =
          await detect('Établissement CH de Metz, FINESS 570000125');
      expect(entities, hasLength(1));
      expect(entities.single.value, '570000125');
      expect(entities.single.confidence, 0.9);
    });

    test('FINESS ET : 750123408', () async {
      final entities = await detect('FINESS ET : 750123408');
      expect(entities, hasLength(1));
      expect(entities.single.value, '750123408');
      expect(entities.single.confidence, 0.9);
    });
  });

  group('FinessDetector — collision SIREN', () {
    test('732829320 sans contexte -> confiance BASSE, jamais haute', () async {
      final entities = await detect('732829320');
      expect(entities, hasLength(1));
      expect(entities.single.type, EntityType.finess);
      expect(entities.single.confidence, 0.5);
    });

    test('552081317 sans contexte -> confiance BASSE, jamais haute', () async {
      final entities = await detect('552081317');
      expect(entities, hasLength(1));
      expect(entities.single.confidence, 0.5);
    });

    test('SIREN dans un contexte sans "finess" reste à confiance basse',
        () async {
      final entities = await detect('Le SIREN de la société est 732829320.');
      expect(entities.single.confidence, 0.5);
    });
  });
}
