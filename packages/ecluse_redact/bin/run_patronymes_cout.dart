import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';

/// Coût de la liste de patronymes d'un dossier (P2-243, § 7.4 de
/// `agent/specs/P2-219.md`). Masque un corpus de dossiers avec une liste de
/// `--noms` noms **distincts** (synthétiques : « Aaa0001 »…, jamais présents
/// dans le corpus), `--repetitions` fois, un `Dossier` neuf par dossier du
/// corpus ; imprime la médiane et l'étendue du temps de la passe (ms) et la
/// mémoire résidente maximale du processus (Mio). **Chiffres de temps : non
/// déterministes**, donc hors de `bench/etat.sh` ; à rejouer à la main.
///
/// Chemin mesuré : `Ecluse.redact` (ce que reçoit le LLM).
///
/// Usage : dart run bin/run_patronymes_cout.dart --noms=1000 [--repetitions=3]
///   `<corpus_dossiers.jsonl>`
Future<void> main(List<String> arguments) async {
  var noms = 0;
  var repetitions = 3;
  final fichiers = <String>[];
  for (final a in arguments) {
    if (a.startsWith('--noms=')) {
      noms = int.parse(a.substring(7));
    } else if (a.startsWith('--repetitions=')) {
      repetitions = int.parse(a.substring(14));
    } else {
      fichiers.add(a);
    }
  }
  if (fichiers.length != 1) {
    stderr.writeln('Usage : dart run bin/run_patronymes_cout.dart --noms=N '
        '[--repetitions=3] <corpus.jsonl>');
    exitCode = 64;
    return;
  }
  final docs = <(Object?, String)>[];
  for (final ligne in File(fichiers.first).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final m = _json(ligne);
    docs.add((m['dossier'], m['text'] as String));
  }
  // Noms distincts, sans doublon à la normalisation (minuscules).
  final liste = [
    for (var i = 0; i < noms; i++) 'Zq${i.toRadixString(36).padLeft(5, 'a')}'
  ];
  final temps = <int>[];
  for (var r = 0; r < repetitions; r++) {
    final chrono = Stopwatch()..start();
    final dossiers = <Object?, Dossier>{};
    for (final (id, texte) in docs) {
      final d = dossiers.putIfAbsent(
          id, () => Dossier(patronymesConnus: PatronymesConnus(liste)));
      await Ecluse.redact(texte, dossier: d);
    }
    temps.add(chrono.elapsedMilliseconds);
    for (final d in dossiers.values) {
      d.fermer();
    }
  }
  temps.sort();
  stdout.writeln('noms=$noms documents=${docs.length} '
      'mediane_ms=${temps[temps.length ~/ 2]} min_ms=${temps.first} '
      'max_ms=${temps.last} '
      'rss_max_mio=${(ProcessInfo.maxRss / (1024 * 1024)).round()}');
}

Map<String, dynamic> _json(String ligne) =>
    jsonDecode(ligne) as Map<String, dynamic>;
