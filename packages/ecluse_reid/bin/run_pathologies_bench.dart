import 'dart:convert';
import 'dart:io';

import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// Mesure de `extrairePathologies` (P2-125) sur le corpus de P2-112.
///
///     dart run bin/run_pathologies_bench.dart \
///       ../../bench/patho/corpus_pathologies_indices.jsonl \
///       ../../bench/patho/corpus_pathologies_temoin.jsonl
///
/// Appariement strict (mêmes bornes). Deux lectures : toutes les mentions
/// repérées (« brut »), et seulement celles rattachées à une personne.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
        'usage : run_pathologies_bench <indices.jsonl> <temoin.jsonl>');
    exit(64);
  }
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.rareDiseases.load();

  List<Map<String, dynamic>> lire(String chemin) => [
        for (final l in File(chemin).readAsLinesSync())
          if (l.trim().isNotEmpty) jsonDecode(l) as Map<String, dynamic>,
      ];

  for (final filtre in [false, true]) {
    var tp = 0, fp = 0, fn = 0, categorieJuste = 0;
    final faux = <String, int>{};
    for (final d in lire(args[0])) {
      final texte = d['text'] as String;
      final gold = <(int, int), String>{
        for (final p in (d['pathologies'] as List).cast<Map<String, dynamic>>())
          (p['start'] as int, p['end'] as int): p['categorie'] as String,
      };
      final trouvees = [
        for (final m in extrairePathologies(texte, catalogue: ref.rareDiseases))
          if (!filtre || m.rattachee) m,
      ];
      final vues = <(int, int)>{};
      for (final m in trouvees) {
        final cle = (m.start, m.end);
        if (gold.containsKey(cle)) {
          tp++;
          vues.add(cle);
          if (m.source == 'orphanet' || gold[cle] == m.categorie) {
            categorieJuste++;
          }
        } else {
          fp++;
          faux[m.text] = (faux[m.text] ?? 0) + 1;
        }
      }
      fn += gold.length - vues.length;
    }
    var fpTemoin = 0;
    final fauxTemoin = <String, int>{};
    for (final d in lire(args[1])) {
      for (final m in extrairePathologies(d['text'] as String,
          catalogue: ref.rareDiseases)) {
        if (filtre && !m.rattachee) continue;
        fpTemoin++;
        fauxTemoin[m.text] = (fauxTemoin[m.text] ?? 0) + 1;
      }
    }
    String pc(num a, num b) =>
        b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)} %';
    print('== ${filtre ? 'rattachées seulement' : 'brut'}');
    print('  indices : TP $tp, FP $fp, FN $fn ; précision ${pc(tp, tp + fp)}, '
        'rappel ${pc(tp, tp + fn)} ; catégorie juste ${pc(categorieJuste, tp)}');
    print('  FP indices : $faux');
    print('  témoin : $fpTemoin faux positifs $fauxTemoin');
  }
}
