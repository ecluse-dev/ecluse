import 'package:ecluse_llm_onnx/ecluse_llm_onnx.dart';
import 'package:test/test.dart';

void main() {
  group('WhitespaceTokenizer (stub)', () {
    test('roundtrip encode/decode sur tokens simples', () {
      final tok = WhitespaceTokenizer();
      final ids = tok.encode('bonjour monde', addSpecialTokens: false);
      expect(ids, hasLength(2));
      final text = tok.decode(ids, skipSpecialTokens: true);
      expect(text, 'bonjour monde');
      tok.close();
    });

    test('tokens spéciaux réservés et distincts', () {
      final tok = WhitespaceTokenizer();
      expect(tok.bosTokenId, isNot(tok.eosTokenId));
      expect(tok.bosTokenId, isNot(tok.padTokenId));
      tok.close();
    });

    test('addSpecialTokens=true encadre par BOS/EOS', () {
      final tok = WhitespaceTokenizer();
      final ids = tok.encode('salut', addSpecialTokens: true);
      expect(ids.first, tok.bosTokenId);
      expect(ids.last, tok.eosTokenId);
      tok.close();
    });

    test('skipSpecialTokens=true les retire du décodage', () {
      final tok = WhitespaceTokenizer();
      final ids = tok.encode('salut', addSpecialTokens: true);
      final withSpecials = tok.decode(ids, skipSpecialTokens: false);
      final withoutSpecials = tok.decode(ids, skipSpecialTokens: true);
      expect(withSpecials, contains('<bos>'));
      expect(withoutSpecials, isNot(contains('<bos>')));
      tok.close();
    });

    test('vocabSize croît avec de nouveaux tokens', () {
      final tok = WhitespaceTokenizer();
      final baseline = tok.vocabSize;
      tok.encode('nouveau vocabulaire', addSpecialTokens: false);
      expect(tok.vocabSize, greaterThan(baseline));
      tok.close();
    });
  });
}
