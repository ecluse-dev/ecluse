import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// Mesure le branchement de `ecluse_reid` dans `Ecluse.redact` (P2-04) sur un
/// corpus de quasi-identifiants (`bench/generate_corpus_qi.py`).
///
/// Pour chaque document : le texte masqué est-il identique avec et sans
/// référence (il doit l'être), quel statut donne le rapport sur le **texte
/// masqué**, et quel statut aurait donné l'évaluation du texte d'origine. Le
/// croisement montre ce que le masquage des autres détecteurs retire au
/// rapport.
///
/// Usage (depuis `packages/ecluse_redact`) :
///   dart run bin/run_risque_bench.dart <corpus_qi.jsonl>
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage : dart run bin/run_risque_bench.dart <corpus.jsonl>');
    exitCode = 64;
    return;
  }
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.preload();

  var documents = 0;
  var texteDifferent = 0;
  var statutDifferent = 0;
  final parStatut = <String, int>{};
  final croise = <String, int>{};
  final chrono = Stopwatch();
  var tempsAvec = 0;
  var tempsSans = 0;

  for (final ligne in File(args[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final texte = (jsonDecode(ligne) as Map<String, dynamic>)['text'] as String;
    documents++;

    chrono
      ..reset()
      ..start();
    final sans = await Ecluse.redact(texte);
    tempsSans += chrono.elapsedMicroseconds;
    chrono
      ..reset()
      ..start();
    final avec = await Ecluse.redact(texte, riskReference: ref);
    tempsAvec += chrono.elapsedMicroseconds;

    if (avec.maskedText != sans.maskedText) texteDifferent++;
    final masque = avec.risque!.evaluation.statut.name;
    final origine = evaluateText(ref, texte).statut.name;
    parStatut[masque] = (parStatut[masque] ?? 0) + 1;
    if (masque != origine) statutDifferent++;
    final cle = '$origine -> $masque';
    croise[cle] = (croise[cle] ?? 0) + 1;
  }

  stdout.writeln('${args[0]} : $documents documents');
  stdout.writeln('  texte masqué différent avec référence : $texteDifferent '
      '(attendu : 0)');
  stdout.writeln('  statut du rapport (texte masqué) :');
  for (final k in parStatut.keys.toList()..sort()) {
    stdout.writeln('    ${k.padRight(14)} ${parStatut[k]}');
  }
  stdout.writeln('  statut changé par le masquage : $statutDifferent');
  for (final k in croise.keys.toList()..sort()) {
    stdout.writeln('    texte d\'origine -> texte masqué  ${k.padRight(34)} '
        '${croise[k]}');
  }
  stdout.writeln('  temps moyen par document : sans '
      '${(tempsSans / documents).round()} µs, avec '
      '${(tempsAvec / documents).round()} µs');
}
