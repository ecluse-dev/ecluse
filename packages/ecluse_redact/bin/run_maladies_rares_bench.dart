import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';

/// Mesure du masquage des maladies rares (P2-143).
///
///     dart run bin/run_maladies_rares_bench.dart ../../bench/patho
///
/// Deux sources :
///
/// 1. le corpus de pathologies P2-112 (`corpus_pathologies_*.jsonl`) : les
///    mentions annotées « maladie rare » doivent être masquées, les
///    pathologies fréquentes et le témoin rester en clair ;
/// 2. un échantillon de noms Orphanet (nom préféré, tel qu'écrit) tirés du
///    catalogue (graine 42), placés
///    dans des phrases rattachées ou qui nomment une personne (à masquer),
///    niées et générales sans personne (à laisser),
///    pour mesurer la couverture au-delà des 51 mentions du corpus.
///
/// Sans catalogue (« avant »), rien n'est masqué par construction : la
/// colonne « avant » le vérifie au lieu de le supposer.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage : run_maladies_rares_bench <dossier bench/patho>');
    exit(64);
  }
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.rareDiseases.load();
  final cat = ref.rareDiseases;

  bool masquee(List<DetectedEntity> es, int s, int e) => es.any(
      (x) => x.type == EntityType.maladieRare && x.start <= s && x.end >= e);

  for (final nom in ['indices', 'variantes', 'formes_libres', 'temoin']) {
    final f = File('${args[0]}/corpus_pathologies_$nom.jsonl');
    if (!f.existsSync()) continue;
    var rares = 0, avant = 0, apres = 0, frequentes = 0, fp = 0;
    final faux = <String, int>{};
    for (final l in f.readAsLinesSync()) {
      if (l.trim().isEmpty) continue;
      final d = jsonDecode(l) as Map<String, dynamic>;
      final t = d['text'] as String;
      final sans = await Ecluse.detect(t);
      final avec = await Ecluse.detect(t, maladiesRares: cat);
      final gold = (d['pathologies'] as List).cast<Map<String, dynamic>>();
      final rareGold = <(int, int)>[];
      for (final p in gold) {
        final s = p['start'] as int, e = p['end'] as int;
        if (p['categorie'] == 'maladie rare') {
          rares++;
          rareGold.add((s, e));
          if (masquee(sans, s, e)) avant++;
          if (masquee(avec, s, e)) apres++;
        } else if (masquee(avec, s, e)) {
          frequentes++;
        }
      }
      for (final x in avec.where((x) => x.type == EntityType.maladieRare)) {
        if (!rareGold.any((g) => x.start <= g.$1 && x.end >= g.$2)) {
          fp++;
          faux[x.value] = (faux[x.value] ?? 0) + 1;
        }
      }
    }
    stdout.writeln('corpus $nom : maladies rares annotées $rares, masquées '
        'avant $avant, après $apres ; pathologies fréquentes masquées '
        '$frequentes ; masquages hors annotation $fp ${faux.isEmpty ? '' : faux}');
  }

  // Échantillon Orphanet : noms préférés, graine fixe.
  final rnd = Random(42);
  final noms = [
    for (final m in cat.mentions)
      if (m.length >= 8) m
  ]..sort();
  // Le nom Orphanet tel qu'écrit (casse et accents), pas la mention
  // normalisée en capitales : « THOMAS » en capitales passait pour un nom de
  // personne et faussait la mesure.
  final tirage = [
    for (var i = 0; i < 300; i++)
      cat.nameOf(cat.codesForMention(noms[rnd.nextInt(noms.length)]).first)!
  ];
  const rattachees = [
    'Mme Odile Verdier, atteinte de {m}, est suivie au service.',
    'M. Paul Girard est suivi pour {m} depuis 2015.',
    'Note au dossier. Mme Claire Benali, antécédents : {m}.',
    // Sans tournure, mais une personne est nommée (P2-143).
    'Mme Lucie Bernard, 52 ans. Diagnostic : {m}.',
  ];
  const nonRattachees = [
    'M. Paul Girard, pas de {m} connue dans la famille.',
    'Formation sur {m} proposée à toute l’équipe.',
  ];
  var r = 0, rm = 0, n = 0, nm = 0;
  final rates = <String>[];
  final fauxNeutres = <String>[];
  for (final (i, m) in tirage.indexed) {
    final phrase = rattachees[i % rattachees.length].replaceAll('{m}', m);
    final s = phrase.indexOf(m);
    final es = await Ecluse.detect(phrase, maladiesRares: cat);
    r++;
    if (masquee(es, s, s + m.length)) {
      rm++;
    } else if (rates.length < 15) {
      rates.add(m);
    }
    final neutre = nonRattachees[i % nonRattachees.length].replaceAll('{m}', m);
    final ns = neutre.indexOf(m);
    final en = await Ecluse.detect(neutre, maladiesRares: cat);
    n++;
    if (en.any((x) =>
        x.type == EntityType.maladieRare &&
        x.start < ns + m.length &&
        x.end > ns)) {
      nm++;
      if (fauxNeutres.length < 10) fauxNeutres.add(neutre);
    }
  }
  stdout.writeln('échantillon Orphanet (300 mentions, graine 42) : '
      'rattachées masquées $rm / $r ; niées ou générales masquées $nm / $n');
  if (rates.isNotEmpty) stdout.writeln('  exemples non masqués : $rates');
  if (fauxNeutres.isNotEmpty) {
    stdout.writeln('  masquées à tort : $fauxNeutres');
  }
}
