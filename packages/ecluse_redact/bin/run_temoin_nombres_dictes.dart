import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';

/// Rejoue `Ecluse.redact` sur un corpus JSONL et écrit, par document : les
/// entités masquées (type et bornes, jamais la valeur) et le nombre de
/// signalements « nombre dicté non reconnu » (P2-270, mesure) et le nombre
/// d'avertissements distincts « précédée d'un mot comme » que la garde du mot
/// voisin émet à la place du signalement (P2-299). C'est le chemin du produit
/// (`Ecluse.redact`), pas le moteur seul.
///
/// Usage : `dart run bin/run_temoin_nombres_dictes.dart corpus.jsonl sortie.jsonl`
Future<void> main(List<String> argv) async {
  if (argv.length != 2) {
    stderr.writeln('usage : run_temoin_nombres_dictes.dart corpus sortie');
    exit(2);
  }
  final sortie = File(argv[1]).openWrite();
  for (final ligne in File(argv[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    final r = await Ecluse.redact(doc['text'] as String);
    final signalements = r.warnings
        .where((w) => w.startsWith('nombre dicté non reconnu'))
        .length;
    final motVoisin =
        r.warnings.where((w) => w.contains("précédée d'un mot comme")).length;
    sortie.writeln(jsonEncode({
      'id': doc['id'],
      'entities': [
        for (final e in r.entities)
          {'type': e.type.name, 'start': e.start, 'end': e.end}
      ],
      'signalements': signalements,
      'signalements_mot_voisin': motVoisin,
    }));
  }
  await sortie.close();
}
