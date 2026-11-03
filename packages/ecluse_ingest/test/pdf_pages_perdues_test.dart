import 'dart:io';

import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:test/test.dart';

/// Un PDF abîmé dont une page n'est plus atteignable depuis l'arbre des pages
/// ne doit pas être lu comme s'il était complet (P2-28) : la page est perdue
/// sans un mot, alors que le principe de l'ingestion PDF est de n'accepter que
/// ce dont tout le contenu est lu (spec P1-09 § 3).
///
/// Cas relevé par un essai de falsification (graine 42) sur
/// `bench/pdf/texte_multipage.pdf` : deux octets modifiés à ces positions
/// font disparaître la page 3 (celle qui porte le RPPS et l'IBAN).
void main() {
  final base = File('../../bench/pdf/texte_multipage.pdf').readAsBytesSync();

  List<int> abime() => List<int>.from(base)
    ..[3019] = 174
    ..[4454] = 221;

  test('référence : le PDF intact est lu en entier', () {
    final r = ingestFile(base, filename: 'a.pdf');
    expect(r, isA<IngestedText>());
    expect((r as IngestedText).text, contains('Page 3'));
  });

  test('page perdue après abîmage : refus explicite, jamais un texte partiel',
      () {
    final r = ingestFile(abime(), filename: 'a.pdf');
    expect(r, isA<IngestRefused>(),
        reason: r is IngestedText ? 'lu sans la page 3 : "${r.text}"' : '');
    expect((r as IngestRefused).code, 'malforme');
  });
}
