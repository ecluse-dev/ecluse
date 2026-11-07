import 'package:ecluse_llm/ecluse_llm.dart';
import 'package:test/test.dart';

void main() {
  const textLen = 500;

  group('parseLeakSpansJson', () {
    test('parse un JSON strict avec une leak', () {
      const raw = '''
{"leaks": [
  {"start": 10, "end": 20, "kind": "coreference",
   "reason": "pronom \\"elle\\" remonte à un nom masqué",
   "confidence": 0.8}
]}
''';
      final parsed = parseLeakSpansJson(raw, textLength: textLen);
      expect(parsed.leaks, hasLength(1));
      expect(parsed.leaks.single.start, 10);
      expect(parsed.leaks.single.end, 20);
      expect(parsed.leaks.single.kind, LeakKind.coreference);
      expect(parsed.leaks.single.confidence, closeTo(0.8, 1e-9));
      expect(parsed.warnings, isEmpty);
    });

    test('parse une liste vide (aucune fuite)', () {
      final parsed = parseLeakSpansJson('{"leaks": []}', textLength: textLen);
      expect(parsed.leaks, isEmpty);
      expect(parsed.warnings, isEmpty);
    });

    test('tolère un préambule avant le JSON', () {
      const raw = 'Voici mes trouvailles :\n{"leaks": []}';
      final parsed = parseLeakSpansJson(raw, textLength: textLen);
      expect(parsed.leaks, isEmpty);
    });

    test('tolère un fence markdown ```json', () {
      const raw = '```json\n{"leaks": []}\n```';
      final parsed = parseLeakSpansJson(raw, textLength: textLen);
      expect(parsed.leaks, isEmpty);
    });

    test('tolère du texte après l\'objet JSON', () {
      const raw = '{"leaks": []}\n\nJ\'espère que ça aide.';
      final parsed = parseLeakSpansJson(raw, textLength: textLen);
      expect(parsed.leaks, isEmpty);
    });

    test('respecte les accolades dans les strings', () {
      const raw = '{"leaks": [{"start": 0, "end": 5, "kind": "coreference", '
          '"reason": "contient une } et un {", "confidence": 0.5}]}';
      final parsed = parseLeakSpansJson(raw, textLength: textLen);
      expect(parsed.leaks, hasLength(1));
    });

    test('lève si aucun JSON trouvé', () {
      expect(
        () => parseLeakSpansJson('Je refuse de répondre.', textLength: textLen),
        throwsA(isA<LlmJsonParseException>()),
      );
    });

    test('ignore les leaks avec offsets débordant du texte', () {
      const raw = '''
{"leaks": [
  {"start": 10, "end": 20, "kind": "coreference", "reason": "ok",
   "confidence": 0.5},
  {"start": 490, "end": 600, "kind": "coreference", "reason": "trop loin",
   "confidence": 0.5}
]}
''';
      final parsed = parseLeakSpansJson(raw, textLength: textLen);
      expect(parsed.leaks, hasLength(1));
      expect(parsed.warnings, hasLength(1));
      expect(parsed.warnings.single, contains('dépasse'));
    });

    test('kind inconnu bascule sur LeakKind.unknown avec warning', () {
      const raw =
          '{"leaks": [{"start": 0, "end": 5, "kind": "hallucinated_kind", '
          '"reason": "x", "confidence": 0.5}]}';
      final parsed = parseLeakSpansJson(raw, textLength: textLen);
      expect(parsed.leaks, hasLength(1));
      expect(parsed.leaks.single.kind, LeakKind.unknown);
      expect(parsed.warnings.single, contains('kind inconnu'));
    });

    test('confidence hors [0,1] est clampée avec warning', () {
      const raw = '{"leaks": [{"start": 0, "end": 5, "kind": "coreference", '
          '"reason": "x", "confidence": 1.5}]}';
      final parsed = parseLeakSpansJson(raw, textLength: textLen);
      expect(parsed.leaks.single.confidence, 1.0);
      expect(parsed.warnings.single, contains('clampée'));
    });

    test('champ "leaks" manquant lève', () {
      expect(
        () => parseLeakSpansJson('{"other": []}', textLength: textLen),
        throwsA(isA<LlmJsonParseException>()),
      );
    });
  });
}
