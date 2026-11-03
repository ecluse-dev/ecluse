import 'dart:typed_data';

import 'package:pdf_cos/pdf_cos.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import 'pdf_text_source.dart';

/// Implémentation de [PdfTextSource] sur `pdf_graphics` (version fixée).
///
/// Les seuls appels à la bibliothèque du dépôt sont ici.
final class PdfGraphicsTextSource implements PdfTextSource {
  const PdfGraphicsTextSource();

  @override
  PdfOpenDocument open(Uint8List bytes) {
    try {
      return _Open(PdfDocument.open(bytes));
    } on CosPasswordException {
      throw const PdfSourceException(encrypted: true);
    } catch (_) {
      // Le message d'erreur d'une bibliothèque peut citer du contenu.
      throw const PdfSourceException();
    }
  }
}

/// Mode de rendu invisible (`3 Tr`), comme le fait la détection de scans de
/// `pdf_graphics`.
/// `/Nom Do` : dessin d'un XObject.
final RegExp _doOperator = RegExp(r'/([^\s/<>\[\]()%]+)\s+Do(?![A-Za-z])');

/// Opérateurs d'affichage de texte.
final RegExp _showText = RegExp(r'(^|[\s\]\)>])(Tj|TJ)(?![A-Za-z])');

final RegExp _invisibleText = RegExp(r'(^|[\s\]\)>])3\s+Tr(?![A-Za-z])');

final class _Open implements PdfOpenDocument {
  _Open(this._doc);

  final PdfDocument _doc;

  @override
  bool get isEncrypted => _doc.cos.isEncrypted;

  @override
  int get pageCount => _doc.pageCount;

  @override
  PdfExtras get extras {
    final cos = _doc.cos;
    final catalog = _doc.catalog;
    var annotations = false;
    try {
      for (var i = 0; i < _doc.pageCount && !annotations; i++) {
        annotations = _doc.page(i).annotations.isNotEmpty;
      }
    } catch (_) {
      // Une page dont les annotations sont illisibles est comptée comme en
      // ayant : on avertit plutôt que de se taire.
      annotations = true;
    }
    final names = cos.resolve(catalog['Names']);
    final openAction = cos.resolve(catalog['OpenAction']);
    final aa = cos.resolve(catalog['AA']);
    final javascript =
        (names is CosDictionary && names.containsKey('JavaScript')) ||
            (openAction is CosDictionary && openAction.containsKey('JS')) ||
            aa is CosDictionary;
    return PdfExtras(
      hasMetadata: _doc.info.values.any((v) => v.trim().isNotEmpty),
      hasAnnotations: annotations,
      hasForms: cos.resolve(catalog['AcroForm']) is CosDictionary,
      hasJavaScript: javascript,
    );
  }

  @override
  PdfPageInfo page(int index) {
    final page = _doc.page(index);
    final content = page.contentBytes();
    return PdfPageInfo(
      text: PdfTextExtractor.extract(_doc, index).text,
      hasContent: content.any((b) => b > 0x20),
      hasImage: _drawsImage(page, content),
      hasInvisibleText: _invisibleText.hasMatch(String.fromCharCodes(content)),
      hasTextOperators: _showText.hasMatch(String.fromCharCodes(content)),
    );
  }

  /// La page **dessine** une image : un opérateur `Do` dont le nom désigne
  /// un XObject de sous-type `Image`, ou une image en ligne. Un XObject
  /// simplement déclaré dans les ressources, mais jamais dessiné, ne compte
  /// pas (sinon tout PDF produit par un outil qui déclare ses ressources en
  /// bloc serait signalé à tort).
  bool _drawsImage(PdfPage page, Uint8List content) {
    final cos = _doc.cos;
    final xObjects = cos.resolve(page.resources['XObject']);
    if (xObjects is CosDictionary) {
      final source = String.fromCharCodes(content);
      for (final m in _doOperator.allMatches(source)) {
        final entry = xObjects[m.group(1)!];
        if (entry == null) continue;
        final object = cos.resolve(entry);
        if (object is CosStream) {
          final subtype = object.dictionary['Subtype'];
          if (subtype is CosName && subtype.value == 'Image') return true;
        }
      }
    }
    return _hasInlineImage(content);
  }

  /// Opérateur `BI` (image en ligne) isolé par des blancs.
  static bool _hasInlineImage(Uint8List c) {
    bool blank(int b) =>
        b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09 || b == 0x0C;
    for (var i = 0; i + 1 < c.length; i++) {
      if (c[i] == 0x42 &&
          c[i + 1] == 0x49 &&
          (i == 0 || blank(c[i - 1])) &&
          (i + 2 >= c.length || blank(c[i + 2]))) {
        return true;
      }
    }
    return false;
  }
}
