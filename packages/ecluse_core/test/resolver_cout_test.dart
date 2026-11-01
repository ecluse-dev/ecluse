import 'dart:math';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// Coût et équivalence de `resolveOverlaps` (P2-66). Chaque candidate était
/// comparée à toutes les entités déjà retenues : 80 000 entités (un tableau de
/// 40 000 rangées) prenaient 18 s. Les entités retenues sont disjointes : seule
/// celle qui commence juste avant la fin du candidat peut le chevaucher.
///
/// [_reference] est l'ancienne implémentation, gardée ici pour comparer.
List<DetectedEntity> _reference(List<DetectedEntity> entities) {
  final byPriority = [...entities]..sort((a, b) {
      final lengthA = a.end - a.start;
      final lengthB = b.end - b.start;
      if (lengthA != lengthB) return lengthB - lengthA;
      final byConfidence = b.confidence.compareTo(a.confidence);
      if (byConfidence != 0) return byConfidence;
      final tierA = a.tier?.priority ?? -1;
      final tierB = b.tier?.priority ?? -1;
      if (tierA != tierB) return tierB - tierA;
      return a.start - b.start;
    });
  final kept = <DetectedEntity>[];
  for (final candidate in byPriority) {
    final overlaps = kept.any(
      (k) => candidate.start < k.end && k.start < candidate.end,
    );
    if (!overlaps) kept.add(candidate);
  }
  kept.sort((a, b) => a.start - b.start);
  return kept;
}

DetectedEntity _e(int start, int end, double confiance, DetectorTier? tier,
        EntityType type) =>
    DetectedEntity(
      type: type,
      start: start,
      end: end,
      value: 'x' * (end - start),
      confidence: confiance,
      tier: tier,
    );

String _signature(List<DetectedEntity> l) => l
    .map((e) => '${e.start}-${e.end}-${e.type.name}-${e.confidence}')
    .join(',');

void main() {
  test('équivalence avec l\'ancienne implémentation (5 000 tirages)', () {
    const types = [
      EntityType.nir,
      EntityType.nom,
      EntityType.adresse,
      EntityType.telephone
    ];
    const tiers = [
      null,
      DetectorTier.structural,
      DetectorTier.reference,
      DetectorTier.pattern
    ];
    for (var graine = 0; graine < 5000; graine++) {
      final r = Random(graine);
      final n = r.nextInt(40);
      final entites = [
        for (var i = 0; i < n; i++)
          () {
            final debut = r.nextInt(60);
            final fin = debut + 1 + r.nextInt(12);
            return _e(
              debut,
              fin,
              [0.5, 0.6, 0.7, 0.9, 1.0][r.nextInt(5)],
              tiers[r.nextInt(tiers.length)],
              types[r.nextInt(types.length)],
            );
          }()
      ];
      expect(
          _signature(resolveOverlaps(entites)), _signature(_reference(entites)),
          reason: 'graine $graine');
    }
  });

  test('80 000 entités disjointes en moins de 3 s', () {
    final entites = [
      for (var i = 0; i < 80000; i++)
        _e(i * 10, i * 10 + 8, 0.7, null, EntityType.nom),
    ];
    final sw = Stopwatch()..start();
    final r = resolveOverlaps(entites);
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    expect(r.length, 80000);
  });

  test('80 000 entités qui se chevauchent par paires en moins de 3 s', () {
    final entites = [
      for (var i = 0; i < 40000; i++) ...[
        _e(i * 20, i * 20 + 12, 0.9, null, EntityType.nom),
        _e(i * 20 + 6, i * 20 + 16, 0.6, null, EntityType.adresse),
      ],
    ];
    final sw = Stopwatch()..start();
    final r = resolveOverlaps(entites);
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    expect(r.length, 40000);
  });
}
