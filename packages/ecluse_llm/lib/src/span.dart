import 'package:meta/meta.dart';

/// Représentation minimale d'un span détecté, alignée sur les offsets du
/// texte d'origine.
///
/// TODO(integration): remplacer par `Span` de `ecluse_core` une fois la
/// dépendance activée dans `pubspec.yaml`. Les champs sont volontairement
/// alignés sur la convention `ecluse_ner.NerSpan`.
@immutable
class Span {
  const Span({
    required this.start,
    required this.end,
    required this.label,
    this.source = 'unknown',
    this.confidence = 1.0,
  })  : assert(start >= 0, 'start must be >= 0'),
        assert(end > start, 'end must be > start'),
        assert(confidence >= 0.0 && confidence <= 1.0, 'confidence in [0,1]');

  /// Offset de début, inclusif, dans le texte d'origine (unités de code UTF-16).
  final int start;

  /// Offset de fin, exclusif.
  final int end;

  /// Étiquette sémantique (`NOM`, `PRENOM`, `NIR`, `EMAIL`, …).
  final String label;

  /// Origine du span (`structural`, `ner`, `llm`, `heuristic`, …).
  ///
  /// Utilisé par `resolveOverlaps` pour arbitrer les recouvrements.
  final String source;

  /// Confiance [0, 1] fournie par le détecteur.
  final double confidence;

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is Span &&
      other.start == start &&
      other.end == end &&
      other.label == label &&
      other.source == source &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(start, end, label, source, confidence);

  @override
  String toString() =>
      'Span($start-$end, $label, source=$source, conf=$confidence)';
}
