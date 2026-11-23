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
  test('le message d\'un corpus absent donne la commande exacte', () {
    final message = messageCorpusIntrouvable();
    expect(message, contains(commandeCorpus));
    expect(message, contains('--n 1000 --seed 42'));
    expect(message, contains('bench/corpus.jsonl'));
  });

  test('EcluseEngine ≡ ancien pipeline sur le corpus de benchmark', () async {
    final corpusPath = _findCorpusPath();
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

/// La commande qui génère le corpus (déterministe, graine 42) : sur une
/// machine neuve, `bench/corpus.jsonl` n'existe pas (ignoré par git, P2-266).
/// Le test n'appelle pas Python lui-même et ne se saute jamais en silence
/// (règle 4 : un corpus absent est un refus avec son motif).
const commandeCorpus =
    'python3 bench/generate_corpus.py --n 1000 --seed 42 --out bench/corpus.jsonl';

/// Message d'échec quand le corpus est absent, avec la commande à lancer
/// depuis la racine du dépôt.
String messageCorpusIntrouvable() =>
    'bench/corpus.jsonl introuvable (ni à la racine, ni depuis '
    'packages/ecluse_bench). Corpus de benchmark non versionné : générer '
    'depuis la racine du dépôt avec `$commandeCorpus`, puis relancer les tests.';

/// Le test peut être lancé depuis la racine du repo ou depuis ce package :
/// résout `bench/corpus.jsonl` dans les deux cas.
String _findCorpusPath() {
  for (final candidate in ['bench/corpus.jsonl', '../../bench/corpus.jsonl']) {
    if (File(candidate).existsSync()) return candidate;
  }
  throw StateError(messageCorpusIntrouvable());
}
