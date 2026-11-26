import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// P2-297 (mesure) : par quel type d'entité chaque établissement annoté est
/// couvert, par `Ecluse.redact` (chemin du produit : ce que reçoit le LLM), et
/// ce que cela change pour la restauration et pour le rapport de risque.
///
/// Usage (depuis `packages/ecluse_redact`) :
///   dart run bin/run_etablissement_types.dart [--sans=PREFIXES] `<ETIQUETTE>`
///       `<corpus.jsonl>` `[<corpus_ordinaire.jsonl>]`
///
/// Le corpus est annoté (`entities` avec `type` = `etablissement`). Le second
/// corpus, facultatif, est la même série dans sa casse d'origine (mêmes `id`) :
/// il sert à comparer le rapport de risque (statut et F) document par document.
///
/// Seuls des **nombres** sont imprimés : jamais le texte d'un document, ni une
/// valeur détectée (règle de CLAUDE.md sur les sorties console).
Future<void> main(List<String> argv) async {
  // `--sans=nom,etablissement` : retire de `Ecluse.defaultDetectors` ceux dont
  // le nom commence par l'un de ces préfixes (ablation : ce qui part en clair
  // quand un type de détecteur manque).
  final sans = [
    for (final a in argv)
      if (a.startsWith('--sans=')) ...a.substring(7).split(',')
  ];
  final args = [
    for (final a in argv)
      if (!a.startsWith('--sans=')) a
  ];
  final detecteurs = sans.isEmpty
      ? null
      : [
          for (final d in Ecluse.defaultDetectors)
            if (!sans.any(d.name.startsWith)) d
        ];
  if (args.length < 2 || args.length > 3) {
    stderr.writeln('Usage : dart run bin/run_etablissement_types.dart '
        '<ETIQUETTE> <corpus.jsonl> [<corpus_ordinaire.jsonl>]');
    exitCode = 64;
    return;
  }
  final etiquette = args[0];
  final docs = _lit(args[1]);
  final ordinaires = args.length == 3 ? _lit(args[2]) : null;
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.preload();

  var annotes = 0;
  var couverts = 0;
  var couvertsSansEtab = 0;
  var sansEtabBornesExactes = 0;
  var sansEtabDebord = 0; // couverts par une entité plus large que l'annotation
  var debordCaracteres = 0;
  var partiels = 0;
  var rien = 0;
  // Restauration différente de l'original : attendue quand une même personne
  // est citée sous plusieurs formes (le jeton rend la forme la plus complète,
  // LIMITES.md § 5.3), pas un défaut en soi.
  var restaurationKo = 0;
  var refus = 0;
  final parCombinaison = <String, int>{};
  final seul = <String, int>{};
  var docsSansEtab = 0;
  // Rapport de risque : statut et F du texte masqué, capitales contre casse
  // d'origine, en séparant les documents dont un établissement est couvert sans
  // type `etablissement` des autres (le groupe témoin dit ce que la casse change
  // à elle seule).
  final croise = <String, int>{};
  final fDifferent = <String, int>{};
  // Le rapport lit-il le nom du jeton ? Même texte masqué, jetons de personne
  // renommés en jetons d'établissement : statut ou F différents ?
  var jetonLuParLeRapport = 0;

  for (final d in docs) {
    final text = d['text'] as String;
    final RedactResult r;
    try {
      r = await Ecluse.redact(text, riskReference: ref, detectors: detecteurs);
    } on TableauAmbiguException {
      refus++;
      continue;
    }
    if (Ecluse.restore(r.maskedText, r.mapping) != text) restaurationKo++;
    final annotations = [
      for (final e in (d['entities'] as List))
        if ((e as Map)['type'] == 'etablissement')
          (start: e['start'] as int, end: e['end'] as int)
    ];
    var docSansEtab = false;
    for (final a in annotations) {
      annotes++;
      final qui = r.entities
          .where((e) => e.start < a.end && a.start < e.end)
          .toList()
        ..sort((x, y) => x.start.compareTo(y.start));
      if (qui.isEmpty) {
        rien++;
        continue;
      }
      var pos = a.start;
      for (final e in qui) {
        if (e.start > pos) break;
        if (e.end > pos) pos = e.end;
      }
      if (pos < a.end) {
        partiels++;
        continue;
      }
      couverts++;
      final types = {for (final e in qui) e.type.name}.toList()..sort();
      final cle = types.join('+');
      parCombinaison[cle] = (parCombinaison[cle] ?? 0) + 1;
      if (types.length == 1) seul[cle] = (seul[cle] ?? 0) + 1;
      if (!types.contains('etablissement')) {
        couvertsSansEtab++;
        docSansEtab = true;
        final debut = qui.map((e) => e.start).reduce((x, y) => x < y ? x : y);
        final fin = qui.map((e) => e.end).reduce((x, y) => x > y ? x : y);
        if (debut == a.start && fin == a.end) {
          sansEtabBornesExactes++;
        } else {
          sansEtabDebord++;
          debordCaracteres += (a.start - debut) + (fin - a.end);
        }
      }
    }
    if (docSansEtab) {
      docsSansEtab++;
      final a = evaluateText(ref, r.maskedText);
      final b = evaluateText(
          ref, r.maskedText.replaceAll('[NOM_', '[ETABLISSEMENT_'));
      if (a.statut != b.statut || a.estimate?.f != b.estimate?.f) {
        jetonLuParLeRapport++;
      }
    }
    if (ordinaires != null) {
      final o = ordinaires.firstWhere((x) => x['id'] == d['id']);
      final ro = await Ecluse.redact(o['text'] as String, riskReference: ref);
      final sm = r.risque!.evaluation;
      final so = ro.risque!.evaluation;
      final groupe =
          docSansEtab ? 'sans type etablissement' : 'type etablissement';
      final cle = '$groupe : ${so.statut.name} -> ${sm.statut.name}';
      croise[cle] = (croise[cle] ?? 0) + 1;
      if ((sm.estimate?.f) != (so.estimate?.f)) {
        fDifferent[groupe] = (fDifferent[groupe] ?? 0) + 1;
      }
    }
  }

  stdout.writeln(
      '## $etiquette${sans.isEmpty ? "" : ", sans ${sans.join("+")}"} : '
      '${docs.length} documents, $refus refusés');
  stdout.writeln('  établissements annotés : $annotes');
  stdout.writeln('  couverts en entier : $couverts '
      '(dont sans entité etablissement : $couvertsSansEtab)');
  stdout.writeln('    dont bornes exactes : $sansEtabBornesExactes ; '
      'entité plus large que l\'annotation : $sansEtabDebord '
      '($debordCaracteres caractères de plus au total)');
  stdout.writeln('  couverts en partie : $partiels ; en clair : $rien');
  stdout.writeln('  documents avec un établissement couvert sans type '
      'etablissement : $docsSansEtab');
  for (final k in parCombinaison.keys.toList()..sort()) {
    stdout.writeln('  types couvrants ${k.padRight(34)} ${parCombinaison[k]}'
        '${seul.containsKey(k) ? " (ce seul type)" : ""}');
  }
  stdout.writeln(
      '  rapport de risque lisant le nom du jeton (NOM -> ETABLISSEMENT) : '
      '$jetonLuParLeRapport document(s) sur $docsSansEtab');
  stdout.writeln('  restauration différente de l\'original : $restaurationKo');
  if (ordinaires != null) {
    stdout.writeln("  rapport de risque (texte masqué), casse d'origine -> "
        'capitales, par groupe de documents :');
    for (final k in croise.keys.toList()..sort()) {
      stdout.writeln('    statut ${k.padRight(34)} ${croise[k]}');
    }
    for (final k in fDifferent.keys.toList()..sort()) {
      stdout.writeln('    F différent, ${k.padRight(24)} ${fDifferent[k]}');
    }
  }
}

List<Map<String, dynamic>> _lit(String chemin) => [
      for (final l in File(chemin).readAsLinesSync())
        if (l.trim().isNotEmpty) jsonDecode(l) as Map<String, dynamic>
    ];
