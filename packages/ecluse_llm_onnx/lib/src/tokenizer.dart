/// Interface tokenizer minimale attendue par la boucle de génération.
///
/// Toute implémentation concrète doit être capable de :
///   - encoder une string en `List<int>` d'IDs de tokens ;
///   - décoder une `List<int>` en string ;
///   - exposer les tokens spéciaux (BOS, EOS, PAD).
abstract interface class Tokenizer {
  List<int> encode(String text, {bool addSpecialTokens = true});

  String decode(List<int> tokenIds, {bool skipSpecialTokens = true});

  int get bosTokenId;
  int get eosTokenId;
  int? get padTokenId;

  /// Taille du vocabulaire.
  int get vocabSize;

  void close();
}

/// Stub minimal pour développer sans binder SentencePiece.
///
/// Découpe naïve mots+ponctuation, vocab construit à la volée.
/// **À NE PAS UTILISER EN PRODUCTION** — les IDs générés n'ont aucune
/// correspondance avec ceux d'un vrai modèle.
class WhitespaceTokenizer implements Tokenizer {
  WhitespaceTokenizer() {
    // Réserve les tokens spéciaux.
    _idOf('<pad>');
    _idOf('<bos>');
    _idOf('<eos>');
  }

  final Map<String, int> _vocab = <String, int>{};
  final List<String> _rev = <String>[];

  int _idOf(String tok) {
    return _vocab.putIfAbsent(tok, () {
      final id = _rev.length;
      _rev.add(tok);
      return id;
    });
  }

  @override
  List<int> encode(String text, {bool addSpecialTokens = true}) {
    final parts = text
        .split(RegExp(r"(\s+|[.,;:!?()\[\]{}])"))
        .where((s) => s.isNotEmpty && s.trim().isNotEmpty);
    final ids = <int>[];
    if (addSpecialTokens) ids.add(bosTokenId);
    for (final p in parts) {
      ids.add(_idOf(p));
    }
    if (addSpecialTokens) ids.add(eosTokenId);
    return ids;
  }

  @override
  String decode(List<int> tokenIds, {bool skipSpecialTokens = true}) {
    final sb = StringBuffer();
    for (final id in tokenIds) {
      if (id < 0 || id >= _rev.length) continue;
      final tok = _rev[id];
      if (skipSpecialTokens &&
          (tok == '<pad>' || tok == '<bos>' || tok == '<eos>')) {
        continue;
      }
      if (sb.isNotEmpty) sb.write(' ');
      sb.write(tok);
    }
    return sb.toString();
  }

  @override
  int get bosTokenId => _vocab['<bos>']!;

  @override
  int get eosTokenId => _vocab['<eos>']!;

  @override
  int? get padTokenId => _vocab['<pad>'];

  @override
  int get vocabSize => _rev.length;

  @override
  void close() {}
}

/// Interface à implémenter pour un vrai tokenizer SentencePiece.
///
/// TODO(integration): créer `SentencePieceTokenizer` qui charge un
/// fichier `.spm` via FFI. Réutiliser le binding déjà mis en place dans
/// `ecluse_ner_onnx` si compatible.
class SentencePieceTokenizerNotImplemented implements Tokenizer {
  @override
  List<int> encode(String text, {bool addSpecialTokens = true}) =>
      throw UnimplementedError('SentencePiece binding à intégrer');
  @override
  String decode(List<int> tokenIds, {bool skipSpecialTokens = true}) =>
      throw UnimplementedError('SentencePiece binding à intégrer');
  @override
  int get bosTokenId => throw UnimplementedError();
  @override
  int get eosTokenId => throw UnimplementedError();
  @override
  int? get padTokenId => throw UnimplementedError();
  @override
  int get vocabSize => throw UnimplementedError();
  @override
  void close() {}
}
