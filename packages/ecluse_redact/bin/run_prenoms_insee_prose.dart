import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart' show DetectedEntity, EntityType;
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';

/// Faux positifs de l'option `prenomsInsee` sur de la prose (P2-149).
///
/// Les corpus synthétiques ont un vocabulaire limité : leurs témoins ne
/// contiennent presque aucun mot courant qui soit aussi au fichier des
/// prénoms. Ce script lit des fichiers texte quelconques (par exemple les
/// `.md` du dépôt, du français réel qui ne nomme presque personne), compare
/// les noms détectés avec et sans l'option et imprime chaque **nouvelle**
/// détection, pour une relecture à la main. Rien n'est écrit sur disque.
///
/// Usage :
///   dart run bin/run_prenoms_insee_prose.dart [--seuil=N] <fichier>...
Future<void> main(List<String> argv) async {
  final effectifs =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'))
          .firstNameFrequencies;
  await effectifs.load();
  final seuils = argv.where((a) => a.startsWith('--seuil='));
  final args = [
    for (final a in argv)
      if (!a.startsWith('--seuil=')) a
  ];
  final gazetteer = PrenomsInsee(effectifs,
      seuil: seuils.isEmpty
          ? PrenomsInsee.seuilParDefaut
          : int.parse(seuils.last.split('=')[1]));
  var total = 0;
  final parPrenom = <String, int>{};
  for (final chemin in args) {
    final texte = File(chemin).readAsStringSync();
    final Set<(int, int)> sans;
    final List<DetectedEntity> avec;
    try {
      sans = {
        for (final e in await Ecluse.detect(texte))
          if (e.type == EntityType.nom) (e.start, e.end),
      };
      avec = await Ecluse.detect(texte, prenomsInsee: gazetteer);
    } on Exception catch (e) {
      // Un refus (tableau ambigu…) est un refus, pas un faux positif.
      stderr.writeln('$chemin : refusé (${e.runtimeType})');
      continue;
    }
    for (final e in avec) {
      if (e.type != EntityType.nom || sans.contains((e.start, e.end))) continue;
      total++;
      final premier = e.value.split(RegExp(r'\s+')).first;
      parPrenom[premier] = (parPrenom[premier] ?? 0) + 1;
      stdout.writeln('$chemin\t${e.value}');
    }
  }
  stdout.writeln('TOTAL nouvelles détections : $total');
  final tri = parPrenom.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('par premier mot : '
      '${tri.map((e) => '${e.key} ${e.value}').join(', ')}');
}
