import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';

/// Témoin « nombres à cinq chiffres » (P2-167) : compte les adresses prédites
/// sur un corpus sans aucune adresse (`bench/generate_corpus_cinq_chiffres.py`).
///
/// Trois chemins, à ne pas confondre :
/// - **`Ecluse.redact`** : ce que reçoit le LLM (seul chemin dont le chiffre
///   dit ce qui part en clair ou masqué) ;
/// - `AdresseDetector` seul : la voie « casse ordinaire » ;
/// - `MinusculesRecapitaliseDetector(AdresseDetector, communesSeules)` : la voie
///   « texte d'ombre » des textes sans majuscule hors début de phrase.
/// Les deux derniers servent seulement à dire quelle règle produit une
/// prédiction ; ils ne mesurent pas le produit.
///
/// Aucune valeur du texte n'est imprimée : seulement des comptes par axe.
///
/// Usage : dart run bin/run_cinq_chiffres_bench.dart <corpus.jsonl>
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage : run_cinq_chiffres_bench <corpus.jsonl>');
    exit(64);
  }
  final direct = AdresseDetector();
  const ombre = MinusculesRecapitaliseDetector(
    AdresseDetector(),
    communesSeules: true,
  );
  var docs = 0, redact = 0, seulDirect = 0, seulOmbre = 0, lesDeux = 0;
  final parAxe = <String, List<int>>{}; // axe -> [documents, faux positifs]
  for (final ligne in File(args[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final d = jsonDecode(ligne) as Map<String, dynamic>;
    final texte = d['text'] as String;
    docs++;
    final r = await Ecluse.redact(texte);
    final fp = r.entities.where((e) => e.type == EntityType.adresse).length;
    final aDirect = direct.detect(texte).isNotEmpty;
    final aOmbre = ombre.detect(texte).isNotEmpty;
    if (fp > 0) {
      redact += fp;
      if (aDirect && aOmbre) {
        lesDeux++;
      } else if (aDirect) {
        seulDirect++;
      } else if (aOmbre) {
        seulOmbre++;
      }
    }
    for (final axe in ['famille', 'suffixe', 'position', 'casse']) {
      final cle = '$axe=${d[axe]}';
      final c = parAxe.putIfAbsent(cle, () => [0, 0]);
      c[0]++;
      if (fp > 0) c[1]++;
    }
  }
  stdout.writeln('témoin cinq chiffres : $docs phrases, $redact prédiction(s) '
      'd\'adresse par Ecluse.redact (chemin du produit)');
  stdout.writeln('  voie : détecteur seul $seulDirect, texte d\'ombre '
      '$seulOmbre, les deux $lesDeux (phrases avec prédiction)');
  for (final cle in parAxe.keys.toList()..sort()) {
    final c = parAxe[cle]!;
    stdout.writeln('  $cle : ${c[1]} / ${c[0]} phrases avec une adresse');
  }
}
