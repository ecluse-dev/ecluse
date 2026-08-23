import 'package:meta/meta.dart';

import 'span.dart';

/// Nature d'une fuite résiduelle détectée par le LLM sur le texte anonymisé.
enum LeakKind {
  /// Quasi-identifiant sémantique : « le chef de service qui a démissionné
  /// en mars », « la seule pédiatre de Vesoul ».
  semanticQuasiIdentifier,

  /// Coréférence non résolue par les détecteurs précédents : « elle »,
  /// « ce dernier », « son frère »...
  coreference,

  /// Ambiguïté résolue vers du PII : un token qu'un détecteur pensait
  /// bénin s'avère identifiant en contexte.
  ambiguityResolvedToPii,

  /// Fuite contextuelle plus large (structure d'agenda, indice temporel
  /// unique, particularité rare...).
  contextualLeak,

  /// Le LLM signale une entité mais ne sait pas la classer.
  unknown,
}

/// Fuite proposée par le LLM vérificateur.
///
/// Distincte de [Span] car elle porte un `reason` en langage naturel et un
/// [LeakKind]. Elle sera convertie en [Span] côté engine (source = 'llm')
/// avant fusion via `resolveOverlaps`.
@immutable
class LeakSpan {
  const LeakSpan({
    required this.start,
    required this.end,
    required this.kind,
    required this.reason,
    this.confidence = 0.5,
  })  : assert(start >= 0),
        assert(end > start),
        assert(confidence >= 0.0 && confidence <= 1.0);

  final int start;
  final int end;
  final LeakKind kind;

  /// Explication en langage naturel, telle que retournée par le LLM.
  /// Utile pour le `reid_trace` et pour l'auditabilité.
  final String reason;

  /// Confiance rapportée par le LLM. **À prendre avec précaution** : les
  /// LLM auto-évaluent mal. Sert de signal, pas de vérité.
  final double confidence;

  /// Convertit en [Span] pour intégration dans le pipeline `EcluseEngine`.
  Span toSpan({String label = 'LLM_LEAK'}) => Span(
        start: start,
        end: end,
        label: label,
        source: 'llm',
        confidence: confidence,
      );

  @override
  bool operator ==(Object other) =>
      other is LeakSpan &&
      other.start == start &&
      other.end == end &&
      other.kind == kind &&
      other.reason == reason &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(start, end, kind, reason, confidence);

  @override
  String toString() =>
      'LeakSpan($start-$end, $kind, conf=$confidence, "$reason")';
}
