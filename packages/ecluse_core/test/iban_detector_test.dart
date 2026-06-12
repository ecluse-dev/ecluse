import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

void main() {
  const detector = IbanFrDetector();

  group('IbanFrDetector — IBAN valides', () {
    test('détecte un IBAN FR compact', () {
      final entities = detector.detect(
        'Virement vers FR7630006000011234567890189 effectué.',
      );
      expect(entities, hasLength(1));
      expect(entities.single.type, EntityType.iban);
      expect(entities.single.confidence, 1.0);
    });

    test('détecte un IBAN groupé par 4 (format bancaire courant)', () {
      final entities = detector.detect(
        'IBAN : FR76 3000 6000 0112 3456 7890 189',
      );
      expect(entities, hasLength(1));
      expect(entities.single.value, 'FR76 3000 6000 0112 3456 7890 189');
    });

    test('détecte un IBAN en minuscules', () {
      final entities = detector.detect('fr7630006000011234567890189');
      expect(entities, hasLength(1));
    });

    test('détecte un IBAN avec lettre dans le numéro de compte', () {
      final entities = detector.detect('RIB: FR603000400827A123456789044');
      expect(entities, hasLength(1));
    });

    test('détecte plusieurs IBAN dans le même texte', () {
      final entities = detector.detect(
        'De FR7630006000011234567890189 vers FR603000400827A123456789044.',
      );
      expect(entities, hasLength(2));
    });

    test('les positions start/end correspondent au texte source', () {
      const text = 'cpt FR7630006000011234567890189.';
      final e = detector.detect(text).single;
      expect(text.substring(e.start, e.end), e.value);
    });
  });

  group('IbanFrDetector — rejets', () {
    test('rejette une clé de contrôle invalide', () {
      expect(detector.detect('FR7730006000011234567890189'), isEmpty);
    });

    test('ignore un IBAN non français', () {
      expect(detector.detect('DE89370400440532013000'), isEmpty);
    });

    test('ne matche pas enchâssé dans une séquence alphanumérique', () {
      expect(detector.detect('XFR7630006000011234567890189Z'), isEmpty);
    });

    test('ignore un texte sans IBAN', () {
      expect(detector.detect('Le franc FR a disparu en 2002.'), isEmpty);
    });

    test('texte vide', () {
      expect(detector.detect(''), isEmpty);
    });
  });
}
