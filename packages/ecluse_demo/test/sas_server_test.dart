import 'dart:convert';

import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Request _post(
  String path,
  Object body, {
  String host = '127.0.0.1:8787',
  String contentType = 'application/json',
}) =>
    Request(
      'POST',
      Uri.parse('http://$host/$path'),
      body: body is String ? body : jsonEncode(body),
      headers: {'content-type': contentType},
    );

Future<Map<String, dynamic>> _json(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, dynamic>;

void main() {
  group('buildSasHandler', () {
    test('masque un prompt et ne renvoie jamais la table', () async {
      final handler = buildSasHandler();
      final response = await handler(_post('v1/redact', {
        'session': 's1',
        'text': 'M. Jean Dupont est présent.',
      }));
      final body = await _json(response);

      expect(response.statusCode, 200);
      expect(body['text'], 'M. [NOM_1] est présent.');
      expect(body['entities'], 1);
      expect(body.keys, unorderedEquals(['text', 'entities']));
      expect(jsonEncode(body), isNot(contains('Dupont')));
    });

    test('jetons stables sur toute une session', () async {
      final handler = buildSasHandler();
      Future<String> redact(String text) async => (await _json(await handler(
              _post('v1/redact', {'session': 's1', 'text': text}))))['text']
          as String;

      expect(await redact('M. Jean Dupont arrive.'), 'M. [NOM_1] arrive.');
      // Sans la table de session, Ecluse.redact aurait renvoyé [NOM_1].
      expect(await redact('Mme Alice Martin part.'), 'Mme [NOM_2] part.');
      expect(await redact('M. Jean Dupont revient.'), 'M. [NOM_1] revient.');
    });

    test('restaure avec la table de la session', () async {
      final handler = buildSasHandler();
      await handler(_post('v1/redact',
          {'session': 's1', 'text': 'M. Jean Dupont et Mme Alice Martin.'}));
      final body = await _json(await handler(_post('v1/restore',
          {'session': 's1', 'text': '[NOM_2] remplace [NOM_1].'})));

      expect(body['text'], 'Alice Martin remplace Jean Dupont.');
    });

    test('une session ne restaure pas les jetons d\'une autre', () async {
      final handler = buildSasHandler();
      await handler(_post(
          'v1/redact', {'session': 's1', 'text': 'M. Jean Dupont arrive.'}));
      final body = await _json(await handler(
          _post('v1/restore', {'session': 's2', 'text': '[NOM_1] arrive.'})));

      expect(body['text'], '[NOM_1] arrive.');
    });

    test('au-delà de maxSessions, la plus ancienne est oubliée', () async {
      final handler = buildSasHandler(store: SasStore(maxSessions: 1));
      await handler(_post(
          'v1/redact', {'session': 'a', 'text': 'M. Jean Dupont arrive.'}));
      await handler(_post(
          'v1/redact', {'session': 'b', 'text': 'Mme Alice Martin part.'}));
      final body = await _json(await handler(
          _post('v1/restore', {'session': 'a', 'text': '[NOM_1]'})));

      expect(body['text'], '[NOM_1]');
    });

    test('refuse un hôte qui n\'est pas la machine locale', () async {
      final response = await buildSasHandler()(_post(
        'v1/redact',
        {'session': 's1', 'text': 'x'},
        host: 'attaquant.example:8787',
      ));
      expect(response.statusCode, 403);
    });

    test('refuse un corps qui n\'est pas déclaré JSON', () async {
      final response = await buildSasHandler()(_post(
        'v1/redact',
        {'session': 's1', 'text': 'x'},
        contentType: 'text/plain',
      ));
      expect(response.statusCode, 415);
    });

    test('refuse un JSON invalide ou incomplet', () async {
      final handler = buildSasHandler();
      expect((await handler(_post('v1/redact', '{pas du json'))).statusCode,
          400);
      expect((await handler(_post('v1/redact', {'text': 'x'}))).statusCode,
          400);
      expect(
          (await handler(_post('v1/redact', {'session': '', 'text': 'x'})))
              .statusCode,
          400);
    });

    test('route inconnue ou mauvaise méthode : 404', () async {
      final handler = buildSasHandler();
      expect((await handler(_post('api/process', {}))).statusCode, 404);
      expect(
          (await handler(
                  Request('GET', Uri.parse('http://127.0.0.1:8787/v1/redact'))))
              .statusCode,
          404);
    });
  });
}
