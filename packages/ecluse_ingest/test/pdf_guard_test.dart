import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:ecluse_ingest/src/pdf/pdf_guard.dart';
import 'package:ecluse_ingest/src/pdf/pdf_text_source.dart';
import 'package:test/test.dart';

/// Source factice : le garde-fou se teste sans bibliothèque PDF.
final class _FakeDoc implements PdfOpenDocument {
  _FakeDoc(this.pages,
      {this.encrypted = false, this.extras = const PdfExtras()});

  final List<PdfPageInfo> pages;
  final bool encrypted;

  @override
  final PdfExtras extras;

  @override
  bool get isEncrypted => encrypted;

  @override
  int get pageCount => pages.length;

  @override
  PdfPageInfo page(int index) => pages[index];
}

final class _FakeSource implements PdfTextSource {
  _FakeSource(this.doc);

  final PdfOpenDocument doc;

  @override
  PdfOpenDocument open(Uint8List bytes) => doc;
}

PdfPageInfo _text(String text, {bool image = false}) => PdfPageInfo(
      text: text,
      hasContent: true,
      hasImage: image,
      hasInvisibleText: false,
      hasTextOperators: true,
    );

const _blank = PdfPageInfo(
  text: '',
  hasContent: false,
  hasImage: false,
  hasInvisibleText: false,
);

const _scan = PdfPageInfo(
  text: '',
  hasContent: true,
  hasImage: true,
  hasInvisibleText: false,
);

/// Octets dotés d'une structure minimale acceptée par le contrôle préalable
/// (en-tête, `startxref` vers `xref`, `%%EOF`).
Uint8List get _wellFormed {
  const body = '%PDF-1.4\n';
  final xrefAt = body.length;
  return Uint8List.fromList(
    utf8.encode('${body}xref\n0 1\n0000000000 65535 f \n'
        'trailer\n<< /Size 1 >>\nstartxref\n$xrefAt\n%%EOF\n'),
  );
}

const _long = 'Texte de page suffisamment long pour dépasser le seuil.';

IngestResult _run(List<PdfPageInfo> pages,
        {bool encrypted = false,
        PdfLimits limits = const PdfLimits(),
        PdfExtras extras = const PdfExtras(),
        Stopwatch? clock}) =>
    ingestPdf(_wellFormed,
        source:
            _FakeSource(_FakeDoc(pages, encrypted: encrypted, extras: extras)),
        limits: limits,
        clock: clock);

String? _code(IngestResult r) => (r as IngestRefused).code;

