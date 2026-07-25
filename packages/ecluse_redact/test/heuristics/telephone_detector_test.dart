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
}
