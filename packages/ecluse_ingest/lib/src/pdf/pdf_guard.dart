import 'dart:typed_data';

import '../ingest_result.dart';
import 'pdf_graphics_source.dart';
import 'pdf_text_source.dart';

/// Plafonds et seuils de départ (spec P1-09 §3-4), à recalibrer sur
/// `bench/pdf/`. Valeurs de départ proposées, pas des mesures.
final class PdfLimits {
  const PdfLimits({
    this.maxBytes = 50 * 1024 * 1024,
    this.maxPages = 200,
    this.timeout = const Duration(seconds: 30),
    this.minAlnumPerTextPage = 20,
    this.maxStrayRatio = 0.05,
    this.minLetterDigitRatio = 0.5,
  });

  /// Taille du fichier (50 Mo, comme `maxSafeZipEntryBytes`).
  final int maxBytes;

  /// Nombre de pages au-delà duquel le document est refusé.
  final int maxPages;

  /// Durée d'extraction. Vérifiée **entre** les pages : une seule page ne
  /// peut pas être interrompue (extraction synchrone).
  final Duration timeout;

  /// Caractères alphanumériques à partir desquels une page « a du texte ».
  final int minAlnumPerTextPage;

  /// Part maximale de caractères parasites (U+FFFD, zone privée, contrôle,
  /// ou hors du jeu attendu d'un texte français) dans le texte d'une page.
  final double maxStrayRatio;

  /// Part minimale de lettres/chiffres parmi les caractères non blancs.
  final double minLetterDigitRatio;
}

// Motifs de refus : constantes stables, reprises dans bench/pdf/expected.json.
const String pdfRefusalNoText = 'sans_texte';
const String pdfRefusalPartial = 'partiellement_numerise';
const String pdfRefusalUnreadableText = 'texte_illisible';
const String pdfRefusalEncrypted = 'chiffre';
const String pdfRefusalMalformed = 'malforme';
const String pdfRefusalTooManyPages = 'plafond_pages';
const String pdfRefusalTooLarge = 'plafond_taille';
const String pdfRefusalTooSlow = 'plafond_duree';
const String pdfRefusalOcrLayer = 'numerise_couche_ocr';

/// Refus d'un PDF : [code] est le motif stable, [reason] le message affiché.
IngestRefused _refuse(String code, String message) =>
    IngestRefused(message, code: code);

/// Ingère un PDF. Principe (spec P1-09 §3) : accepté seulement si l'on peut
/// affirmer que **tout son contenu informatif est du texte lu** ; sinon le
/// document entier est refusé avec un motif. Jamais un texte vide.
///
/// [source] et [limits] sont injectables pour les tests ; [clock] aussi
/// (aucun test ne dépend de l'heure réelle).
IngestResult ingestPdf(
  List<int> bytes, {
  PdfTextSource source = const PdfGraphicsTextSource(),
  PdfLimits limits = const PdfLimits(),
  Stopwatch? clock,
}) {
  if (bytes.length > limits.maxBytes) {
    return _refuse(
      pdfRefusalTooLarge,
      'PDF trop volumineux (plafond : ${limits.maxBytes ~/ (1024 * 1024)} Mo) : '
      'document refusé.',
    );
  }
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  final structure = _checkStructure(data);
  if (structure != null) return structure;

  final watch = clock ?? (Stopwatch()..start());

  final PdfOpenDocument doc;
  try {
    doc = source.open(data);
  } on PdfSourceException catch (e) {
    return e.encrypted ? _encrypted() : _malformed();
  }
  if (doc.isEncrypted) return _encrypted();

  final int pageCount;
  try {
    pageCount = doc.pageCount;
  } catch (_) {
    return _malformed();
  }
  if (pageCount > limits.maxPages) {
    return _refuse(
      pdfRefusalTooManyPages,
      'PDF de $pageCount pages (plafond : ${limits.maxPages}) : document '
      'refusé.',
    );
  }
  if (pageCount == 0) {
    return _refuse(
      pdfRefusalNoText,
      'PDF sans page : rien n\'a pu être lu, document refusé.',
    );
  }

  final texts = <String>[];
  final pagesWithoutText = <int>[]; // numéros de page, à partir de 1
  final imageOnTextPages = <int>[];
  var blankPages = 0;

  for (var i = 0; i < pageCount; i++) {
    if (watch.elapsed > limits.timeout) {
      return _refuse(
        pdfRefusalTooSlow,
        'Lecture du PDF trop longue (plafond : ${limits.timeout.inSeconds} s) '
        ': document refusé.',
      );
    }
    final PdfPageInfo page;
    try {
      page = doc.page(i);
    } catch (_) {
      return _malformed();
    }

    if (page.hasInvisibleText) {
      return _refuse(
        pdfRefusalOcrLayer,
        'PDF numérisé avec une couche de texte issue d\'une reconnaissance '
        'de caractères : Écluse ne traite pas les scans. Document refusé.',
      );
    }

    final alnum = _alnumCount(page.text);
    final quality = _textQuality(page.text, limits);
    if (alnum >= limits.minAlnumPerTextPage) {
      if (!quality) {
        return _refuse(
          pdfRefusalUnreadableText,
          'Texte du PDF illisible (encodage de polices) : document refusé.',
        );
      }
      if (page.hasImage) imageOnTextPages.add(i + 1);
      texts.add(page.text);
    } else if (!page.hasContent) {
      blankPages++; // page blanche : ni texte, ni image, ni tracé
    } else if (page.text.trim().isNotEmpty && !page.hasImage && quality) {
      // Page courte mais entièrement textuelle (« Fin », numéro de page) :
      // rien n'y est resté non lu.
      texts.add(page.text);
    } else if (page.text.trim().isNotEmpty && !quality) {
      // Quelques caractères, mais parasites (U+FFFD, zone privée).
      return _refuse(
        pdfRefusalUnreadableText,
        'Texte du PDF illisible (encodage de polices) : document refusé.',
      );
    } else if (page.hasTextOperators &&
        page.text.trim().isEmpty &&
        !page.hasImage) {
      // La page affiche du texte mais l'extracteur n'en a rien tiré : police
      // sans table ToUnicode. Texte non vide ≠ texte lu, et ici il est vide.
      return _refuse(
        pdfRefusalUnreadableText,
        'Texte du PDF illisible (encodage de polices) : document refusé.',
      );
    } else {
      pagesWithoutText.add(i + 1);
    }
  }

  if (pagesWithoutText.isNotEmpty) {
    if (texts.isEmpty) {
      return _refuse(
        pdfRefusalNoText,
        'PDF sans texte exploitable (scan ou image) : Écluse ne traite pas '
        'les images. Document refusé.',
      );
    }
    return _refuse(
      pdfRefusalPartial,
      'PDF partiellement numérisé : les pages ${pagesWithoutText.join(', ')} '
      'ne contiennent pas de texte exploitable. Le document est refusé en '
      'entier.',
    );
  }
  if (texts.isEmpty) {
    return _refuse(
      pdfRefusalNoText,
      'PDF sans texte exploitable (aucune page lue) : document refusé.',
    );
  }

  final extras = doc.extras;
  return IngestedText(
    text: texts.join('\n\n'),
    format: IngestFormat.pdf,
    warnings: [
      if (imageOnTextPages.isNotEmpty)
        'images_non_traitees:${imageOnTextPages.join(',')}',
      if (extras.hasMetadata) 'metadonnees_non_extraites',
      if (extras.hasAnnotations) 'annotations_non_extraites',
      if (extras.hasForms) 'formulaires_non_extraits',
      if (extras.hasJavaScript) 'javascript_ignore',
      if (blankPages > 0) 'pages_blanches:$blankPages',
    ],
  );
}

