import 'dart:convert';
import 'dart:typed_data';

import 'package:ecluse_ocr/ecluse_ocr.dart';
import 'package:ecluse_ocr_docling/ecluse_ocr_docling.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('DoclingConfig', () {
    test('accepte les hosts loopback', () {
      for (final h in ['127.0.0.1', 'localhost']) {
        final cfg = DoclingConfig(baseUrl: Uri.parse('http://$h:8790'));
        expect(cfg.isLoopback, isTrue,
            reason: '$h devrait être considéré loopback');
      }
    });

    test('rejette les hosts non-loopback', () {
      final cfg = DoclingConfig(baseUrl: Uri.parse('http://10.0.0.1:8790'));
      expect(cfg.isLoopback, isFalse);
    });
  });

  group('DoclingClient', () {
    test('lève SidecarNotLoopbackException si baseUrl non-loopback', () {
      expect(
        () => DoclingClient(
          config: DoclingConfig(
            baseUrl: Uri.parse('http://10.0.0.1:8790'),
          ),
        ),
        throwsA(isA<SidecarNotLoopbackException>()),
      );
    });

    test('accepte 127.0.0.1 par défaut', () {
      final client = DoclingClient(
        config: DoclingConfig(baseUrl: Uri.parse('http://127.0.0.1:8790')),
        httpClient: MockClient((_) async => http.Response('{"pages":[]}', 200)),
      );
      expect(client.name, 'docling');
      client.close();
    });

    test('extract retourne les pages parsées à partir du sidecar', () async {
      final mock = MockClient((request) async {
        // La requête doit être POST /extract multipart
        expect(request.method, 'POST');
        expect(request.url.path, '/extract');
        return http.Response(
          jsonEncode({
            'pages': [
              {
                'index': 0,
                'width': 1000,
                'height': 1400,
                'regions': [
                  {
                    'id': 'r1',
                    'kind': 'line',
                    'box': {'x': 0, 'y': 0, 'w': 100, 'h': 20},
                    'tokens': [
                      {
                        'text': 'Bonjour',
                        'conf': 0.95,
                        'box': {'x': 0, 'y': 0, 'w': 60, 'h': 20},
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        );
      });
      final client = DoclingClient(
        config: DoclingConfig(baseUrl: Uri.parse('http://127.0.0.1:8790')),
        httpClient: mock,
      );
      final pages = await client.extract(
        Uint8List.fromList([1, 2, 3, 4]),
        mediaType: 'application/pdf',
      );
      expect(pages, hasLength(1));
      expect(pages.first.regions.first.tokens.first.text, 'Bonjour');
      client.close();
    });

    test('extract refuse un mediaType non supporté', () async {
      final client = DoclingClient(
        config: DoclingConfig(baseUrl: Uri.parse('http://127.0.0.1:8790')),
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(
        () => client.extract(
          Uint8List.fromList([0]),
          mediaType: 'application/octet-stream',
        ),
        throwsA(isA<OcrUnsupportedFormatException>()),
      );
      client.close();
    });

    test(
        'extract propage une erreur HTTP non-200 en DoclingSidecarErrorException',
        () async {
      final client = DoclingClient(
        config: DoclingConfig(baseUrl: Uri.parse('http://127.0.0.1:8790')),
        httpClient: MockClient(
            (_) async => http.Response('docling not installed', 503)),
      );
      expect(
        () => client.extract(
          Uint8List.fromList([1]),
          mediaType: 'application/pdf',
        ),
        throwsA(isA<DoclingSidecarErrorException>()),
      );
      client.close();
    });

    test('close() empêche tout appel ultérieur', () async {
      final client = DoclingClient(
        config: DoclingConfig(baseUrl: Uri.parse('http://127.0.0.1:8790')),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      client.close();
      expect(
        () => client.extract(
          Uint8List.fromList([1]),
          mediaType: 'application/pdf',
        ),
        throwsA(isA<OcrEngineClosedException>()),
      );
    });
  });
}