void main() {
  group('fuzzing', fuzzSuite);
  group('garde-fou PDF — acceptation', () {
    test('pages de texte : concaténées par une ligne vide', () {
      final r = _run([_text(_long), _text('$_long Deux.')]) as IngestedText;
      expect(r.text, '$_long\n\n$_long Deux.');
      expect(r.format, IngestFormat.pdf);
      expect(r.warnings, isEmpty);
    });

    test('page courte mais purement textuelle (« Fin ») : acceptée', () {
      final r = _run([_text(_long), _text('Fin')]) as IngestedText;
      expect(r.text, endsWith('Fin'));
    });

    test('page blanche : acceptée et signalée', () {
      final r = _run([_text(_long), _blank]) as IngestedText;
      expect(r.warnings, ['pages_blanches:1']);
    });

    test('texte + image : accepté avec avertissement par page', () {
      final r = _run([_text(_long), _text(_long, image: true)]) as IngestedText;
      expect(r.warnings, ['images_non_traitees:2']);
    });

    test('éléments hors texte : un avertissement chacun', () {
      final r = _run(
        [_text(_long)],
        extras: const PdfExtras(
          hasMetadata: true,
          hasAnnotations: true,
          hasForms: true,
          hasJavaScript: true,
        ),
      ) as IngestedText;
      expect(r.warnings, [
        'metadonnees_non_extraites',
        'annotations_non_extraites',
        'formulaires_non_extraits',
        'javascript_ignore',
      ]);
    });

    test('accents, œ, euro, guillemets, ligatures : texte attendu', () {
      final r = _run([_text('Rémunération « œuvre » 12 € — ﬁn ﬂux, déjà là.')]);
      expect(r, isA<IngestedText>());
    });
  });

  group('garde-fou PDF — refus', () {
    test('scan pur : sans_texte', () {
      expect(_code(_run([_scan])), pdfRefusalNoText);
      expect(_code(_run([_scan, _scan])), pdfRefusalNoText);
    });

    test('toutes pages blanches : sans_texte (rien n\'a été lu)', () {
      expect(_code(_run([_blank, _blank])), pdfRefusalNoText);
    });

    test('mixte : refus du document entier, pages listées', () {
      final r = _run([_text(_long), _scan, _scan]) as IngestRefused;
      expect(r.code, pdfRefusalPartial);
      expect(r.reason, contains('2, 3'));
    });

    test('image + quelques caractères : sans_texte', () {
      expect(_code(_run([_text('p. 1', image: true)])), pdfRefusalNoText);
    });

    test('couche OCR invisible (3 Tr) : refusé même avec du texte', () {
      const ocr = PdfPageInfo(
        text: _long,
        hasContent: true,
        hasImage: true,
        hasInvisibleText: true,
      );
      expect(_code(_run([ocr])), pdfRefusalOcrLayer);
    });

    test('texte affiché mais extraction vide (police sans ToUnicode)', () {
      const empty = PdfPageInfo(
        text: '',
        hasContent: true,
        hasImage: false,
        hasInvisibleText: false,
        hasTextOperators: true,
      );
      expect(_code(_run([_text(_long), empty])), pdfRefusalUnreadableText);
    });

    test('caractères de zone privée / U+FFFD : texte_illisible', () {
      final pua = String.fromCharCodes(List.filled(60, 0xE041));
      expect(_code(_run([_text(pua)])), pdfRefusalUnreadableText);
      final fffd = String.fromCharCodes(List.filled(60, 0xFFFD));
      expect(_code(_run([_text(fffd)])), pdfRefusalUnreadableText);
    });

    test('lettres latines étendues sans rapport (bruit) : texte_illisible', () {
      // 100 % de lettres, aucun U+FFFD ni zone privée : le critère du spec
      // §3 seul laisserait passer ce bruit.
      final noise = String.fromCharCodes(
        List.generate(80, (i) => 0x100 + (i % 0x40)),
      );
      expect(_code(_run([_text(noise)])), pdfRefusalUnreadableText);
    });

    test('chiffré (ouverture sans mot de passe possible ou non)', () {
      expect(_code(_run([_text(_long)], encrypted: true)), pdfRefusalEncrypted);
    });

    test('plafond de pages', () {
      final pages = List.filled(201, _text(_long));
      expect(_code(_run(pages)), pdfRefusalTooManyPages);
      expect(_run(List.filled(200, _text(_long))), isA<IngestedText>());
    });

    test('plafond de taille, avant toute lecture', () {
      final r = ingestPdf(
        Uint8List(101),
        limits: const PdfLimits(maxBytes: 100),
      );
      expect(_code(r), pdfRefusalTooLarge);
    });

    test('plafond de durée : contrôlé entre les pages (horloge injectée)', () {
      final clock = _SlowClock();
      final r = _run(
        List.filled(5, _text(_long)),
        limits: const PdfLimits(timeout: Duration(seconds: 1)),
        clock: clock,
      );
      expect(_code(r), pdfRefusalTooSlow);
    });

    test('zéro page : refusé', () {
      expect(_code(_run([])), pdfRefusalNoText);
    });

    test('mot de passe requis à l\'ouverture : chiffré', () {
      final r = ingestPdf(
        _wellFormed,
        source: _ThrowingSource(const PdfSourceException(encrypted: true)),
      );
      expect(_code(r), pdfRefusalEncrypted);
    });

    test('bibliothèque en échec : malformé, sans citer l\'erreur', () {
      final r = ingestPdf(
        _wellFormed,
        source: _ThrowingSource(const PdfSourceException()),
      ) as IngestRefused;
      expect(r.code, pdfRefusalMalformed);
    });
  });

  group('contrôle de structure préalable', () {
    test('pas d\'en-tête %PDF-', () {
      expect(
          _code(ingestPdf(utf8.encode('juste du texte'))), pdfRefusalMalformed);
    });

    test('pas de %%EOF', () {
      expect(_code(ingestPdf(utf8.encode('%PDF-1.4\nstartxref\n9\n'))),
          pdfRefusalMalformed);
    });

    test('startxref hors du fichier ou pointant ailleurs que sur xref', () {
      expect(_code(ingestPdf(utf8.encode('%PDF-1.4\nstartxref\n9999\n%%EOF'))),
          pdfRefusalMalformed);
      expect(_code(ingestPdf(utf8.encode('%PDF-1.4\nstartxref\n2\n%%EOF'))),
          pdfRefusalMalformed);
    });
  });

  group('jeu synthétique : offsets des identifiants', () {
    test('un NIR du PDF est retrouvé à la même position dans le texte extrait',
        () {
      final expected = jsonDecode(
        File('../../bench/pdf/expected.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final files = expected['fichiers'] as Map<String, dynamic>;
      final spec = files['texte_simple.pdf'] as Map<String, dynamic>;
      final entities = (spec['entites'] as List).cast<Map<String, dynamic>>();
      final nir =
          entities.firstWhere((e) => e['type'] == 'nir')['affiche'] as String;
      final r = ingestFile(
        File('../../bench/pdf/texte_simple.pdf').readAsBytesSync(),
        filename: 'texte_simple.pdf',
      ) as IngestedText;
      final at = r.text.indexOf(nir);
      expect(at, isNonNegative);
      expect(r.text.substring(at, at + nir.length), nir);
      expect(r.warnings, isEmpty);
    });
  });
}

final class _ThrowingSource implements PdfTextSource {
  _ThrowingSource(this.error);

  final PdfSourceException error;

  @override
  PdfOpenDocument open(Uint8List bytes) => throw error;
}

/// Chronomètre dont le temps écoulé dépasse toujours le plafond.
final class _SlowClock implements Stopwatch {
  @override
  Duration get elapsed => const Duration(seconds: 60);
  @override
  int get elapsedMicroseconds => 60 * 1000000;
  @override
  int get elapsedMilliseconds => 60 * 1000;
  @override
  int get elapsedTicks => 60;
  @override
  int get frequency => 1;
  @override
  bool get isRunning => true;
  @override
  void reset() {}
  @override
  void start() {}
  @override
  void stop() {}
}

/// Fuzzing minimal, déterministe : un PDF tronqué ou corrompu donne un refus
/// ou un texte, jamais une exception, jamais un texte vide.
void fuzzSuite() {
  test('mutations déterministes de texte_simple.pdf : jamais d\'exception', () {
    final original = File('../../bench/pdf/texte_simple.pdf').readAsBytesSync();
    var seed = 42;
    int next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    for (var i = 0; i < 300; i++) {
      final bytes = Uint8List.fromList(original);
      switch (i % 3) {
        case 0: // troncature
          final cut = next() % bytes.length;
          final r = ingestFile(bytes.sublist(0, cut), filename: 'x.pdf');
          _expectSound(r);
        case 1: // octets inversés
          for (var k = 0; k < 8; k++) {
            bytes[next() % bytes.length] = next() & 0xFF;
          }
          _expectSound(ingestFile(bytes, filename: 'x.pdf'));
        default: // plage effacée
          final from = next() % bytes.length;
          final to = (from + next() % 200).clamp(0, bytes.length);
          bytes.fillRange(from, to, 0);
          _expectSound(ingestFile(bytes, filename: 'x.pdf'));
      }
    }
  });
}

void _expectSound(IngestResult r) {
  if (r is IngestedText) {
    expect(r.text.trim(), isNotEmpty);
  } else {
    expect((r as IngestRefused).reason, isNotEmpty);
  }
}
