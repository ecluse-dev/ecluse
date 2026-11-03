import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';

/// Mesure l'effet de `appliquerGeneralisations` (P2-92) sur un corpus de
/// quasi-identifiants (`bench/generate_corpus_qi.py`), avant et après.
///
/// Mesure seulement : rien n'est corrigé. Deux politiques d'appelant :
///   - `retenue` : seule la première suggestion (candidat retenu) ;
///   - `toutes`  : toutes les suggestions proposées.
///
/// Par politique : bande et F avant/après, refus (`GeneralisationException`),
/// et QI annotés dont le texte d'origine reste en clair après application.
/// Le corpus de QI ne contient pas d'entité masquée : le texte masqué est
/// quasi identique au texte d'origine, ce qui rend la comparaison lisible.
///
/// Usage (depuis `packages/ecluse_redact`) :
///   dart run bin/run_generalisation_bench.dart <corpus_qi.jsonl>
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
        'Usage : dart run bin/run_generalisation_bench.dart <corpus.jsonl>');
    exitCode = 64;
    return;
  }
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.preload();

  var documents = 0;
  var avecSuggestion = 0;
  final avantBande = <String, int>{};
  final avantStatut = <String, int>{};
  final politiques = {
    'retenue': _Stats(),
    'toutes': _Stats(),
  };

  for (final ligne in File(args[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    final texte = doc['text'] as String;
    final golds = [
      for (final e in (doc['entities'] as List).cast<Map<String, dynamic>>())
        (
          e['type'] as String,
          texte.substring(e['start'] as int, e['end'] as int)
        ),
    ];
    documents++;

    final base = await Ecluse.redact(texte, riskReference: ref);
    final rapport = base.risque!;
    final statut = rapport.evaluation.statut.name;
    avantStatut[statut] = (avantStatut[statut] ?? 0) + 1;
    final est = rapport.evaluation.estimate;
    if (est != null) {
      avantBande[est.band.name] = (avantBande[est.band.name] ?? 0) + 1;
    }
    if (rapport.suggestions.isEmpty) continue;
    avecSuggestion++;

    for (final entree in politiques.entries) {
      final choisies = entree.key == 'retenue'
          ? [rapport.suggestions.first]
          : rapport.suggestions;
      final s = entree.value;
      s.documents++;
      s.golds += golds.length;
      s.fAvant += est!.f;
      s.bandeAvant[est.band.name] = (s.bandeAvant[est.band.name] ?? 0) + 1;
      try {
        final apres = appliquerGeneralisations(base, choisies, reference: ref);
        final t = apres.maskedText;
        if (t == base.maskedText) s.inchange++;
        for (final (type, extrait) in golds) {
          if (t.contains(extrait)) {
            s.enClair++;
            s.enClairParType[type] = (s.enClairParType[type] ?? 0) + 1;
          }
        }
        final e2 = apres.risque!.evaluation;
        final st = e2.statut.name;
        s.statutApres[st] = (s.statutApres[st] ?? 0) + 1;
        final est2 = e2.estimate;
        if (est2 != null) {
          s.fApres += est2.f;
          s.evaluesApres++;
          s.bandeApres[est2.band.name] =
              (s.bandeApres[est2.band.name] ?? 0) + 1;
          if (est2.f > est.f) s.fMonte++;
          if (est2.f < est.f) s.fBaisse++;
        }
        // Le texte restauré garde les entités masquées exactes.
        final restaure = Ecluse.restore(t, apres.mapping);
        if (restaure.contains('[')) s.crochetsRestants++;
      } on GeneralisationException {
        s.refus++;
      }
    }
  }

  stdout.writeln('${args[0]} : $documents documents');
  stdout.writeln('  statut avant : ${_fmt(avantStatut)}');
  stdout.writeln('  bande avant (évalués) : ${_fmt(avantBande)}');
  stdout.writeln('  documents avec suggestion : $avecSuggestion');
  for (final e in politiques.entries) {
    final s = e.value;
    stdout.writeln('  politique « ${e.key} » (${s.documents} documents) :');
    if (s.documents == 0) continue;
    stdout.writeln('    refus : ${s.refus}, texte inchangé : ${s.inchange}');
    stdout.writeln('    bande avant : ${_fmt(s.bandeAvant)}');
    stdout.writeln('    bande après : ${_fmt(s.bandeApres)} '
        '(évalués après : ${s.evaluesApres})');
    stdout.writeln('    statut après : ${_fmt(s.statutApres)}');
    stdout.writeln('    F moyen avant : ${(s.fAvant / s.documents).round()}, '
        'après : ${s.evaluesApres == 0 ? "n/a" : (s.fApres / s.evaluesApres).round()}');
    stdout.writeln('    F monte : ${s.fMonte}, F baisse : ${s.fBaisse}');
    stdout.writeln('    QI annotés : ${s.golds}, encore en clair après : '
        '${s.enClair}');
    stdout.writeln('    encore en clair, par type : '
        '${_fmt(s.enClairParType)}');
    stdout.writeln('    restauration avec « [ » résiduel : '
        '${s.crochetsRestants}');
  }
}

String _fmt(Map<String, int> m) => m.isEmpty
    ? '-'
    : (m.keys.toList()..sort()).map((k) => '$k=${m[k]}').join(', ');

class _Stats {
  int documents = 0;
  int refus = 0;
  int inchange = 0;
  int golds = 0;
  int enClair = 0;
  int evaluesApres = 0;
  int fMonte = 0;
  int fBaisse = 0;
  int crochetsRestants = 0;
  double fAvant = 0;
  double fApres = 0;
  final bandeAvant = <String, int>{};
  final bandeApres = <String, int>{};
  final statutApres = <String, int>{};
  final enClairParType = <String, int>{};
}
