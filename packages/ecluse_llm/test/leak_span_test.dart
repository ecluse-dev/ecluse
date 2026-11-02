import 'package:ecluse_llm/ecluse_llm.dart';
import 'package:test/test.dart';

void main() {
  group('LeakSpan', () {
    test('assert start < end', () {
      expect(
        () => LeakSpan(
          start: 5,
          end: 5,
          kind: LeakKind.coreference,
          reason: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assert confidence dans [0,1]', () {
      expect(
        () => LeakSpan(
          start: 0,
          end: 1,
          kind: LeakKind.coreference,
          reason: 'x',
          confidence: 1.1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toSpan produit un Span source=llm', () {
      final leak = LeakSpan(
        start: 10,
        end: 20,
        kind: LeakKind.contextualLeak,
        reason: 'unique dans la ville',
        confidence: 0.7,
      );
      final span = leak.toSpan();
      expect(span.source, 'llm');
      expect(span.start, 10);
      expect(span.end, 20);
      expect(span.confidence, 0.7);
    });

    test('égalité par valeur', () {
      const a = LeakSpan(
        start: 0,
        end: 3,
        kind: LeakKind.coreference,
        reason: 'x',
      );
      const b = LeakSpan(
        start: 0,
        end: 3,
        kind: LeakKind.coreference,
        reason: 'x',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Span', () {
    test('rejette end <= start', () {
      expect(
        () => Span(start: 5, end: 5, label: 'X'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('length = end - start', () {
      const s = Span(start: 3, end: 10, label: 'X');
      expect(s.length, 7);
    });
  });
}
