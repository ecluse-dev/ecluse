import 'dart:convert';

import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

/// Règle n°4 de CLAUDE.md : un contenu non lu ne doit jamais ressortir comme
/// « rien à masquer ». Ces cas produisaient un texte vide ou partiel, sans
/// refus ni avertissement.
const _ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

List<int> _docx(String xml, [Map<String, String> extra = const {}]) =>
    buildStoredZip({'word/document.xml': xml, ...extra});

List<int> _odt(String content, [Map<String, String> extra = const {}]) =>
    buildStoredZip({
      'mimetype': 'application/vnd.oasis.opendocument.text',
      'content.xml': content,
      ...extra,
    });

const _odtNs = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';

void main() {
  group('docx', () {
    test('préfixe XML autre que w: -> refus explicite', () {
      final xml = '<ns0:document xmlns:ns0="$_ns"><ns0:body><ns0:p><ns0:r>'
          '<ns0:t>Jean Dupont NIR 185057800608491</ns0:t></ns0:r></ns0:p>'
          '</ns0:body></ns0:document>';
      final r = ingestFile(_docx(xml), filename: 'a.docx');
      expect(r, isA<IngestRefused>());
      expect((r as IngestRefused).reason, contains('préfixe'));
    });

    test('espace de noms par défaut -> refus explicite', () {
      final xml = '<document xmlns="$_ns"><body><p><r><t>Jean</t></r></p>'
          '</body></document>';
      expect(ingestFile(_docx(xml), filename: 'a.docx'), isA<IngestRefused>());
    });

    test('préfixe w: standard -> inchangé', () {
      final xml = '<w:document xmlns:w="$_ns"><w:body><w:p><w:r>'
          '<w:t>Jean</w:t></w:r></w:p></w:body></w:document>';
      final r = ingestFile(_docx(xml), filename: 'a.docx') as IngestedText;
      expect(r.text, 'Jean\n');
      expect(r.warnings, isEmpty);
    });

    test('document vide -> avertissement « empty »', () {
      final xml = '<w:document xmlns:w="$_ns"><w:body><w:p/></w:body>'
          '</w:document>';
      final r = ingestFile(_docx(xml), filename: 'a.docx') as IngestedText;
      expect(r.warnings, contains('empty'));
    });

    test('en-têtes, pieds, notes et commentaires -> avertissement', () {
      final body = '<w:document xmlns:w="$_ns"><w:body><w:p><w:r>'
          '<w:t>Corps</w:t></w:r></w:p></w:body></w:document>';
      final r = ingestFile(
        _docx(body, {
          'word/header1.xml': '<w:hdr xmlns:w="$_ns"><w:p><w:r><w:t>EN-TETE '
              'Jean Dupont</w:t></w:r></w:p></w:hdr>',
          'word/footnotes.xml': '<w:footnotes xmlns:w="$_ns"/>',
        }),
        filename: 'a.docx',
      ) as IngestedText;
      expect(r.warnings, contains('ignored_parts'));
    });

    test('entité numérique hors plage -> refus, pas d\'exception', () {
      final xml = '<w:document xmlns:w="$_ns"><w:body><w:p><w:r>'
          '<w:t>a&#x110000;b</w:t></w:r></w:p></w:body></w:document>';
      expect(ingestFile(_docx(xml), filename: 'a.docx'), isA<IngestRefused>());
    });

    test('entité numérique démesurée -> refus, pas d\'exception', () {
      final xml = '<w:document xmlns:w="$_ns"><w:body><w:p><w:r>'
          '<w:t>a&#99999999999999999999;b</w:t></w:r></w:p></w:body>'
          '</w:document>';
      expect(ingestFile(_docx(xml), filename: 'a.docx'), isA<IngestRefused>());
    });

    test('section CDATA -> refus explicite', () {
      final xml = '<w:document xmlns:w="$_ns"><w:body><w:p><w:r><w:t>'
          '<![CDATA[Jean Dupont]]></w:t></w:r></w:p></w:body></w:document>';
      expect(ingestFile(_docx(xml), filename: 'a.docx'), isA<IngestRefused>());
    });
  });

  group('odt', () {
    test('préfixe XML autre que text: -> refus explicite', () {
      final xml = '<o:document-content xmlns:o="$_odtNs"><o:body><o:p>Jean'
          '</o:p></o:body></o:document-content>';
      expect(ingestFile(_odt(xml), filename: 'a.odt'), isA<IngestRefused>());
    });

    test('document vide -> avertissement « empty »', () {
      final xml = '<office:document-content xmlns:text="$_odtNs"><office:body>'
          '<office:text/></office:body></office:document-content>';
      final r = ingestFile(_odt(xml), filename: 'a.odt') as IngestedText;
      expect(r.warnings, contains('empty'));
    });

    test('en-tête dans styles.xml -> avertissement', () {
      final xml = '<office:document-content xmlns:text="$_odtNs"><office:body>'
          '<office:text><text:p>Corps</text:p></office:text></office:body>'
          '</office:document-content>';
      final r = ingestFile(
        _odt(xml, {
          'styles.xml': '<office:document-styles xmlns:text="$_odtNs">'
              '<style:master-page><style:header><text:p>EN-TETE Jean Dupont'
              '</text:p></style:header></style:master-page>'
              '</office:document-styles>',
        }),
        filename: 'a.odt',
      ) as IngestedText;
      expect(r.warnings, contains('ignored_parts'));
    });

    test('entité numérique hors plage -> refus, pas d\'exception', () {
      final xml = '<office:document-content xmlns:text="$_odtNs"><office:body>'
          '<office:text><text:p>a&#x110000;b</text:p></office:text>'
          '</office:body></office:document-content>';
      expect(ingestFile(_odt(xml), filename: 'a.odt'), isA<IngestRefused>());
    });
  });

  group('texte brut', () {
    test('UTF-16 sans BOM (NUL entre les lettres) -> refus', () {
      final bytes = <int>[];
      for (final unit in 'NIR 185057800608491'.codeUnits) {
        bytes
          ..add(unit)
          ..add(0);
      }
      final r = ingestFile(bytes, filename: 'a.txt');
      expect(r, isA<IngestRefused>());
      expect((r as IngestRefused).reason, contains('NUL'));
    });

    test('UTF-8 normal -> inchangé', () {
      final r = ingestFile(utf8.encode('Bonjour'), filename: 'a.txt');
      expect(r, isA<IngestedText>());
    });
  });
}
