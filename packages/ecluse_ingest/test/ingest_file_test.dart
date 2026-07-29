import 'dart:convert';

import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

List<int> _buildDocxBytes(String documentXml) =>
    buildStoredZip({'word/document.xml': documentXml});

void main() {
  group('ingestFile — formats pris en charge', () {
    test('.txt : texte brut décodé tel quel', () {
      final result = ingestFile(
        utf8.encode('Un texte simple, sans mise en forme.'),
        filename: 'note.txt',
      );
      expect(result, isA<IngestedText>());
      final text = result as IngestedText;
      expect(text.text, 'Un texte simple, sans mise en forme.');
      expect(text.format, IngestFormat.txt);
    });

    test('.md : la syntaxe Markdown brute est préservée, jamais rendue', () {
      final result = ingestFile(
        utf8.encode('# Titre\n\n**gras** et [lien](https://example.fr).'),
        filename: 'notes.md',
      );
      expect(result, isA<IngestedText>());
      final text = result as IngestedText;
      expect(
        text.text,
        '# Titre\n\n**gras** et [lien](https://example.fr).',
      );
      expect(text.format, IngestFormat.md);
    });

    test('.docx : dézippage + extraction du texte de document.xml', () {
      final xml = '<w:p><w:r><w:t>Compte rendu de r&#233;union</w:t>'
          '</w:r></w:p><w:p><w:r><w:t>Deuxi&#232;me paragraphe.</w:t>'
          '</w:r></w:p>';
      final result = ingestFile(
        _buildDocxBytes(xml),
        filename: 'compte_rendu.docx',
      );
      expect(result, isA<IngestedText>());
      final text = result as IngestedText;
      expect(
        text.text,
        'Compte rendu de réunion\nDeuxième paragraphe.\n',
      );
      expect(text.format, IngestFormat.docx);
    });
  });

  group('ingestFile — hors périmètre v1', () {
    test(
        '.pdf est refusé explicitement, même avec un contenu texte '
        'plausible', () {
      final pdfLikeBytes = [
        0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, // %PDF-1.4
        ...utf8.encode(' du texte qui pourrait faire illusion'),
      ];
      final result = ingestFile(pdfLikeBytes, filename: 'contrat.pdf');
      expect(result, isA<IngestRefused>());
      final refused = result as IngestRefused;
      expect(refused.reason, contains('non traité'));
      // Garde-fou non négociable : jamais de texte, même vide, sur un
      // format non lu.
      expect(result, isNot(isA<IngestedText>()));
    });

    test('extension inconnue -> refus explicite', () {
      final result = ingestFile(
        utf8.encode('peu importe le contenu'),
        filename: 'tableau.xlsx',
      );
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('.xlsx'));
    });

    test('fichier sans extension -> refus explicite', () {
      final result = ingestFile(utf8.encode('contenu'), filename: 'README');
      expect(result, isA<IngestRefused>());
    });
  });

  group('ingestFile — défense en profondeur (magic bytes)', () {
    test('.txt contenant en réalité un .docx (ZIP) -> refus', () {
      final docxBytes = _buildDocxBytes(
        '<w:p><w:r><w:t>Contenu</w:t></w:r></w:p>',
      );
      final result = ingestFile(docxBytes, filename: 'faux.txt');
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('ZIP'));
    });

    test('.docx sans signature ZIP en tête -> refus', () {
      final result = ingestFile(
        utf8.encode('Ceci est en fait du texte brut, pas un docx.'),
        filename: 'faux.docx',
      );
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('ZIP'));
    });

    test('.docx dont document.xml est absent -> refus', () {
      final result = ingestFile(
        buildStoredZip({'autre_fichier.txt': 'contenu'}),
        filename: 'vide.docx',
      );
      expect(result, isA<IngestRefused>());
      expect(
        (result as IngestRefused).reason,
        contains('document.xml'),
      );
    });

    test(
        '.md avec un BOM UTF-16 -> refus explicite (pas de décodage '
        'silencieux)', () {
      final utf16LeBomBytes = [0xFF, 0xFE, 0x48, 0x00, 0x69, 0x00];
      final result = ingestFile(utf16LeBomBytes, filename: 'notes.md');
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('UTF-16'));
    });

    test(
        '.txt en encodage non-UTF-8 (Windows-1252) -> refus explicite, '
        'pas de repli silencieux', () {
      // 0xE9 seul (« é » en Windows-1252) n'est pas un octet de tête UTF-8
      // valide suivi d'une continuation correcte : le décodage strict
      // échoue, comme attendu.
      final windows1252Bytes = [
        ...utf8.encode('Ren'),
        0xE9,
        ...utf8.encode(' Dupont'),
      ];
      final result = ingestFile(windows1252Bytes, filename: 'note.txt');
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('Encodage'));
    });
  });
}
