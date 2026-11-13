import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Tests des deux binaires de banc de P2-166 (`run_detecteur_isole.dart`,
/// `run_collage_fp.dart`) et des deux mesures ajoutées par P2-171
/// (`--equivalence`, `--cout`). Données synthétiques : le NIR 2 55 08 14 168 025 38
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

  group('équivalence avec et sans recollage (P2-171)', () {
    test('sans coupure : identique ; coupé : une traversée ; voisin : conservé',
        () async {
      final corpus = ecrit('g.jsonl', [
        {'id': 'entier', 'text': entier},
        {'id': 'coupe', 'text': coupe},
        // Un NIR complet en fin de ligne, la ligne suivante commence par un
        // nombre : la coupure existe, la détection d'origine doit rester.
        {'id': 'voisin', 'text': '$entier\n12 comprimés le matin.'},
      ]);
      final r = await lance('run_collage_fp.dart', ['--equivalence', corpus]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final sortie = '${r.stdout}';
      expect(sortie, contains('3 doc. ; sans coupure 1 doc., '));
      expect(sortie, contains('détections identiques 1, différentes 0'));
      expect(
          sortie,
          contains('avec coupure 2 doc. : détections d\'origine 1, '
              'conservées 1, remplacées 0, perdues 0'));
      expect(sortie, contains('1 traversant une coupure (nir 1), 0 hors'));
      expect(sortie, contains('Équivalence : aucune détection changée'));
    });

    test('aucune valeur du texte dans la sortie', () async {
      final corpus = ecrit('h.jsonl', [
        {'id': 'coupe', 'text': coupe},
      ]);
      final r = await lance('run_collage_fp.dart', ['--equivalence', corpus]);
      expect('${r.stdout}${r.stderr}', isNot(contains('168')));
      expect('${r.stdout}${r.stderr}', isNot(contains('025 38')));
    });

    test('refus explicite : fichier absent ou sans champ text', () async {
      final absent = await lance(
          'run_collage_fp.dart', ['--equivalence', '${tmp.path}/nope.md']);
      expect(absent.exitCode, 66);
      final predictions = ecrit('q.jsonl', [
        {'id': 'a', 'entities': <Object>[]},
      ]);
      final sans =
          await lance('run_collage_fp.dart', ['--equivalence', predictions]);
      expect(sans.exitCode, 65);
      expect('${sans.stderr}', contains('REFUS'));
    });

    test('voisinage (sans entrée) : rien de perdu, rien hors coupure',
        () async {
      final r = await lance('run_collage_fp.dart', ['--equivalence']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final total = '${r.stdout}'
          .split('\n')
          .firstWhere((l) => l.startsWith('TOTAL voisinage'));
      expect(total, contains('10000 tirages'));
      expect(total, contains('perdues 0 ;'));
      expect(total, contains(', 0 hors coupure'));
      // Chaque forme tire bien des identifiants que le détecteur trouve.
      expect(total, contains('détections d\'origine 23500, conservées 23500'));
    });
  });

  test('coût (P2-171) : une ligne par entrée et par taille, temps imprimés',
      () async {
    final r = await lance('run_collage_fp.dart', ['--cout', '--petit']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final lignes =
        '${r.stdout}'.split('\n').where((l) => l.startsWith('coût, ')).toList();
    expect(lignes, hasLength(15));
    for (final l in lignes) {
      expect(l, contains('recollage '));
      expect(l, contains('détection sur le texte recollé '));
      expect(l, isNot(contains('abandonné')));
    }
    // La page ordinaire contient des identifiants coupés : le recollage a
    // bien quelque chose à faire.
    expect(lignes.first, isNot(contains(' 0 coupures')));
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
