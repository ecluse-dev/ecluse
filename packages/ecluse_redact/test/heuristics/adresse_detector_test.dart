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

    test('code postal + commune seul, sans numéro ni type de voie', () {
      final entities = detector.detect('70160 Saint Rémy en Comté');
      expect(entities, hasLength(1));
      expect(entities.single.value, '70160 Saint Rémy en Comté');
      expect(entities.single.confidence, 0.55);
    });

    test('code postal isolé, sans commune qui suit -> non détecté', () {
      final entities = detector.detect('Il habite dans le 70160.');
      expect(entities, isEmpty);
    });

    test(
        'adresse complète + adresse code postal/commune seule sur une '
        'autre ligne -> deux entités distinctes', () {
      final entities = detector.detect(
        '8 rue Robert Roy 70170 Port sur Saône\n'
        '70160 Saint Rémy en Comté',
      );
      expect(entities, hasLength(2));
      expect(entities[0].value, '8 rue Robert Roy 70170 Port sur Saône');
      expect(entities[0].confidence, 0.7);
      expect(entities[1].value, '70160 Saint Rémy en Comté');
      expect(entities[1].confidence, 0.55);
    });
  });
}
