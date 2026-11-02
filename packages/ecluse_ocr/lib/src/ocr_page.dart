import 'package:meta/meta.dart';

import 'bounding_box.dart';

/// Un token OCR : plus petite unité extraite, avec sa confiance et
/// sa position dans l'image.
@immutable
class OcrToken {
  const OcrToken({
    required this.text,
    required this.confidence,
    required this.box,
  }) : assert(confidence >= 0.0 && confidence <= 1.0);

  final String text;

  /// Confiance rapportée par le moteur OCR, dans [0, 1].
  final double confidence;

  final BoundingBox box;

  @override
  bool operator ==(Object other) =>
      other is OcrToken &&
      other.text == text &&
      other.confidence == confidence &&
      other.box == box;

  @override
  int get hashCode => Object.hash(text, confidence, box);

  @override
  String toString() =>
      'OcrToken("$text", conf=${confidence.toStringAsFixed(2)}, $box)';
}

/// Une région logique : ligne, cellule de tableau, paragraphe.
///
/// Le type est indicatif — les moteurs OCR ne l'exposent pas toujours
/// avec fidélité.
enum OcrRegionKind {
  line,
  paragraph,
  tableCell,
  tableRow,
  table,
  heading,
  other
}

@immutable
class OcrRegion {
  const OcrRegion({
    required this.kind,
    required this.tokens,
    required this.box,
    this.parentRegionId,
    this.id,
  });

  final OcrRegionKind kind;
  final List<OcrToken> tokens;
  final BoundingBox box;

  /// Identifiant pour reconstituer la hiérarchie (une cellule pointe vers
  /// une row, une row vers une table).
  final String? id;
  final String? parentRegionId;

  /// Texte concaténé de la région, espacé par un blanc simple.
  String get text => tokens.map((t) => t.text).join(' ');

  /// Confiance minimale des tokens — la plus prudente.
  double get minConfidence => tokens.isEmpty
      ? 1.0
      : tokens.map((t) => t.confidence).reduce(
            (a, b) => a < b ? a : b,
          );

  /// Confiance moyenne des tokens.
  double get avgConfidence {
    if (tokens.isEmpty) return 1.0;
    final sum = tokens.fold<double>(0.0, (a, t) => a + t.confidence);
    return sum / tokens.length;
  }
}

/// Une page extraite : ensemble ordonné de régions.
@immutable
class OcrPage {
  const OcrPage({
    required this.pageIndex,
    required this.width,
    required this.height,
    required this.regions,
    this.sourceEngine = 'unknown',
    this.warnings = const <String>[],
  });

  final int pageIndex;
  final int width;
  final int height;
  final List<OcrRegion> regions;
  final String sourceEngine;
  final List<String> warnings;

  Iterable<OcrToken> get allTokens => regions.expand((r) => r.tokens);
}
