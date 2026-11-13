import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Tests des deux binaires de banc de P2-166 (`run_detecteur_isole.dart`,
/// `run_collage_fp.dart`). Données synthétiques : le NIR 2 55 08 14 168 025 38
/// est calculé (clé 97 − 2550814168025 mod 97 = 38), jamais copié d'une
/// source réelle. Un banc qui se tromperait de chemin donnerait un chiffre
/// faux sans que personne le voie : ces tests fixent ce que chaque banc doit
/// compter.
void main() {
  late Directory tmp;
  setUpAll(() => tmp = Directory.systemTemp.createTempSync('bancs_p2_166_'));
  tearDownAll(() => tmp.deleteSync(recursive: true));

  String ecrit(String nom, List<Map<String, Object?>> docs) {
    final f = File('${tmp.path}/$nom');
    f.writeAsStringSync('${docs.map(jsonEncode).join('\n')}\n');
    return f.path;
  }

  Future<ProcessResult> lance(String binaire, List<String> args) => Process.run(
      Platform.resolvedExecutable, ['run', 'bin/$binaire', ...args]);

  const entier = 'NIR 2 55 08 14 168 025 38 du patient.';
  const coupe = 'NIR 2 55 08 14 168\n025 38 du patient.';

  test('détecteur isolé : trouve le NIR entier, rate le NIR coupé', () async {
    final corpus = ecrit('c.jsonl', [
      {'id': 'a', 'text': entier},
      {'id': 'b', 'text': coupe},
    ]);
    final sortie = '${tmp.path}/s.jsonl';
    final r = await lance('run_detecteur_isole.dart', [corpus, sortie]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final lignes = File(sortie)
        .readAsLinesSync()
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .toList();
    expect([
      for (final e in lignes[0]['entities'] as List)
        (e as Map<String, dynamic>)['type']
    ], [
      'nir'
    ]);
    expect(lignes[1]['entities'], isEmpty,
        reason: 'aucun détecteur isolé ne franchit une fin de ligne');
  });

  test('collage : compte la traversée comme attendue si annotée', () async {
    final corpus = ecrit('d.jsonl', [
      {
        'id': 'b',
        'text': coupe,
        'entities': [
          {'type': 'nir', 'start': 4, 'end': coupe.indexOf(' du')}
        ],
      },
    ]);
    final r = await lance('run_collage_fp.dart', [corpus]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final sortie = '${r.stdout}';
    expect(sortie, contains('1 coupures'));
    expect(sortie, contains('1 attendues + 0 à tort'));
    expect(sortie, contains('Contrôle : 0 détection(s)'));
  });

  test('collage : la même traversée sans annotation est comptée à tort',
      () async {
    final corpus = ecrit('e.jsonl', [
      {'id': 'b', 'text': coupe, 'entities': <Object>[]},
    ]);
    final r = await lance('run_collage_fp.dart', [corpus]);
    expect('${r.stdout}', contains('0 attendues + 1 à tort'));
  });

  test('collage : contre-exemples du § 5.3 et colonnes, rien à tort', () async {
    final corpus = ecrit('f.jsonl', [
      {'id': 'salle', 'text': 'En salle 4\nA2 fermée.'},
      {'id': 'vol', 'text': 'Vol 12\nB7 porte ouverte.'},
      {
        'id': 'col',
        'text': '123456789\n234567891\n345678912\n',
      },
    ]);
    final r = await lance('run_collage_fp.dart', [corpus]);
    final sortie = '${r.stdout}';
    expect(sortie, contains('0 attendues + 0 à tort'));
    expect(sortie, contains('1 colonnes de 9/11/13 chiffres'));
  });

  test('refus explicite : fichier absent ou sans champ text', () async {
    final absent = await lance('run_collage_fp.dart', ['${tmp.path}/nope.md']);
    expect(absent.exitCode, 66);
    expect('${absent.stderr}', contains('REFUS'));
    final predictions = ecrit('p.jsonl', [
      {'id': 'a', 'entities': <Object>[]},
    ]);
    final sans = await lance('run_collage_fp.dart', [predictions]);
    expect(sans.exitCode, 65);
    expect('${sans.stderr}', contains('REFUS'));
  });
}
