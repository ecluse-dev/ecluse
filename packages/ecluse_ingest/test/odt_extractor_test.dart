import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:ecluse_ingest/src/odt_extractor.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

const _mimetype = 'application/vnd.oasis.opendocument.text';

/// Enregistrement de fin de répertoire central (EOCD) valide en
/// apparence (signature correcte, 1 entrée annoncée) mais dont l'offset
/// de répertoire central (999 999) dépasse toute taille de fichier de
/// test plausible — `ZipDecoder` lève une `RangeError` en tentant de le
/// lire, ce qui simule une archive réellement corrompue plutôt qu'une
/// simple absence d'entrées.
const List<int> _eocdWithBogusOffset = [
  0x50, 0x4B, 0x05, 0x06, // signature EOCD
  0x00, 0x00, // numéro de ce disque
  0x00, 0x00, // disque du début du répertoire central
  0x01, 0x00, // entrées sur ce disque
  0x01, 0x00, // entrées au total
  0xE8, 0x03, 0x00, 0x00, // taille du répertoire central (1000)
  0x3F, 0x42, 0x0F, 0x00, // offset du répertoire central (999999)
  0x00, 0x00, // longueur du commentaire
];

List<int> _buildOdtBytes(String contentXml, {String mimetype = _mimetype}) =>
    buildStoredZip({
      'mimetype': mimetype,
      'content.xml': contentXml,
    });

void main() {
  group('ingestOdt — extraction fonctionnelle', () {
    test('.odt valide -> texte extrait de content.xml', () {
      final bytes = _buildOdtBytes(
        '<text:p>Compte rendu de réunion</text:p>'
        '<text:p>Deuxième paragraphe.</text:p>',
      );
      final result = ingestOdt(bytes);
      expect(result, isA<IngestedText>());
      final text = result as IngestedText;
      expect(text.text, 'Compte rendu de réunion\nDeuxième paragraphe.\n');
      expect(text.format, IngestFormat.odt);
    });
  });

  group('ingestOdt — vérifications de refus', () {
    test('signature ZIP absente en tête -> refus', () {
      final result = ingestOdt(
        'Ceci est en fait du texte brut, pas un odt.'.codeUnits,
      );
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('ZIP'));
    });

    test('archive ZIP corrompue -> refus', () {
      // Signature ZIP correcte en tête (pour passer le premier garde-fou),
      // suivie d'un enregistrement de fin de répertoire central (EOCD)
      // dont l'offset pointe hors des bornes du fichier -> `ZipDecoder`
      // lève une exception à la lecture, pas seulement une archive vide.
      final bytes = [
        0x50, 0x4B, 0x03, 0x04, // signature ZIP en tête (magic bytes)
        ..._eocdWithBogusOffset,
      ];
      final result = ingestOdt(bytes);
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('corrompue'));
    });

    test('entrée « mimetype » absente -> refus', () {
      final bytes = buildStoredZip({
        'content.xml': '<text:p>Contenu</text:p>',
      });
      final result = ingestOdt(bytes);
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('mimetype'));
    });

    test('entrée « mimetype » présente mais contenu incorrect -> refus', () {
      final bytes = _buildOdtBytes(
        '<text:p>Contenu</text:p>',
        mimetype: 'application/vnd.oasis.opendocument.spreadsheet',
      );
      final result = ingestOdt(bytes);
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('MIME'));
    });

    test('« content.xml » absent -> refus', () {
      final bytes = buildStoredZip({'mimetype': _mimetype});
      final result = ingestOdt(bytes);
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('content.xml'));
    });
  });

  group('ingestOdt — garde-fou zip bomb (partagé avec docx)', () {
    test('odt normal, sous le seuil -> passe', () {
      final bytes = _buildOdtBytes('<text:p>Compte rendu normal.</text:p>');
      final result = ingestOdt(bytes, maxEntryBytes: 1024);
      expect(result, isA<IngestedText>());
      expect((result as IngestedText).text, 'Compte rendu normal.\n');
    });

    test(
        'taille déclarée dans l\'en-tête ZIP au-dessus du seuil -> refusé '
        'avant toute décompression', () {
      final content = 'A' * 500;
      final bytes = _buildOdtBytes(content);
      final result = ingestOdt(bytes, maxEntryBytes: 100);
      expect(result, isA<IngestRefused>());
      expect(
        (result as IngestRefused).reason,
        isNot(contains('A' * 10)), // jamais un extrait du contenu
      );
    });

    test(
        'mimetype valide (stored) + content.xml deflate avec en-tête '
        'mensonger -> refusé quand même (garde-fou partagé déclenché)', () {
      // Mimetype stocké normalement (comme un vrai .odt), content.xml très
      // répétitif : compresse à quelques octets mais décompresse vers
      // 200 000 caractères, avec une taille déclarée falsifiée à 10 (bien
      // en dessous du seuil de test) — seul le plafond appliqué PENDANT la
      // décompression réelle peut détecter ce cas.
      final content = '<text:p>${'A' * 200000}</text:p>';
      final bytes = buildZip([
        ZipTestEntry('mimetype', _mimetype),
        ZipTestEntry(
          'content.xml',
          content,
          compression: ZipCompression.deflated,
          declaredUncompressedSize: 10,
        ),
      ]);
      final result = ingestOdt(bytes, maxEntryBytes: 1000);
      expect(result, isA<IngestRefused>());
      final refused = result as IngestRefused;
      expect(refused.reason, isNot(contains('A' * 10)));
    });
  });
}
