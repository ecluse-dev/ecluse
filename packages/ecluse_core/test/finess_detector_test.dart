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

    test(
        'un nombre sans aucun mot de contexte reste un FINESS à confiance basse',
        () async {
      final entities = await detect('Société 732829320 immatriculée.');
      expect(entities.single.type, EntityType.finess);
      expect(entities.single.confidence, 0.5);
    });
  });

  // P2-248 : le nombre nommé « SIREN » ou « SIRET » est un SIREN, pas un
  // FINESS. Il reste masqué (le SIREN d'un entrepreneur individuel désigne une
  // personne) : confiance haute, comme un identifiant annoncé par son nom.
  group('FinessDetector — SIREN nommé (P2-248)', () {
    test('« Le SIREN de la société est 732829320. » -> siren, 0,9', () async {
      const text = 'Le SIREN de la société est 732829320.';
      final e = (await detect(text)).single;
      expect(e.type, EntityType.siren);
      expect(e.confidence, 0.9);
      expect(text.substring(e.start, e.end), '732829320');
      expect(e.value, '732829320');
    });

    test('« SIRET » nomme aussi un SIREN (nombre de neuf chiffres)', () async {
      final e = (await detect('SIRET : 732829320')).single;
      expect(e.type, EntityType.siren);
    });

    test('le libellé peut suivre le nombre, dans la même fenêtre', () async {
      final e = (await detect('732829320 (numéro SIREN)')).single;
      expect(e.type, EntityType.siren);
    });

    test('casse indifférente et écriture groupée 3-3-3', () async {
      final e = (await detect('siren 732 829 320')).single;
      expect(e.type, EntityType.siren);
      expect(e.value, '732 829 320');
    });

    test('hors de la fenêtre de 40 caractères : reste un FINESS', () async {
      final texte = 'SIREN${' ' * 45}732829320';
      final e = (await detect(texte)).single;
      expect(e.type, EntityType.finess);
      expect(e.confidence, 0.5);
    });

    test('le mot FINESS à proximité l\'emporte : FINESS à confiance haute',
        () async {
      final e = (await detect('FINESS 570000125, SIREN voisin')).single;
      expect(e.type, EntityType.finess);
      expect(e.confidence, 0.9);
    });

    test('un vrai FINESS sans le mot SIREN reste un FINESS', () async {
      final e =
          (await detect('Établissement CH de Metz, FINESS 570000125')).single;
      expect(e.type, EntityType.finess);
    });

    test('clé de Luhn cassée : rien, même après « SIREN »', () async {
      expect(await detect('Le SIREN est 732829321'), isEmpty);
    });
  });

  group('FinessDetector — identifiant adjacent à un nombre', () {
    test('nombre après un FINESS compact', () async {
      const text = 'FINESS 570000125 12 lits';
      final entities = await detect(text);
      expect(entities, hasLength(1));
      expect(text.substring(entities.single.start, entities.single.end),
          '570000125');
    });
  });
}
