import 'dart:convert';
import 'dart:io';

import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

final class _EchoClient implements LlmClient {
  @override
  Future<String> complete(String maskedText,
          {required String instruction}) async =>
      maskedText;
}

List<int> _buildDocxBytes(String documentXml) =>
    buildStoredZip({'word/document.xml': documentXml});

List<int> _buildOdtBytes(String contentXml) => buildStoredZip({
      'mimetype': 'application/vnd.oasis.opendocument.text',
      'content.xml': contentXml,
    });

Future<Map<String, dynamic>> _postIngest(
  Handler handler, {
  required String filename,
  required List<int> bytes,
}) async {
  final request = Request(
    'POST',
    Uri.parse('http://l/api/ingest'),
    body: jsonEncode({'filename': filename, 'bytes': base64Encode(bytes)}),
  );
  final response = await handler(request);
  expect(response.statusCode, 200);
  return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
}

void main() {
  late Directory tempWebDir;
  late Handler handler;

  setUp(() {
    tempWebDir = Directory.systemTemp.createTempSync('ecluse_demo_web_');
    File('${tempWebDir.path}/index.html')
        .writeAsStringSync('<title>ok</title>');
    handler = buildHandler(
      redactService: RedactService(_EchoClient()),
      webDirectory: tempWebDir,
    );
  });

  tearDown(() {
    tempWebDir.deleteSync(recursive: true);
  });

  group('POST /api/ingest — formats pris en charge', () {
    test('.txt déposé -> texte extrait, aucune erreur', () async {
      final body = await _postIngest(
        handler,
        filename: 'notes.txt',
        bytes: utf8.encode('Compte rendu du 12 mars.'),
      );

      expect(body['error'], isNull);
      expect(body['text'], 'Compte rendu du 12 mars.');
      expect(body['format'], 'txt');
    });

    test('.md déposé -> texte extrait tel quel', () async {
      final body = await _postIngest(
        handler,
        filename: 'notes.md',
        bytes: utf8.encode('# Réunion\n\n- point un\n- point deux'),
      );

      expect(body['error'], isNull);
      expect(body['text'], '# Réunion\n\n- point un\n- point deux');
      expect(body['format'], 'md');
    });

    test('.docx déposé -> dézippage et extraction du texte', () async {
      final xml = '<w:p><w:r><w:t>Compte rendu de r&#233;union</w:t>'
          '</w:r></w:p>';
      final body = await _postIngest(
        handler,
        filename: 'compte_rendu.docx',
        bytes: _buildDocxBytes(xml),
      );

      expect(body['error'], isNull);
      expect(body['text'], 'Compte rendu de réunion\n');
      expect(body['format'], 'docx');
    });

    test('.odt déposé -> dézippage et extraction du texte', () async {
      final bytes = _buildOdtBytes(
        '<text:p>Compte rendu de réunion</text:p>'
        '<text:p>Deuxième paragraphe.</text:p>',
      );
      final body = await _postIngest(
        handler,
        filename: 'compte_rendu.odt',
        bytes: bytes,
      );

      expect(body['error'], isNull);
      expect(body['text'], 'Compte rendu de réunion\nDeuxième paragraphe.\n');
      expect(body['format'], 'odt');
    });

    test('fichier .txt vide -> traité proprement, texte vide', () async {
      final body = await _postIngest(
        handler,
        filename: 'vide.txt',
        bytes: const [],
      );

      expect(body['error'], isNull);
      expect(body['text'], '');
      expect(body['format'], 'txt');
    });
  });

  group('POST /api/ingest — refus explicite', () {
    test('.pdf refusé avec un message clair', () async {
      final body = await _postIngest(
        handler,
        filename: 'contrat.pdf',
        bytes: [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34],
      );

      expect(body['text'], isNull);
      expect(body['error'], isNotEmpty);
      expect(body['error'], contains('non traité'));
    });

    test('extension inconnue -> refus explicite', () async {
      final body = await _postIngest(
        handler,
        filename: 'tableau.xlsx',
        bytes: utf8.encode('peu importe le contenu'),
      );

      expect(body['text'], isNull);
      expect(body['error'], contains('.xlsx'));
    });
  });

  group('POST /api/ingest — requêtes malformées', () {
    test('nom de fichier manquant -> erreur claire, pas de crash', () async {
      final request = Request(
        'POST',
        Uri.parse('http://l/api/ingest'),
        body: jsonEncode({'bytes': base64Encode(utf8.encode('x'))}),
      );
      final response = await handler(request);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      expect(response.statusCode, 200);
      expect(body['error'], isNotEmpty);
    });

    test('JSON invalide -> erreur claire, pas de crash', () async {
      final request = Request(
        'POST',
        Uri.parse('http://l/api/ingest'),
        body: 'ceci n\'est pas du JSON',
      );
      final response = await handler(request);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      expect(response.statusCode, 200);
      expect(body['error'], isNotEmpty);
    });
  });
}
