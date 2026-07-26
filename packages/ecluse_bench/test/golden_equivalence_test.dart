import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// Filet de sécurité du Jalon 1 (voir `docs/Ecluse-Jalon1-refactor-spec.md`,
/// §7) : le nouveau `EcluseEngine` doit produire, sur tout le corpus de
/// benchmark, une sortie strictement identique à celle de l'ancien
/// pipeline (appel direct des détecteurs + `resolveOverlaps`). Toute
/// divergence ici signifie que le refactor a changé un comportement de
/// détection, pas seulement une structure — condition d'acceptation avant
/// de considérer le Jalon 1 terminé.
void main() {
  final corpusPath = _findCorpusPath();

  test('EcluseEngine ≡ ancien pipeline sur le corpus de benchmark', () async {
    const legacyDetectors = <EntityDetector>[
      NirDetector(),
      RppsDetector(),
      IbanFrDetector(),
    ];

    final engine = EcluseEngine(const [
      LegacyDetectorAdapter(NirDetector(), DetectorTier.structural,
          name: 'nir'),
      LegacyDetectorAdapter(RppsDetector(), DetectorTier.structural,
          name: 'rpps'),
      LegacyDetectorAdapter(IbanFrDetector(), DetectorTier.structural,
          name: 'iban'),
    ]);

    var documents = 0;
    var entities = 0;

    for (final line in File(corpusPath).readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final doc = jsonDecode(line) as Map<String, dynamic>;
      final text = doc['text'] as String;
      documents++;

      final legacy = resolveOverlaps([
        for (final detector in legacyDetectors) ...detector.detect(text),
      ]);
      final viaEngine = (await engine.run(text)).entities;

      expect(
        viaEngine.length,
        legacy.length,
        reason: 'doc ${doc['id']} : nombre d\'entités différent',
      );
      for (var i = 0; i < legacy.length; i++) {
        expect(viaEngine[i].type, legacy[i].type, reason: 'doc ${doc['id']}');
        expect(viaEngine[i].start, legacy[i].start, reason: 'doc ${doc['id']}');
        expect(viaEngine[i].end, legacy[i].end, reason: 'doc ${doc['id']}');
        expect(viaEngine[i].value, legacy[i].value, reason: 'doc ${doc['id']}');
        expect(viaEngine[i].confidence, legacy[i].confidence,
            reason: 'doc ${doc['id']}');
      }
      entities += legacy.length;
    }

    stdout.writeln(
        '$documents documents, $entities entités : EcluseEngine ≡ ancien pipeline.');
  });
}

/// Le test peut être lancé depuis la racine du repo ou depuis ce package :
/// résout `bench/corpus.jsonl` dans les deux cas.
String _findCorpusPath() {
  for (final candidate in ['bench/corpus.jsonl', '../../bench/corpus.jsonl']) {
    if (File(candidate).existsSync()) return candidate;
  }
  throw StateError(
      'bench/corpus.jsonl introuvable (ni à la racine, ni depuis packages/ecluse_bench)');
}
