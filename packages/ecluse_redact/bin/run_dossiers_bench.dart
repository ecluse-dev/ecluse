import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';

/// Forme d'un jeton produit par `Ecluse.redact` : `[NOM_1]`, `[EMAIL_2]`…
final RegExp _jeton = RegExp(r'\[[A-Z_]+_\d+\]');

/// Associe chaque entité au jeton qui la remplace dans [masque].
///
/// Le texte masqué est le texte d'origine où chaque entité (triées, sans
/// chevauchement) est remplacée par un jeton : le jeton de l'entité i commence
/// à (position d'origine - décalage cumulé) dans le texte masqué, ce qui évite
/// de les retrouver par recherche (un jeton littéral du texte d'origine ne
/// peut pas être pris pour un jeton produit). Une entité dont le jeton n'est
/// pas retrouvé est omise : l'appelant compare les longueurs.
List<Map<String, dynamic>> mentionsAvecJeton(
  String masque,
  List<DetectedEntity> entites,
) {
  final sortie = <Map<String, dynamic>>[];
  var curseur = 0;
  var position = 0;
  for (final e in entites) {
    position += e.start - curseur;
    final m = _jeton.matchAsPrefix(masque, position);
    if (m != null) {
      position = m.end;
      sortie.add({
        'type': e.type.name,
        'start': e.start,
        'end': e.end,
        'jeton': m.group(0),
      });
    }
    curseur = e.end;
  }
  return sortie;
}

/// Mesure l'état actuel sur un corpus de dossiers
/// (`bench/generate_corpus_dossiers.py`) : chaque document est masqué
/// **séparément** par `Ecluse.redact`, puis restauré avec la table de ce
/// même appel. Aucun état n'est partagé entre les documents, c'est ce que
/// l'on veut mesurer.
///
/// Écrit une ligne par document, au format attendu par
/// `bench/score_dossiers.py` :
/// `{"id", "mentions": [{"type","start","end","jeton"}], "restaure": bool}`.
/// `restaure` vaut vrai quand le texte masqué puis restauré est identique à
/// l'original, octet pour octet.
///
/// Avec `--dossier` (P2-06), les documents d'un même dossier sont masqués avec
/// un même [Dossier] (clé `dossier` du corpus) et restaurés par ce dossier ;
/// sans, un appel par document, état d'avant.
///
/// Usage :
///   dart run bin/run_dossiers_bench.dart [--dossier] <corpus.jsonl> <sortie.jsonl>
Future<void> main(List<String> arguments) async {
  final avecDossier = arguments.contains('--dossier');
  final args = [
    for (final a in arguments)
      if (a != '--dossier') a
  ];
  if (args.length != 2) {
    stderr.writeln('Usage : dart run bin/run_dossiers_bench.dart [--dossier] '
        '<corpus.jsonl> <sortie.jsonl>');
    exitCode = 64;
    return;
  }
  final dossiers = <Object?, Dossier>{};
  final sink = File(args[1]).openWrite();
  var documents = 0;
  var mentions = 0;
  var nonRestaures = 0;
  var sansJeton = 0;

  for (final ligne in File(args[0]).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    final doc = jsonDecode(ligne) as Map<String, dynamic>;
    final texte = doc['text'] as String;

    final dossier =
        avecDossier ? dossiers.putIfAbsent(doc['dossier'], Dossier.new) : null;
    final resultat = await Ecluse.redact(texte, dossier: dossier);
    final restaure = dossier != null
        ? dossier.restore(resultat.maskedText)
        : Ecluse.restore(resultat.maskedText, resultat.mapping);
    final identique = restaure == texte;
    if (!identique) nonRestaures++;

    final sortie = mentionsAvecJeton(resultat.maskedText, resultat.entities);
    if (sortie.length != resultat.entities.length) {
      sansJeton += resultat.entities.length - sortie.length;
      stderr.writeln('ALERTE : jeton introuvable (document ${doc['id']})');
    }
    sink.writeln(jsonEncode(
        {'id': doc['id'], 'mentions': sortie, 'restaure': identique}));
    documents++;
    mentions += sortie.length;
  }

  await sink.flush();
  await sink.close();
  stdout.writeln(
      'Ecluse redact (${avecDossier ? 'avec dossier' : 'un appel par document'}) : $documents '
      'documents, $mentions mentions -> ${args[1]}');
  if (nonRestaures > 0) {
    stdout.writeln('  restaurations non identiques : $nonRestaures');
  }
  if (sansJeton > 0) {
    stderr.writeln('ATTENTION : $sansJeton entité(s) sans jeton retrouvé ; '
        'mesure à ne pas interpréter.');
    exitCode = 1;
  }
}
