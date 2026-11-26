import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';

/// P2-303 (mesure) : par document, les entités masquées par `Ecluse.redact`
/// (type et bornes) et les **avertissements** de `RedactResult.warnings`
/// (comptes et positions seulement : le code de `lib/` n'y met jamais de
/// valeur ; ce script ne fait que les recopier). C'est le chemin du produit.
/// Rien n'est corrigé.
///
/// Usage (depuis `packages/ecluse_redact`) :
///   `dart run bin/run_gardes_avertissements.dart corpus.jsonl sortie.jsonl`
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage : run_gardes_avertissements.dart corpus sortie');
    exitCode = 64;
    return;
  }
  final sortie = File(args[1]).openWrite();
  for (final ligne in File(args[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    final r = await Ecluse.redact(doc['text'] as String);
    sortie.writeln(jsonEncode({
      'id': doc['id'],
      'entities': [
        for (final e in r.entities)
          {'type': e.type.name, 'start': e.start, 'end': e.end},
      ],
      'warnings': r.warnings,
    }));
  }
  await sortie.close();
}
