import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

DetectedEntity e(EntityType t, int s, int end, [double c = 1.0]) =>
    DetectedEntity(
        type: t, start: s, end: end, value: 'x' * (end - s), confidence: c);

void main() {
  group('resolveOverlaps', () {
    test('liste vide', () {
      expect(resolveOverlaps([]), isEmpty);
    });

    test('entités disjointes conservées et triées par début', () {
      final result = resolveOverlaps([
        e(EntityType.iban, 50, 77),
        e(EntityType.nir, 0, 15),
      ]);
      expect(result, hasLength(2));
      expect(result.first.type, EntityType.nir);
    });

    test('un faux RPPS enchâssé dans un IBAN est éliminé', () {
      // Cas réel relevé par le benchmark : fenêtre de 11 chiffres
      // passant Luhn à la fin d\'un IBAN groupé par 4.
      final iban = e(EntityType.iban, 10, 43);
      final fauxRpps = e(EntityType.rpps, 30, 43, 0.9);
      final result = resolveOverlaps([fauxRpps, iban]);
      expect(result, hasLength(1));
      expect(result.single.type, EntityType.iban);
    });

    test('à longueur égale, la confiance la plus haute gagne', () {
      final result = resolveOverlaps([
        e(EntityType.rpps, 0, 11, 0.9),
        e(EntityType.nir, 0, 11, 1.0),
      ]);
      expect(result.single.type, EntityType.nir);
    });

    test('chevauchement partiel : le plus long survit', () {
      final result = resolveOverlaps([
        e(EntityType.rpps, 5, 16, 0.9),
        e(EntityType.iban, 10, 37),
      ]);
      expect(result.single.type, EntityType.iban);
    });
  });
}
