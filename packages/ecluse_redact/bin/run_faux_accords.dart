import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';

/// Rejoue `Ecluse.redact` (chemin du produit) sur un corpus JSONL et écrit, par
/// document, les entités masquées : type, confiance et provenance, jamais la
/// valeur ni le texte (P2-279, mesure). `bench/score_faux_accords.py` en tire
/// un taux de masquages à tort par détecteur, avec un intervalle de confiance.
///
/// Usage : `dart run bin/run_faux_accords.dart corpus.jsonl sortie.jsonl`
Future<void> main(List<String> argv) async {
  if (argv.length != 2) {
    stderr.writeln('usage : run_faux_accords.dart corpus sortie');
    exit(2);
  }
  final sortie = File(argv[1]).openWrite();
  for (final ligne in File(argv[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    final r = await Ecluse.redact(doc['text'] as String);
    sortie.writeln(jsonEncode({
      'id': doc['id'],
      'e': [
        for (final e in r.entities)
          [e.type.name, e.confidence, e.provenance?.name ?? '']
      ],
    }));
  }
  await sortie.close();
}
