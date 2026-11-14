import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';

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
  'adeli': 'adeli',
  // Identifiant administratif etiquete (numero de dossier, de patient,
  // IPP...) : produit par `Ecluse.redact` sur les corpus QI et le corpus
  // « identifiant suivi », mais aucun corpus flou n'annote ce type. Meme
  // raisonnement que les detecteurs structurels ci-dessus : conserve tel
  // quel plutot que signale comme inconnu a chaque execution (P2-179).
  'identifiant': 'identifiant',
};

/// Execute `ecluse_redact` sur un corpus JSONL et ecrit les predictions
/// au format attendu par `bench/score_flou.py`.
///
/// Usage :
///   dart run bin/run_redact_bench.dart [--prenoms-insee[=SEUIL]] <corpus.jsonl> <sortie.jsonl>
///
/// `--prenoms-insee` (P2-149) : active l'option `prenomsInsee` de
/// `Ecluse.redact` avec les effectifs de `ecluse_reference`, au seuil par
/// défaut ou à `SEUIL`.
Future<void> main(List<String> argv) async {
  final option = argv.where((a) => a.startsWith('--prenoms-insee')).toList();
  final args = [
    for (final a in argv)
      if (!a.startsWith('--prenoms-insee')) a
  ];
  PrenomsInsee? gazetteer;
  if (option.isNotEmpty) {
    final effectifs =
        EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'))
            .firstNameFrequencies;
    await effectifs.load();
    final valeur = option.last.split('=');
    gazetteer = PrenomsInsee(effectifs,
        seuil: valeur.length == 2
            ? int.parse(valeur[1])
            : PrenomsInsee.seuilParDefaut);
  }
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
  var refus = 0;
  final parType = <String, int>{};
  final typesInconnus = <String>{};

  for (final line in File(corpusPath).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final doc = jsonDecode(line) as Map<String, dynamic>;
    final text = doc['text'] as String;

    final RedactResult result;
    try {
      result = await Ecluse.redact(text, prenomsInsee: gazetteer);
    } on TableauAmbiguException {
      // Refus explicite (règle 4) : rien n'est envoyé, donc rien ne fuit.
      // On le note (`refuse`) au lieu de faire tomber tout le banc ; le
      // tableau de bord compte les refus à part (P2-153).
      sink.writeln(jsonEncode({
        'id': doc['id'],
        'entities': <Map<String, dynamic>>[],
        'refuse': true
      }));
      refus++;
      stderr.writeln('REFUS : document ${doc['id']} (tableau ambigu)');
      continue;
    }

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
      '$entityCount entites, $refus refus -> $outPath');
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
