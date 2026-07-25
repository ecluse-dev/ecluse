import 'dart:convert';
import 'dart:io';

import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

final class _EchoClient implements LlmClient {
  @override
  Future<String> complete(String maskedText,
          {required String instruction}) async =>
      maskedText;
}

final class _FailingClient implements LlmClient {
  @override
  Future<String> complete(String maskedText, {required String instruction}) {
    throw const LlmError('Service indisponible.');
  }
}

void main() {
  late Directory tempWebDir;

  setUp(() {
    tempWebDir = Directory.systemTemp.createTempSync('ecluse_demo_web_');
    File('${tempWebDir.path}/index.html')
        .writeAsStringSync('<title>ok</title>');
  });

  tearDown(() {
    tempWebDir.deleteSync(recursive: true);
  });

  group('buildHandler', () {
    test('GET / sert index.html', () async {
      final handler = buildHandler(
        redactService: RedactService(_EchoClient()),
        webDirectory: tempWebDir,
      );
      final response = await handler(Request('GET', Uri.parse('http://l/')));
      expect(response.statusCode, 200);
      expect(await response.readAsString(), contains('<title>ok</title>'));
    });

    test('GET /api/samples renvoie les deux documents d\'exemple', () async {
      final handler = buildHandler(
        redactService: RedactService(_EchoClient()),
        webDirectory: tempWebDir,
      );
      final response =
          await handler(Request('GET', Uri.parse('http://l/api/samples')));
      final body = jsonDecode(await response.readAsString()) as List<dynamic>;

      expect(response.statusCode, 200);
      expect(body, hasLength(2));
      expect((body[0] as Map<String, dynamic>)['title'], isNotEmpty);
    });

    test('POST /api/process retourne les 4 panneaux', () async {
      final handler = buildHandler(
        redactService: RedactService(_EchoClient()),
        webDirectory: tempWebDir,
      );
      final request = Request(
        'POST',
        Uri.parse('http://l/api/process'),
        body: jsonEncode({
          'text': 'M. Jean Dupont est arrivé.',
          'instruction': 'Résume.',
        }),
      );
      final response = await handler(request);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      expect(response.statusCode, 200);
      expect(body['maskedText'], contains('[NOM_1]'));
      expect(body['restoredText'], 'M. Jean Dupont est arrivé.');
      expect(body.containsKey('mapping'), isFalse);
    });

    test('une erreur LLM revient comme {error} clair, sans planter', () async {
      final handler = buildHandler(
        redactService: RedactService(_FailingClient()),
        webDirectory: tempWebDir,
      );
      final request = Request(
        'POST',
        Uri.parse('http://l/api/process'),
        body: jsonEncode({'text': 'Un texte.', 'instruction': 'Résume.'}),
      );
      final response = await handler(request);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      expect(response.statusCode, 200);
      expect(body['error'], 'Service indisponible.');
    });

    test('texte manquant -> erreur claire sans planter', () async {
      final handler = buildHandler(
        redactService: RedactService(_EchoClient()),
        webDirectory: tempWebDir,
      );
      final request = Request(
        'POST',
        Uri.parse('http://l/api/process'),
        body: jsonEncode({'instruction': 'Résume.'}),
      );
      final response = await handler(request);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      expect(response.statusCode, 200);
      expect(body['error'], isNotEmpty);
    });
  });
}