IngestRefused _encrypted() =>
    _refuse(pdfRefusalEncrypted, 'PDF chiffré : document refusé.');

IngestRefused _malformed() => _refuse(
      pdfRefusalMalformed,
      'PDF illisible ou malformé : document refusé.',
    );

/// Contrôle de structure **avant** la bibliothèque : les lecteurs courants
/// reconstruisent un PDF tronqué ou à table `xref` cassée et en tirent du
/// texte. Écluse ne lit que ce qu'elle peut affirmer avoir lu en entier :
/// une structure cassée est un refus (politique, règle n°4 de `CLAUDE.md`).
IngestRefused? _checkStructure(Uint8List data) {
  final head = String.fromCharCodes(
    data.sublist(0, data.length < 1024 ? data.length : 1024),
  );
  if (!head.contains('%PDF-')) return _malformed();

  final tailStart = data.length > 2048 ? data.length - 2048 : 0;
  final tail = String.fromCharCodes(data.sublist(tailStart));
  if (!tail.contains('%%EOF')) return _malformed();
  final match = RegExp(r'startxref\s+(\d+)').allMatches(tail).lastOrNull;
  if (match == null) return _malformed();
  final offset = int.tryParse(match.group(1)!);
  if (offset == null || offset < 0 || offset >= data.length) {
    return _malformed();
  }
  final at = String.fromCharCodes(
    data.sublist(offset, offset + 64 > data.length ? data.length : offset + 64),
  );
  // Table classique (`xref`) ou flux de références (`N G obj`).
  if (!RegExp(r'^\s*(xref|\d+\s+\d+\s+obj)').hasMatch(at)) return _malformed();
  return null;
}

int _alnumCount(String text) {
  var n = 0;
  for (final r in text.runes) {
    if (_isLetterOrDigit(r)) n++;
  }
  return n;
}

bool _isLetterOrDigit(int r) =>
    (r >= 0x30 && r <= 0x39) ||
    (r >= 0x41 && r <= 0x5A) ||
    (r >= 0x61 && r <= 0x7A) ||
    (r >= 0xC0 && r <= 0x24F && r != 0xD7 && r != 0xF7) ||
    r == 0x153 ||
    r == 0x152;

/// Jeu de caractères attendu dans un texte français : ASCII imprimable,
/// Latin-1 (accents, espace insécable), œ/Œ/Ÿ, ponctuation typographique,
/// euro, ligatures `fi`/`fl`. Tout le reste — Latin étendu A hors œ,
/// zone privée, U+FFFD — compte comme parasite : c'est ce qui trahit une
/// police sans table `ToUnicode` même quand le bruit ressemble à des lettres.
bool _isExpected(int r) =>
    r == 0x09 ||
    r == 0x0A ||
    r == 0x0D ||
    r == 0x0C ||
    (r >= 0x20 && r <= 0x7E) ||
    (r >= 0xA0 && r <= 0xFF) ||
    r == 0x152 ||
    r == 0x153 ||
    r == 0x178 ||
    (r >= 0x2010 && r <= 0x206F) ||
    r == 0x20AC ||
    r == 0xFB01 ||
    r == 0xFB02;

bool _textQuality(String text, PdfLimits limits) {
  var nonBlank = 0;
  var stray = 0;
  var letterDigit = 0;
  for (final r in text.runes) {
    if (r == 0x20 || r == 0xA0 || r == 0x09 || r == 0x0A || r == 0x0D) {
      continue;
    }
    nonBlank++;
    if (!_isExpected(r)) stray++;
    if (_isLetterOrDigit(r)) letterDigit++;
  }
  if (nonBlank == 0) return true;
  return stray / nonBlank <= limits.maxStrayRatio &&
      letterDigit / nonBlank >= limits.minLetterDigitRatio;
}
