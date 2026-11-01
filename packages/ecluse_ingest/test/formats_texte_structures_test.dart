import 'dart:convert';

import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Formats texte structurés (P2-67) : `.csv`, `.tsv`, `.json`, `.html`/`.htm`,
/// `.xml`. Ils étaient refusés (« format non traité ») alors que la détection
/// lit désormais leur structure (CSV à en-tête P2-61, clés de données P2-61,
/// tableaux HTML P2-63). Même garde-fous que `.txt` : UTF-8 strict, refus d'un
/// binaire déguisé, d'un NUL, d'un encodage non reconnu.
void main() {
  const cas = {
    'export.csv': IngestFormat.csv,
    'EXPORT.CSV': IngestFormat.csv,
    'export.tsv': IngestFormat.tsv,
    'dossier.json': IngestFormat.json,
    'page.html': IngestFormat.html,
    'page.htm': IngestFormat.html,
    'flux.xml': IngestFormat.xml,
  };
  cas.forEach((nom, format) {
    test('$nom : texte brut, format $format', () {
      final r = ingestFile(utf8.encode('a;b\n1;2\n'), filename: nom);
      expect(r, isA<IngestedText>());
      expect((r as IngestedText).format, format);
      expect(r.text, 'a;b\n1;2\n');
    });
  });

  test('UTF-8 avec BOM : le BOM est retiré', () {
    final r = ingestFile([0xEF, 0xBB, 0xBF, ...utf8.encode('Nom;Prénom\n')],
        filename: 'x.csv');
    expect((r as IngestedText).text, 'Nom;Prénom\n');
  });

  group('refus explicites', () {
    test('Windows-1252 (export Excel courant)', () {
      final r =
          ingestFile([0x50, 0x72, 0xE9, 0x6E, 0x6F, 0x6D], filename: 'x.csv');
      expect(r, isA<IngestRefused>());
      expect((r as IngestRefused).reason, contains('UTF-8'));
    });

    test('UTF-16', () {
      final r = ingestFile([0xFF, 0xFE, 0x4E, 0x00], filename: 'x.csv');
      expect(r, isA<IngestRefused>());
    });

    test('binaire déguisé en .json', () {
      final r =
          ingestFile([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31], filename: 'x.json');
      expect(r, isA<IngestRefused>());
    });

    test('NUL dans un .html', () {
      final r = ingestFile(utf8.encode('<p>a\u0000b</p>'), filename: 'x.html');
      expect(r, isA<IngestRefused>());
    });

    test('.xlsx, .rtf, .doc restent refusés', () {
      for (final n in ['a.xlsx', 'a.rtf', 'a.doc', 'a.pptx']) {
        expect(ingestFile(utf8.encode('x'), filename: n), isA<IngestRefused>(),
            reason: n);
      }
    });

    test('le message de refus liste les nouveaux formats', () {
      final r =
          ingestFile(utf8.encode('x'), filename: 'a.rtf') as IngestRefused;
      for (final f in ['.csv', '.tsv', '.json', '.html', '.xml']) {
        expect(r.reason, contains(f));
      }
    });
  });

  group('masquage de bout en bout', () {
    Future<String> masque(String nom, String contenu) async {
      final r = ingestFile(utf8.encode(contenu), filename: nom) as IngestedText;
      final m = await Ecluse.redact(r.text);
      expect(Ecluse.restore(m.maskedText, m.mapping), r.text);
      return m.maskedText;
    }

    test('csv à en-tête', () async {
      final m = await masque(
          'x.csv', 'Nom;Prénom;Service\nQuenelle;Zorglub;Cardio\n');
      expect(m, isNot(contains('Quenelle')));
      expect(m, isNot(contains('Zorglub')));
      expect(m, contains('Cardio'));
    });

    test('tsv à en-tête', () async {
      final m = await masque(
          'x.tsv', 'Nom\tPrénom\tService\nQuenelle\tZorglub\tCardio\n');
      expect(m, isNot(contains('Quenelle')));
    });

    test('json à clés explicites', () async {
      final m = await masque(
          'x.json', '{"nom_patient": "Quenelle", "prenom": "Zorglub"}');
      expect(m, isNot(contains('Quenelle')));
      expect(m, isNot(contains('Zorglub')));
    });

    test('html : tableau étiquette / valeur', () async {
      final m = await masque('x.html',
          '<table><tr><td>Date de naissance</td><td>12/03/1950</td></tr></table>');
      expect(m, isNot(contains('12/03/1950')));
    });

    test('xml à clés explicites', () async {
      final m = await masque(
          'x.xml', '<patient><nom_patient>Quenelle</nom_patient></patient>');
      expect(m, isNot(contains('Quenelle')));
    });

    test('csv ambigu : refus explicite de la détection', () async {
      final r = ingestFile(
          utf8.encode(
              'Nom;Prénom;Ville\nQuenelle;Zorglub;Lyon\nMartin;Hector\n'),
          filename: 'x.csv') as IngestedText;
      await expectLater(
          Ecluse.redact(r.text), throwsA(isA<TableauAmbiguException>()));
    });
  });
}
