import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = AdresseDetector();

  group('AdresseDetector', () {
    test('numéro + voie + code postal + commune', () {
      final entities =
          detector.detect('Il habite 12 rue des Lilas, 75015 Paris.');
      expect(entities, hasLength(1));
      expect(entities.single.value, contains('75015 Paris'));
      expect(entities.single.value, contains('rue des Lilas'));
    });

    test('sans code postal -> non détecté', () {
      final entities = detector.detect('Il habite rue des Lilas à Paris.');
      expect(entities, isEmpty);
    });

    test('commune composée', () {
      final entities = detector
          .detect('14 avenue Foch, 54000 Nancy-Saint-Nicolas est proche.');
      expect(entities, hasLength(1));
    });
  });
}
