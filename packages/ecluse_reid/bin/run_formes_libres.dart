import 'dart:convert';
import 'dart:io';

import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// Mesure par forme de `extrairePathologies` sur le corpus `formes_libres`
/// (P2-129, mesure seulement : aucune correction).
///
///     dart run bin/run_formes_libres.dart \
///       ../../bench/patho/corpus_pathologies_formes_libres.jsonl
///
/// Pour chaque forme, en lecture « brut » et « rattachées seulement » :
/// mentions attendues trouvées (TP) ou manquées (FN), mentions trouvées en
/// trop (FP) avec leur texte. Appariement strict (mêmes bornes) ; une
/// mention trouvée sur les bonnes bornes mais non rattachée compte comme
/// manquée en lecture « rattachées ».
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage : run_formes_libres <formes_libres.jsonl>');
    exit(64);
  }
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.rareDiseases.load();
  final docs = [
    for (final l in File(args[0]).readAsLinesSync())
      if (l.trim().isNotEmpty) jsonDecode(l) as Map<String, dynamic>,
  ];
  for (final filtre in [false, true]) {
    print('== ${filtre ? 'rattachées seulement' : 'brut'}');
    final parForme = <String, List<int>>{}; // docs, attendues, TP, FN, FP
    final fauxParForme = <String, Map<String, int>>{};
    for (final d in docs) {
      final forme = d['forme'] as String;
      final texte = d['text'] as String;
      final gold = {
        for (final p in (d['pathologies'] as List).cast<Map<String, dynamic>>())
          (p['start'] as int, p['end'] as int),
      };
      final s = parForme.putIfAbsent(forme, () => [0, 0, 0, 0, 0]);
      s[0]++;
      s[1] += gold.length;
      final vues = <(int, int)>{};
      for (final m in extrairePathologies(texte, catalogue: ref.rareDiseases)) {
        if (filtre && !m.rattachee) continue;
        if (gold.contains((m.start, m.end))) {
          s[2]++;
          vues.add((m.start, m.end));
        } else {
          s[4]++;
          final f = fauxParForme.putIfAbsent(forme, () => {});
          f[m.text] = (f[m.text] ?? 0) + 1;
        }
      }
      s[3] += gold.length - vues.length;
    }
    var tp = 0, fn = 0, fp = 0;
    for (final e in parForme.entries) {
      final s = e.value;
      tp += s[2];
      fn += s[3];
      fp += s[4];
      print('  ${e.key.padRight(18)} docs ${s[0]}, attendues ${s[1]}, '
          'trouvées ${s[2]}, manquées ${s[3]}, en trop ${s[4]}'
          '${fauxParForme[e.key] == null ? '' : ' ${fauxParForme[e.key]}'}');
    }
    String pc(num a, num b) =>
        b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)} %';
    print('  TOTAL TP $tp, FN $fn, FP $fp ; précision ${pc(tp, tp + fp)}, '
        'rappel ${pc(tp, tp + fn)}');
  }
}
