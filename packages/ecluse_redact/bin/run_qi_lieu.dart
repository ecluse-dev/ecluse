import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// P2-287 (mesure) : quasi-identifiants `lieu` du rapport de risque de
/// `Ecluse.redact`, par document, avec le mot lu comme commune, les 14 caractères qui
/// le précèdent dans le texte masqué, et la bande de risque avec / sans ce lieu.
/// C'est le chemin du produit (`Ecluse.redact` avec `riskReference`). Rien n'est
/// corrigé. Les mots imprimés viennent de corpus synthétiques.
///
/// Usage (depuis `packages/ecluse_redact`) :
///   `dart run bin/run_qi_lieu.dart corpus.jsonl sortie.jsonl [N_max]`
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage : run_qi_lieu.dart corpus sortie [n_max]');
    exitCode = 64;
    return;
  }
  final nMax = args.length > 2 ? int.parse(args[2]) : 1 << 30;
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.preload();
  final sortie = File(args[1]).openWrite();
  var n = 0;
  for (final ligne in File(args[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    if (n++ >= nMax) break;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    final r = await Ecluse.redact(doc['text'] as String, riskReference: ref);
    final ev = r.risque!.evaluation;
    final masque = r.maskedText;
    final lieux = <Map<String, dynamic>>[];
    for (final s in ev.spans.where((s) => s.type == QiType.lieu)) {
      final avant = s.start > 0 ? masque.substring(s.start - 1, s.start) : '';
      final debutCtx = s.start > 14 ? s.start - 14 : 0;
      final avant2 = masque.substring(debutCtx, s.start);
      final sans =
          '${masque.substring(0, s.start)}___${masque.substring(s.end)}';
      final e2 = evaluateText(ref, sans);
      lieux.add({
        'mot': s.text,
        'avant': avant2,
        'debut_ligne': s.start == 0 || avant == '\n',
        'bande2': e2.estimate?.band.name ?? e2.statut.name,
        'f2': e2.estimate?.f,
      });
    }
    sortie.writeln(jsonEncode({
      'id': doc['id'],
      'statut': ev.statut.name,
      'bande': ev.estimate?.band.name,
      'f': ev.estimate?.f,
      'lieux': lieux,
    }));
  }
  await sortie.close();
}
