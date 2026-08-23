import 'dart:convert';

import 'package:ecluse_ocr/ecluse_ocr.dart';

/// Convertit la réponse JSON du sidecar Docling en `OcrPage`.
///
/// Format de réponse attendu (produit par `sidecar/app.py`) :
/// ```json
/// {
///   "pages": [
///     {
///       "index": 0,
///       "width": 2480,
///       "height": 3508,
///       "regions": [
///         {
///           "id": "r1",
///           "kind": "line" | "paragraph" | "table_cell" | "heading",
///           "parent_id": null,
///           "box": {"x": 100, "y": 200, "w": 300, "h": 30},
///           "tokens": [
///             {"text": "...", "conf": 0.98,
///              "box": {"x": 100, "y": 200, "w": 40, "h": 30}}
///           ]
///         }
///       ]
///     }
///   ]
/// }
/// ```
class DoclingParser {
  const DoclingParser();

  List<OcrPage> parse(String rawJson) {
    final Object? decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('racine attendue : objet JSON');
    }
    final pagesList = decoded['pages'];
    if (pagesList is! List) {
      throw const FormatException('champ "pages" attendu : array');
    }

    return List<OcrPage>.generate(
      pagesList.length,
      (i) => _parsePage(pagesList[i] as Map<String, dynamic>, i),
    );
  }

  OcrPage _parsePage(Map<String, dynamic> data, int fallbackIndex) {
    final pageIndex = (data['index'] as num?)?.toInt() ?? fallbackIndex;
    final width = (data['width'] as num).toInt();
    final height = (data['height'] as num).toInt();

    final regionsRaw = (data['regions'] as List?) ?? const [];
    final regions = <OcrRegion>[];
    for (final r in regionsRaw) {
      if (r is Map) {
        regions.add(_parseRegion(r.cast<String, dynamic>(), pageIndex));
      }
    }

    return OcrPage(
      pageIndex: pageIndex,
      width: width,
      height: height,
      regions: regions,
      sourceEngine: 'docling',
      warnings: List<String>.from((data['warnings'] as List?) ?? const []),
    );
  }

  OcrRegion _parseRegion(Map<String, dynamic> data, int pageIndex) {
    final kind = _parseKind(data['kind'] as String?);
    final tokens = <OcrToken>[];
    final tokensRaw = (data['tokens'] as List?) ?? const [];
    for (final t in tokensRaw) {
      if (t is Map) {
        tokens.add(_parseToken(t.cast<String, dynamic>(), pageIndex));
      }
    }
    return OcrRegion(
      kind: kind,
      tokens: tokens,
      box: _parseBox(data['box'] as Map<String, dynamic>, pageIndex),
      id: data['id'] as String?,
      parentRegionId: data['parent_id'] as String?,
    );
  }

  OcrToken _parseToken(Map<String, dynamic> data, int pageIndex) {
    final rawConf = (data['conf'] as num?)?.toDouble() ?? 1.0;
    return OcrToken(
      text: data['text'] as String,
      confidence: rawConf.clamp(0.0, 1.0),
      box: _parseBox(data['box'] as Map<String, dynamic>, pageIndex),
    );
  }

  BoundingBox _parseBox(Map<String, dynamic> data, int pageIndex) {
    return BoundingBox(
      x: (data['x'] as num).toInt(),
      y: (data['y'] as num).toInt(),
      width: (data['w'] as num).toInt(),
      height: (data['h'] as num).toInt(),
      pageIndex: pageIndex,
    );
  }

  OcrRegionKind _parseKind(String? raw) {
    switch (raw) {
      case 'line':
        return OcrRegionKind.line;
      case 'paragraph':
        return OcrRegionKind.paragraph;
      case 'table_cell':
      case 'cell':
        return OcrRegionKind.tableCell;
      case 'table_row':
      case 'row':
        return OcrRegionKind.tableRow;
      case 'table':
        return OcrRegionKind.table;
      case 'heading':
      case 'title':
        return OcrRegionKind.heading;
      default:
        return OcrRegionKind.other;
    }
  }
}
