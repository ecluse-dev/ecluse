import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';

/// Appelle **directement** `NirDetector`, `RppsDetector`, `IbanFrDetector` et
/// `FinessDetector` sur un corpus JSONL, sans `EcluseEngine` ni
/// `ecluse_redact`, et écrit les prédictions au format de
/// `bin/run_redact_bench.dart` (lisible par `bench/rappel_structurel.py`).
///
/// Pourquoi (P2-166) : c'est l'exemple du README d'`ecluse_core` (un
/// détecteur appelé seul). Le tableau de bord mesurait le moteur seul et
/// `Ecluse.redact`, jamais cet appel : on ne savait pas ce qu'il laisse
/// passer quand une fin de ligne coupe un identifiant. Chemin mesuré ici :
/// **détecteur isolé**, ni le moteur, ni le chemin du produit
/// (`Ecluse.redact`, seul chemin que reçoit le LLM).
///
/// Les quatre détecteurs sont lancés l'un après l'autre sur le même texte ;
/// leurs sorties sont simplement concaténées, sans résolution de
/// chevauchements (un détecteur isolé n'en fait pas).
///
/// Usage : dart run ecluse_bench:run_detecteur_isole <corpus.jsonl> <sortie.jsonl>
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage : run_detecteur_isole <corpus.jsonl> <sortie.jsonl>');
    exit(64);
  }
  final detecteurs = <String, Future<List<DetectedEntity>> Function(String)>{
    'nir': (t) async => const NirDetector().detect(t),
    'rpps': (t) async => const RppsDetector().detect(t),
    'iban': (t) async => const IbanFrDetector().detect(t),
    'finess': (t) => const FinessDetector().detect(NormalizedText.identity(t)),
  };

  final sink = File(args[1]).openWrite();
  var documents = 0;
  var total = 0;
  for (final ligne in File(args[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    final texte = doc['text'] as String;
    final entites = <Map<String, Object>>[];
    for (final d in detecteurs.entries) {
      for (final e in await d.value(texte)) {
        entites.add({'type': d.key, 'start': e.start, 'end': e.end});
      }
    }
    sink.writeln(jsonEncode({'id': doc['id'], 'entities': entites}));
    documents++;
    total += entites.length;
  }
  await sink.flush();
  await sink.close();
  stdout.writeln(
      'Détecteurs isolés : $documents documents, $total entités -> ${args[1]}');
}
