import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = EtablissementDetector();

  group('EtablissementDetector', () {
    test('mot-clé + nom propre simple', () {
      final entities = detector.detect('Le Foyer Les Tilleuls accueille.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Foyer Les Tilleuls');
    });

    test('acronyme + nom propre', () {
      final entities = detector.detect('L\'IME Beauséjour organise une '
          'réunion.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'IME Beauséjour');
    });

    test('mot-clé avec connecteur', () {
      final entities =
          detector.detect('La Résidence du Parc accueille des visiteurs.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Résidence du Parc');
    });

    test('mot-clé en minuscule -> non détecté (évite le sens commun)', () {
      final entities = detector.detect('Le centre de la ville est proche.');
      expect(entities, isEmpty);
    });
  });
}
