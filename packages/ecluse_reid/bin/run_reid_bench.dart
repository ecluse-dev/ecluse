import 'dart:convert';
import 'dart:io';

import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// Causes d'échec de la chaîne actuelle `extractQis` puis `estimate`, déduites
/// du message de l'`ArgumentError` (le seul signal que l'API actuelle donne).
String _cause(String message) {
  if (message.contains('Un seul QI par type')) return 'doublon_de_type';
  if (message.contains('un QI lieu')) return 'profession_sans_lieu';
  if (message.contains('inconnu (ni spécialité')) return 'profession_inconnue';
  if (message.contains('sans population')) return 'lieu_sans_population';
  if (message.contains('inconnue')) return 'commune_inconnue';
  return 'autre';
}

/// Deux usages (graine et corpus : `bench/generate_corpus_qi.py`) :
///
///   dart run bin/run_reid_bench.dart --avant <corpus.jsonl>
///     Mesure l'état actuel : sur chaque document, exécute `extractQis` puis
///     `estimate`, compte les exceptions par cause et les documents sans QI que
///     `estimate` classe pourtant en risque « faible ».
///
///   dart run bin/run_reid_bench.dart <corpus.jsonl> <sortie.jsonl>
///     Exécute `evaluateText` et écrit, par document, les QI positionnés et le
///     statut, au format attendu par `bench/score_qi.py`.
Future<void> main(List<String> args) async {
  final avant = args.isNotEmpty && args.first == '--avant';
  if (args.length != 2) {
    stderr.writeln('Usage : dart run bin/run_reid_bench.dart --avant '
        '<corpus.jsonl>\n        dart run bin/run_reid_bench.dart '
        '<corpus.jsonl> <sortie.jsonl>');
    exitCode = 64;
    return;
  }
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.preload();
  if (avant) {
    _mesureAvant(ref, args[1]);
  } else {
    _ecritPredictions(ref, args[0], args[1]);
  }
}

const _statuts = {
  EvaluationStatut.evalue: 'evalue',
  EvaluationStatut.aucunQi: 'aucun_qi',
  EvaluationStatut.nonEvaluable: 'non_evaluable',
};

void _ecritPredictions(EcluseReference ref, String corpus, String sortie) {
  final out = File(sortie).openWrite();
  final parStatut = <String, int>{};
  var documents = 0;
  var exceptions = 0;
  for (final ligne in File(corpus).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    documents++;
    try {
      final e = evaluateText(ref, doc['text'] as String);
      final statut = _statuts[e.statut]!;
      parStatut[statut] = (parStatut[statut] ?? 0) + 1;
      out.writeln(jsonEncode({
        'id': doc['id'],
        'statut': statut,
        'entities': [
          for (final s in e.spans)
            {'type': s.type.name, 'start': s.start, 'end': s.end},
        ],
      }));
    } catch (_) {
      // evaluateText ne doit jamais lever : on compte, on n'avale pas.
      exceptions++;
    }
  }
  out.close();
  stdout.writeln('$corpus : $documents documents, $exceptions exception(s)');
  for (final k in parStatut.keys.toList()..sort()) {
    stdout.writeln('  ${k.padRight(14)} ${parStatut[k]}');
  }
}

void _mesureAvant(EcluseReference ref, String corpus) {
  var documents = 0;
  var sansException = 0;
  var sansQiFaible = 0;
  final causes = <String, int>{};
  for (final ligne in File(corpus).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    documents++;
    final qis = extractQis(ref, doc['text'] as String);
    try {
      final e = estimate(ref, qis);
      sansException++;
      if (qis.isEmpty && e.band == RiskBand.faible) sansQiFaible++;
    } on ArgumentError catch (e) {
      final c = _cause(e.message.toString());
      causes[c] = (causes[c] ?? 0) + 1;
    }
  }
  final exceptions = documents - sansException;
  stdout.writeln('$corpus : $documents documents');
  stdout.writeln('  exceptions de la chaîne actuelle : $exceptions '
      '(${(100 * exceptions / documents).toStringAsFixed(1)} %)');
  for (final c in causes.keys.toList()..sort()) {
    stdout.writeln('    ${c.padRight(22)} ${causes[c]}');
  }
  stdout.writeln('  sans QI, classés « risque faible » : $sansQiFaible');
}
