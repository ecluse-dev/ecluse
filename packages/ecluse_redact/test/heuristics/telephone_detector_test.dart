import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = TelephoneDetector();

  group('TelephoneDetector', () {
    test('numéro FR avec espaces', () {
      final entities = detector.detect('Joignable au 02 40 12 34 56.');
      expect(entities, hasLength(1));
      expect(entities.single.value, '02 40 12 34 56');
    });

    test('numéro FR sans séparateur', () {
      final entities = detector.detect('Joignable au 0240123456.');
      expect(entities, hasLength(1));
    });

    test('préfixe international', () {
      final entities = detector.detect('Joignable au +33 2 40 12 34 56.');
      expect(entities, hasLength(1));
    });

    test('séquence de chiffres qui n\'est pas un numéro FR -> non détecté', () {
      final entities = detector.detect('Le code est 99 99 99 99 99.');
      expect(entities, isEmpty);
    });
  });

  group('TelephoneDetector — formats internationaux et séparateurs', () {
    // Chaque variante doit être détectée avec le span exact du numéro.
    const variantes = {
      '+33 6 12 34 56 78': '+33 6 12 34 56 78',
      '+33 (0)6 12 34 56 78': '+33 (0)6 12 34 56 78',
      '+33(0)612345678': '+33(0)612345678',
      '+33612345678': '+33612345678',
      '+33.6.12.34.56.78': '+33.6.12.34.56.78',
      '0033 6 12 34 56 78': '0033 6 12 34 56 78',
      '0033612345678': '0033612345678',
      '06.12.34.56.78': '06.12.34.56.78',
      '06-12-34-56-78': '06-12-34-56-78',
      '06\u00A012\u00A034\u00A056\u00A078':
          '06\u00A012\u00A034\u00A056\u00A078',
      '06\u202F12\u202F34\u202F56\u202F78':
          '06\u202F12\u202F34\u202F56\u202F78',
      '+33\u00A06\u00A012\u00A034\u00A056\u00A078':
          '+33\u00A06\u00A012\u00A034\u00A056\u00A078',
    };
    variantes.forEach((numero, attendu) {
      test('détecte $numero', () {
        final text = 'Tel : $numero, merci.';
        final entities = detector.detect(text);
        expect(entities, hasLength(1));
        final e = entities.single;
        expect(e.value, attendu);
        expect(e.start, text.indexOf(numero));
        expect(text.substring(e.start, e.end), attendu);
      });
    });
  });

  group('TelephoneDetector — rejets', () {
    const rejets = {
      'numéro court 15': 'Appelez le 15 en urgence.',
      'numéro court 112': 'Le 112 est le numéro européen.',
      'numéro court 3114': 'Prévention du suicide : 3114.',
      'numéro court 3237': 'Pharmacie de garde : 3237.',
      'date': 'Le 12/03/2024 à 10 h 30.',
      'date ISO': 'Édité le 2024-03-12.',
      'montant': 'Total : 1 234 567,89 €.',
      'code postal': 'Nantes 44000 Cedex.',
      'préfixe 00 non FR': '0044 20 7946 0958',
      'indicatif +33 suivi de 0 sans parenthèses': '+33 0 12 34 56 78',
      'trop long (11 chiffres)': '012345678901',
    };
    rejets.forEach((nom, texte) {
      test('ignore : $nom', () {
        expect(detector.detect(texte), isEmpty);
      });
    });
  });
}
