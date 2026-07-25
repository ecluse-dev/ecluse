import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = DateNaissanceDetector();

  group('DateNaissanceDetector', () {
    test('né(e) le + date numérique', () {
      final entities = detector.detect('Patient né le 12/05/1988 à Nantes.');
      expect(entities, hasLength(1));
      expect(entities.single.value, '12/05/1988');
    });

    test('né(e) le + date textuelle', () {
      final entities = detector.detect('Née le 3 juillet 1992, domiciliée '
          'à Rennes.');
      expect(entities, hasLength(1));
      expect(entities.single.value, '3 juillet 1992');
    });

    test('date de naissance : + date', () {
      final entities = detector.detect('Date de naissance : 01-01-1980.');
      expect(entities, hasLength(1));
      expect(entities.single.value, '01-01-1980');
    });

    test('une date sans contexte de naissance -> non détectée', () {
      final entities = detector.detect('Réunion prévue le 12/05/2026.');
      expect(entities, isEmpty);
    });
  });
}
