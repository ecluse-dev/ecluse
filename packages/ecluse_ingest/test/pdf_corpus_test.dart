import 'dart:convert';
import 'dart:io';

import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:test/test.dart';

/// Rejoue le jeu synthétique de `bench/pdf/` (généré par
/// `bench/generate_pdfs.py`, graine 42) et vérifie, pour chaque fichier, le
/// résultat attendu : accepté, accepté avec avertissement, ou refusé avec le
/// motif prévu. Pour les PDF acceptés, les identifiants fabriqués doivent
/// figurer dans le texte extrait.
void main() {
  final dir = Directory('../../bench/pdf');
  final expected =
      jsonDecode(File('${dir.path}/expected.json').readAsStringSync())
          as Map<String, dynamic>;
  final files = expected['fichiers'] as Map<String, dynamic>;

  for (final entry in files.entries) {
    final name = entry.key;
    final spec = entry.value as Map<String, dynamic>;
    test('$name — ${spec['attendu']}', () {
      final bytes = File('${dir.path}/$name').readAsBytesSync();
      final result = ingestFile(bytes, filename: name);

      switch (spec['attendu']) {
        case 'refuse':
          expect(result, isA<IngestRefused>(),
              reason: spec['nature'] as String);
          expect((result as IngestRefused).code, spec['motif'],
              reason: result.reason);
        case 'accepte' || 'accepte_avertissement':
          expect(result, isA<IngestedText>(),
              reason: result is IngestRefused ? result.reason : '');
          final ok = result as IngestedText;
          expect(ok.format, IngestFormat.pdf);
          if (spec['attendu'] == 'accepte_avertissement') {
            expect(ok.warnings, isNotEmpty);
          }
          for (final e in (spec['entites'] as List? ?? const [])) {
            final shown = (e as Map)['affiche'] as String;
            // Un identifiant coupé par une fin de ligne : voir LIMITES.md.
            final needle = shown.replaceAll('\\n', '\n');
            final flat = ok.text.replaceAll(RegExp(r'\s+'), ' ');
            expect(
                flat.contains(needle.replaceAll(RegExp(r'\s+'), ' ')), isTrue,
                reason: '${e['type']} absent du texte extrait de $name');
          }
      }
    });
  }
}
