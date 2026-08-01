import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';

/// Correspondance entre les noms d'enumeration Dart (camelCase) et les types
/// utilises dans les corpus d'entites floues (snake_case).
///
/// Tout type absent de cette table est signale en fin d'execution plutot que
/// d'etre silencieusement renomme : un type mal mappe se traduirait par un
/// score de zero sans explication visible.
const Map<String, String> typeMap = {
  'nom': 'nom',
  'adresse': 'adresse',
  'dateNaissance': 'date_naissance',
  'date_naissance': 'date_naissance',
  'telephone': 'telephone',
  'email': 'email',
  'etablissement': 'etablissement',
  // Detecteurs structurels : presents dans la sortie, absents des corpus flous.
  // Conserves tels quels — ils comptent comme sur-masquage, ce qui est correct
  // (masquer un NIR dans un corpus qui n'en annote pas EST une detection en
  // trop du point de vue de ce corpus).
  'nir': 'nir',
  'rpps': 'rpps',
  'iban': 'iban',
  'finess': 'finess',
};

/// Execute `ecluse_redact` sur un corpus JSONL et ecrit les predictions
/// au format attendu par `bench/score_flou.py`.
///
/// Usage :
///   dart run bin/run_redact_bench.dart <corpus.jsonl> <sortie.jsonl>
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
        'Usage : dart run bin/run_redact_bench.dart <corpus.jsonl> <sortie.jsonl>');
    exitCode = 64;
    return;
  }

  final corpusPath = args[0];
  final outPath = args[1];

  final sink = File(outPath).openWrite();
  var documents = 0;
  var entityCount = 0;
  final parType = <String, int>{};
  final typesInconnus = <String>{};

  for (final line in File(corpusPath).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final doc = jsonDecode(line) as Map<String, dynamic>;
    final text = doc['text'] as String;

    final result = await Ecluse.redact(text);

    // Garde-fou : l'invariant de reversibilite doit tenir sur chaque document
    // du corpus. Une rupture ici est plus grave qu'un mauvais score.
    final restaure = Ecluse.restore(result.maskedText, result.mapping);
    if (restaure != text) {
      stderr.writeln(
          'ALERTE : restauration non byte-exacte sur le document ${doc['id']}');
    }

    final entities = <Map<String, dynamic>>[];
    for (final e in result.entities) {
      final brut = e.type.name;
      final mappe = typeMap[brut];
      if (mappe == null) typesInconnus.add(brut);
      final type = mappe ?? brut;
      parType[type] = (parType[type] ?? 0) + 1;
      entities.add({'type': type, 'start': e.start, 'end': e.end});
    }

    sink.writeln(jsonEncode({'id': doc['id'], 'entities': entities}));
    documents++;
    entityCount += entities.length;
  }

  await sink.flush();
  await sink.close();

  stdout.writeln('Ecluse redact : $documents documents, '
      '$entityCount entites -> $outPath');
  final types = parType.keys.toList()..sort();
  for (final t in types) {
    stdout.writeln('    ${t.padRight(16)} ${parType[t]}');
  }

  if (typesInconnus.isNotEmpty) {
    stderr.writeln('\nATTENTION — types non mappes, a ajouter a typeMap :');
    for (final t in typesInconnus) {
      stderr.writeln('    $t');
    }
    stderr.writeln('Ces types seront scores tels quels et compteront '
        'probablement comme faux positifs.');
  }
}
