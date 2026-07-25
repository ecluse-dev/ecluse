import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = EmailDetector();

  group('EmailDetector', () {
    test('adresse email standard', () {
      final entities = detector.detect('Contact : julien.vasseur@example.fr.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'julien.vasseur@example.fr');
    });

    test('texte sans arobase -> non détecté', () {
      final entities = detector.detect('Contact au service RH.');
      expect(entities, isEmpty);
    });
  });
}
