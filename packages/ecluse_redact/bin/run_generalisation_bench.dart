import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';

/// Mesure la généralisation appliquée (P2-93) sur un corpus de quasi-
/// identifiants (`bench/generate_corpus_qi.py`). Mesure seulement : rien n'est
/// corrigé.
///
/// Pour chaque document : `Ecluse.redact` avec référence, puis application de
/// la suggestion retenue (la première, P2-91) par `appliquerGeneralisations`
/// (P2-92), répétée jusqu'à ce qu'il n'y ait plus de suggestion (au plus 10
/// tours). On compte : documents avec suggestion, F et bande avant/après le
/// premier tour et à la fin, nombre de tours, refus ou exceptions, et trois
/// invariants (jetons et table inchangés, texte inchangé sans suggestion,
/// restauration exacte des entités masquées).
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
  var refus = 0;
  var tokensChanges = 0;
  var restaurationFausse = 0;
  var texteChangeSansSuggestion = 0;
  var fMonte = 0;
  var fNonMonte = 0;
  final statuts = <String, int>{};
  final bandes1 = <String, int>{};
  final bandesFin = <String, int>{};
  final tours = <int, int>{};
  final fAvant = <double>[];
  final fApres1 = <double>[];
  final fFin = <double>[];
  final raisonsArret = <String, int>{};

  for (final ligne in File(args[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final texte = (jsonDecode(ligne) as Map<String, dynamic>)['text'] as String;
    documents++;
    final base = await Ecluse.redact(texte, riskReference: ref);
    final st = base.risque!.evaluation.statut.name;
    statuts[st] = (statuts[st] ?? 0) + 1;

    if (base.risque!.suggestions.isEmpty) {
      // Rien à appliquer : le texte doit rester identique.
      final r = appliquerGeneralisations(base, const [], reference: ref);
      if (r.maskedText != base.maskedText) texteChangeSansSuggestion++;
      continue;
    }
    avecSuggestion++;
    final f0 = base.risque!.evaluation.estimate?.f;
    var cur = base;
    var n = 0;
    double? f1;
    String? bande1;
    try {
      while (cur.risque!.suggestions.isNotEmpty && n < 10) {
        final avant = cur.risque!.evaluation.estimate?.f;
        cur = appliquerGeneralisations(cur, [cur.risque!.suggestions.first],
            reference: ref);
        n++;
        final apres = cur.risque!.evaluation.estimate?.f;
        if (n == 1) {
          f1 = apres;
          bande1 = cur.risque!.evaluation.estimate?.band.name ??
              cur.risque!.evaluation.statut.name;
          if (avant != null && apres != null) {
            if (apres > avant) {
              fMonte++;
            } else {
              fNonMonte++;
            }
          }
        }
      }
      raisonsArret[n >= 10 ? 'plafond 10 tours' : 'plus de suggestion'] =
          (raisonsArret[n >= 10 ? 'plafond 10 tours' : 'plus de suggestion'] ??
                  0) +
              1;
    } on GeneralisationException {
      refus++;
      continue;
    }
    tours[n] = (tours[n] ?? 0) + 1;
    if (f0 != null) fAvant.add(f0);
    if (f1 != null) fApres1.add(f1);
    final ff = cur.risque!.evaluation.estimate?.f;
    if (ff != null) fFin.add(ff);
    bandes1[bande1 ?? '?'] = (bandes1[bande1 ?? '?'] ?? 0) + 1;
    final bf = cur.risque!.evaluation.estimate?.band.name ??
        cur.risque!.evaluation.statut.name;
    bandesFin[bf] = (bandesFin[bf] ?? 0) + 1;

    if (cur.mapping.toString() != base.mapping.toString() ||
        cur.entities.length != base.entities.length) {
      tokensChanges++;
    }
    final restaure = Ecluse.restore(cur.maskedText, cur.mapping);
    final restaureBase = Ecluse.restore(base.maskedText, base.mapping);
    // Les entités masquées doivent revenir à l'identique : on compare ce que
    // la restauration rend en dehors des zones généralisées via la table.
    final valeursOk = base.mapping.entries.every(
        (e) => restaure.contains(e.value) == restaureBase.contains(e.value));
    if (!valeursOk) restaurationFausse++;
  }

  String pct(int a, int b) =>
      b == 0 ? 'n/a' : '${(100 * a / b).toStringAsFixed(1)} %';
  String med(List<double> v) {
    if (v.isEmpty) return 'n/a';
    final s = [...v]..sort();
    return s[s.length ~/ 2].toStringAsFixed(1);
  }

  stdout.writeln('${args[0]} : $documents documents');
  stdout.writeln('  statut avant : ${_fmt(statuts)}');
  stdout.writeln('  documents avec suggestion : $avecSuggestion '
      '(${pct(avecSuggestion, documents)})');
  stdout.writeln('  refus ou exception à l\'application : $refus');
  stdout.writeln('  texte changé alors qu\'il n\'y avait rien à appliquer : '
      '$texteChangeSansSuggestion (attendu 0)');
  stdout.writeln('  table/entités changées par la généralisation : '
      '$tokensChanges (attendu 0)');
  stdout.writeln('  restauration des entités masquées altérée : '
      '$restaurationFausse (attendu 0)');
  stdout.writeln('  1er tour : F monte $fMonte, F ne monte pas $fNonMonte');
  stdout.writeln('  F médian : avant ${med(fAvant)}, après 1er tour '
      '${med(fApres1)}, à la fin ${med(fFin)}');
  stdout.writeln('  bande après 1er tour : ${_fmt(bandes1)}');
  stdout.writeln('  bande à la fin : ${_fmt(bandesFin)}');
  stdout.writeln('  tours : ${_fmt({
        for (final e in tours.entries) '${e.key}': e.value
      })}');
  stdout.writeln('  arrêt : ${_fmt(raisonsArret)}');
}

String _fmt(Map<String, int> m) =>
    (m.keys.toList()..sort()).map((k) => '$k=${m[k]}').join(', ');
