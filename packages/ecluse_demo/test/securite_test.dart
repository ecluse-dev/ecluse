import 'dart:convert';
import 'dart:io';

import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

final class _SpyClient implements LlmClient {
  String? instruction;
  String? text;

  @override
  Future<String> complete(String maskedText,
      {required String instruction}) async {
    text = maskedText;
    this.instruction = instruction;
    return maskedText;
  }
}

void main() {
  late Directory web;
  late _SpyClient spy;
  late Handler handler;

  setUp(() {
    web = Directory.systemTemp.createTempSync('ecluse_demo_sec_');
    File('${web.path}/index.html').writeAsStringSync('<title>ok</title>');
    spy = _SpyClient();
    handler = buildHandler(
      redactService: RedactService(spy),
      webDirectory: web,
    );
  });

  tearDown(() => web.deleteSync(recursive: true));

  Future<Response> post(
    String path,
    Object? body, {
    Map<String, String> headers = const {'content-type': 'application/json'},
  }) async =>
      handler(Request(
        'POST',
        Uri.parse('http://localhost/$path'),
        headers: headers,
        body: body is String ? body : jsonEncode(body),
      ));

  Future<Map<String, dynamic>> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  group('corps JSON non-objet', () {
    for (final path in ['api/process', 'api/ingest']) {
      for (final corps in ['[1,2]', '[]', 'null', '"texte"', '42']) {
        test('$path avec $corps -> erreur claire, pas de 500', () async {
          final r = await post(path, corps);
          expect(r.statusCode, 400);
          expect((await json(r))['error'], isNotEmpty);
        });
      }
    }
  });

  group('requêtes inter-sites (CSRF / DNS rebinding)', () {
    test('Content-Type text/plain refusé (évite le CORS « simple »)', () async {
      final r = await post(
        'api/process',
        jsonEncode({'text': 'M. Jean Dupont', 'instruction': 'Résume.'}),
        headers: {'content-type': 'text/plain'},
      );
      expect(r.statusCode, 415);
      expect(spy.text, isNull, reason: 'le LLM ne doit pas être appelé');
    });

    test('sans Content-Type refusé', () async {
      final r = await post(
        'api/process',
        jsonEncode({'text': 'x', 'instruction': 'y'}),
        headers: const {},
      );
      expect(r.statusCode, 415);
    });

    test('Host étranger refusé (DNS rebinding)', () async {
      final r = await post(
        'api/process',
        {'text': 'M. Jean Dupont', 'instruction': 'Résume.'},
        headers: {
          'content-type': 'application/json',
          'host': 'evil.example',
        },
      );
      expect(r.statusCode, 403);
      expect(spy.text, isNull);
    });

    for (final host in ['localhost:8080', '127.0.0.1:8080', '[::1]:8080']) {
      test('Host $host accepté', () async {
        final r = await post(
          'api/process',
          {'text': 'M. Jean Dupont est là.', 'instruction': 'Résume.'},
          headers: {'content-type': 'application/json', 'host': host},
        );
        expect(r.statusCode, 200);
      });
    }
  });

  group('taille de corps', () {
    test('corps de traitement trop gros -> 413 sans traitement', () async {
      final gros = jsonEncode({
        'text': 'a' * (3 * 1024 * 1024),
        'instruction': 'Résume.',
      });
      final r = await post('api/process', gros);
      expect(r.statusCode, 413);
      expect(spy.text, isNull);
    });
  });

  group('la consigne est masquée comme le texte', () {
    test('le LLM ne reçoit pas le nom présent dans la consigne', () async {
      final r = await post('api/process', {
        'text': 'Dossier du patient.',
        'instruction': 'Résume le cas de M. Pierre Martin.',
      });
      expect(r.statusCode, 200);
      expect(spy.instruction, isNot(contains('Martin')));
      expect(spy.instruction, contains('[NOM_1]'));
    });

    test('même personne dans la consigne et le texte : même jeton', () async {
      await post('api/process', {
        'text': 'M. Pierre Martin est arrivé.',
        'instruction': 'Résume le cas de M. Pierre Martin.',
      });
      expect(spy.instruction, contains('[NOM_1]'));
      expect(spy.text, contains('[NOM_1]'));
      expect(spy.instruction, isNot(contains('[NOM_2]')));
    });
  });

  test('un caractère NUL dans le texte est refusé avec un motif', () async {
    final r = await post('api/process', {
      'text': 'a\u0000b',
      'instruction': 'Résume.',
    });
    expect((await json(r))['error'], contains('NUL'));
    expect(spy.text, isNull);
  });
}
