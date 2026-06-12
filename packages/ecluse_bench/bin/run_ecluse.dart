import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';

/// Exécute les détecteurs Écluse sur un corpus JSONL et écrit les
/// prédictions au format attendu par `bench/score.py`.
///
/// Usage : dart run ecluse_bench:run_ecluse <corpus.jsonl> <sortie.jsonl>
Future<void> main(List<String> args) async {
  final corpusPath = args.isNotEmpty ? args[0] : 'bench/corpus.jsonl';
  final outPath = args.length > 1 ? args[1] : 'bench/predictions_ecluse.jsonl';

  const detectors = <EntityDetector>[
    NirDetector(),
    RppsDetector(),
    IbanFrDetector(),
  ];

  final sink = File(outPath).openWrite();
  var documents = 0;
  var entityCount = 0;

  for (final line in File(corpusPath).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final doc = jsonDecode(line) as Map<String, dynamic>;
    final text = doc['text'] as String;

    final raw = <DetectedEntity>[
      for (final detector in detectors) ...detector.detect(text),
    ];
    final resolved = resolveOverlaps(raw);

    sink.writeln(jsonEncode({
      'id': doc['id'],
      'entities': [
        for (final e in resolved)
          {'type': e.type.name, 'start': e.start, 'end': e.end},
      ],
    }));
    documents++;
    entityCount += resolved.length;
  }

  await sink.flush();
  await sink.close();
  stdout.writeln(
      'Écluse : $documents documents, $entityCount entités -> $outPath');
}
