import 'package:ecluse_ocr/ecluse_ocr.dart';
import 'package:ecluse_ocr_docling/ecluse_ocr_docling.dart';
import 'package:test/test.dart';

void main() {
  const parser = DoclingParser();

  group('DoclingParser', () {
    test('parse une réponse minimale à une page vide', () {
      const raw = '''
{"pages":[{"index":0,"width":100,"height":200,"regions":[]}]}
''';
      final pages = parser.parse(raw);
      expect(pages, hasLength(1));
      expect(pages.first.regions, isEmpty);
      expect(pages.first.width, 100);
      expect(pages.first.sourceEngine, 'docling');
    });

    test('parse une région avec tokens et bboxes', () {
      const raw = '''
{"pages":[{
  "index":0,"width":1000,"height":1400,
  "regions":[{
    "id":"r1","kind":"line","parent_id":null,
    "box":{"x":10,"y":20,"w":300,"h":30},
    "tokens":[
      {"text":"Dupont","conf":0.98,
       "box":{"x":10,"y":20,"w":80,"h":30}},
      {"text":"155047800000162","conf":0.72,
       "box":{"x":100,"y":20,"w":180,"h":30}}
    ]
  }]
}]}
''';
      final pages = parser.parse(raw);
      final tokens = pages.first.regions.first.tokens;
      expect(tokens, hasLength(2));
      expect(tokens[0].text, 'Dupont');
      expect(tokens[1].confidence, 0.72);
      expect(tokens[0].box.pageIndex, 0);
    });

    test('mappe correctement les kinds de région', () {
      const raw = '''
{"pages":[{"index":0,"width":10,"height":10,"regions":[
  {"id":"a","kind":"heading","box":{"x":0,"y":0,"w":1,"h":1},"tokens":[]},
  {"id":"b","kind":"table_cell","box":{"x":0,"y":0,"w":1,"h":1},"tokens":[]},
  {"id":"c","kind":"paragraph","box":{"x":0,"y":0,"w":1,"h":1},"tokens":[]}
]}]}
''';
      final regions = parser.parse(raw).first.regions;
      expect(regions[0].kind, OcrRegionKind.heading);
      expect(regions[1].kind, OcrRegionKind.tableCell);
      expect(regions[2].kind, OcrRegionKind.paragraph);
    });

    test('clamp la confiance dans [0,1]', () {
      const raw = '''
{"pages":[{"index":0,"width":10,"height":10,"regions":[
  {"id":"a","kind":"line","box":{"x":0,"y":0,"w":1,"h":1},
   "tokens":[{"text":"x","conf":1.5,"box":{"x":0,"y":0,"w":1,"h":1}}]}
]}]}
''';
      final token = parser.parse(raw).first.regions.first.tokens.first;
      expect(token.confidence, 1.0);
    });

    test('lève FormatException si racine non-objet', () {
      expect(
        () => parser.parse('[]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('lève FormatException si champ pages manquant', () {
      expect(
        () => parser.parse('{"other":1}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('conserve les warnings envoyés par le sidecar', () {
      const raw = '''
{"pages":[{"index":0,"width":10,"height":10,"regions":[],
"warnings":["confiance moyenne <0.5"]}]}
''';
      final page = parser.parse(raw).first;
      expect(page.warnings, ['confiance moyenne <0.5']);
    });
  });
}
