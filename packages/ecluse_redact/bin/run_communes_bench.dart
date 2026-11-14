import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';

/// Option `communes` de `Ecluse.redact` (P2-184) : ce qu'elle retire et ce
/// qu'elle fait perdre, corpus par corpus.
///
/// Chaque document passe deux fois par **`Ecluse.redact`** (ce que reçoit le
/// LLM), sans puis avec l'option. Par corpus :
///
/// - adresses prédites sans et avec l'option (sur un témoin sans adresse,
///   chaque prédiction est un faux positif) ;
/// - adresses annotées **perdues** : entièrement couvertes sans l'option, en
///   partie en clair avec (les blancs ne comptent pas) ;
/// - documents dont les entités changent.
///
/// `--temps` ajoute le temps de chargement de la table et le temps total des
/// deux passes (non reproductible : hors tableau de bord).
///
/// Aucune valeur du texte n'est imprimée : seulement des comptes.
///
/// Usage : dart run bin/run_communes_bench.dart [--temps] étiquette=corpus.jsonl…
Future<void> main(List<String> argv) async {
  final temps = argv.contains('--temps');
  final args = [
    for (final a in argv)
      if (a != '--temps') a
  ];
  if (args.isEmpty || args.any((a) => !a.contains('='))) {
    stderr.writeln('Usage : run_communes_bench [--temps] '
        'étiquette=corpus.jsonl [étiquette=corpus.jsonl…]');
    exit(64);
  }
  final geo =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets')).geo;
  final chargement = Stopwatch()..start();
  await geo.load();
  chargement.stop();
  final communes = CommunesConnues(geo);
  if (temps) {
    stdout.writeln('option communes, chargement de la table : '
        '${chargement.elapsedMilliseconds} ms');
  }

  for (final arg in args) {
    final i = arg.indexOf('=');
    final etiquette = arg.substring(0, i);
    var docs = 0, sans = 0, avec = 0, annotees = 0, perdues = 0, changes = 0;
    var refus = 0;
    final tSans = Stopwatch(), tAvec = Stopwatch();
    for (final ligne in File(arg.substring(i + 1)).readAsLinesSync()) {
      if (ligne.trim().isEmpty) continue;
      final d = jsonDecode(ligne) as Map<String, dynamic>;
      final texte = d['text'] as String;
      final RedactResult a, b;
      try {
        tSans.start();
        a = await Ecluse.redact(texte);
        tSans.stop();
        tAvec.start();
        b = await Ecluse.redact(texte, communes: communes);
        tAvec.stop();
      } on TableauAmbiguException {
        // Refus explicite (règle 4) : rien n'est envoyé. Compté à part.
        tSans.stop();
        tAvec.stop();
        refus++;
        continue;
      }
      docs++;
      sans += a.entities.where((e) => e.type == EntityType.adresse).length;
      avec += b.entities.where((e) => e.type == EntityType.adresse).length;
      if (!_memesEntites(a.entities, b.entities)) changes++;
      for (final e in (d['entities'] as List).cast<Map<String, dynamic>>()) {
        if (e['type'] != 'adresse') continue;
        annotees++;
        final debut = e['start'] as int, fin = e['end'] as int;
        if (_couverte(texte, debut, fin, a.entities) &&
            !_couverte(texte, debut, fin, b.entities)) {
          perdues++;
        }
      }
    }
    stdout.writeln('option communes, $etiquette : $docs documents, adresses '
        'prédites $sans sans l\'option, $avec avec ; $annotees annotée(s), '
        '$perdues perdue(s) avec l\'option ; $changes document(s) changé(s), '
        '$refus refus (Ecluse.redact)');
    if (temps) {
      stdout.writeln('  temps des $docs documents : '
          '${tSans.elapsedMilliseconds} ms sans, '
          '${tAvec.elapsedMilliseconds} ms avec');
    }
  }
}

bool _memesEntites(List<DetectedEntity> a, List<DetectedEntity> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].type != b[i].type ||
        a[i].start != b[i].start ||
        a[i].end != b[i].end) {
      return false;
    }
  }
  return true;
}

final RegExp _blanc = RegExp(r'\s');

/// Vrai si chaque caractère hors blancs de `[debut, fin)` est sous une
/// détection, quel qu'en soit le type.
bool _couverte(
    String texte, int debut, int fin, Iterable<DetectedEntity> entites) {
  for (var p = debut; p < fin; p++) {
    if (_blanc.hasMatch(texte[p])) continue;
    if (!entites.any((e) => e.start <= p && p < e.end)) return false;
  }
  return true;
}
