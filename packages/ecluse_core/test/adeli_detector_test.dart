import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_core/src/luhn.dart';
import 'package:test/test.dart';

/// Valeurs fabriquées : 9 chiffres dont le dernier est une clé Luhn calculée
/// ici, jamais copiée d'une source réelle.
String _withLuhnKey(String eight) {
  for (var k = 0; k < 10; k++) {
    final candidate = '$eight$k';
    if (isLuhnValid(candidate)) return candidate;
  }
  throw StateError('inatteignable');
}

void main() {
  const detector = AdeliDetector();

  Future<List<DetectedEntity>> detect(String text) =>
      detector.detect(NormalizedText.identity(text));

  final valid = _withLuhnKey('75231234');
  final invalid = '${valid.substring(0, 8)}${(int.parse(valid[8]) + 1) % 10}';

  group('AdeliDetector — avec le mot ADELI accolé', () {
    test('clé Luhn valide : confiance 0,95', () async {
      final text = 'N° ADELI : $valid (Mme Test).';
      final e = (await detect(text)).single;
      expect(e.type, EntityType.adeli);
      expect(e.value, valid);
      expect(e.confidence, 0.95);
      expect(text.substring(e.start, e.end), valid);
    });

    test('clé invalide : masqué quand même, confiance 0,6', () async {
      final e = (await detect('Numéro ADELI saisi : $invalid.')).single;
      expect(e.type, EntityType.adeli);
      expect(e.value, invalid);
      expect(e.confidence, 0.6);
    });

    test('numéro corse 2A/2B : aucune validation de clé, confiance 0,6',
        () async {
      for (final dept in ['2A', '2B']) {
        final value = '${dept}6021939';
        final e = (await detect('ADELI $value')).single;
        expect(e.type, EntityType.adeli);
        expect(e.value, value);
        expect(e.confidence, 0.6);
      }
    });

    test('chiffres espacés irrégulièrement (DigitCompaction)', () async {
      final spaced = '${valid.substring(0, 2)} ${valid.substring(2, 4)} '
          '${valid.substring(4)}';
      final text = 'numéro ADELI $spaced';
      final e = (await detect(text)).single;
      expect(text.substring(e.start, e.end), spaced);
      expect(e.confidence, 0.95);
    });

    test('variantes de libellé : ADELI n°, adeli:, ADELI=', () async {
      for (final label in ['ADELI n° ', 'adeli: ', 'ADELI=', 'N°ADELI ']) {
        expect(await detect('$label$valid'), hasLength(1), reason: label);
      }
    });
  });

  group('AdeliDetector — rejets', () {
    test('sans le mot ADELI : rien (le FINESS garde ce cas)', () async {
      expect(await detect('numéro $valid'), isEmpty);
      expect(await detect('numéro $invalid'), isEmpty);
      expect(await detect('6021939 2B6021939'), isEmpty);
    });

    test('mot ADELI trop loin du nombre : rien', () async {
      final far = 'ADELI est un répertoire ancien. Le dossier $invalid.';
      expect(await detect(far), isEmpty);
    });

    test('8 ou 10 chiffres : rien', () async {
      expect(await detect('ADELI ${valid.substring(1)}'), isEmpty);
      expect(await detect('ADELI ${valid}0'), isEmpty);
    });

    test('mot-clé sans nombre : rien', () async {
      expect(await detect('Le numéro ADELI est obligatoire.'), isEmpty);
    });

    test('nombre plus long collé (NIR) : rien', () async {
      expect(await detect('ADELI 1850578006084'), isEmpty);
    });
  });

  group('AdeliDetector — priorité face à FINESS', () {
    test('ADELI accolé l\'emporte sur le FINESS bas de même étendue', () async {
      final text = 'N° ADELI : $valid';
      final all = [
        ...await detect(text),
        ...await const FinessDetector().detect(NormalizedText.identity(text)),
      ];
      final kept = resolveOverlaps(all);
      expect(kept, hasLength(1));
      expect(kept.single.type, EntityType.adeli);
    });
  });
}
