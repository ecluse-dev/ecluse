import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:ecluse_ingest/src/docx_extractor.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

void main() {
  group('ingestDocx — garde-fou zip bomb', () {
    test('docx normal, sous le seuil -> passe', () {
      final bytes = buildStoredZip({
        'word/document.xml':
            '<w:p><w:r><w:t>Compte rendu normal.</w:t></w:r></w:p>',
      });
      final result = ingestDocx(bytes, maxEntryBytes: 1024);
      expect(result, isA<IngestedText>());
      expect((result as IngestedText).text, 'Compte rendu normal.\n');
    });

    test(
        'taille déclarée dans l\'en-tête ZIP au-dessus du seuil -> refusé '
        'avant toute décompression', () {
      // "stored" : taille compressée == taille déclarée == taille réelle.
      // Dépasse le seuil de test (100 octets) sans qu'aucune décompression
      // ne soit nécessaire pour le détecter.
      final content = 'A' * 500;
      final bytes = buildStoredZip({'word/document.xml': content});
      final result = ingestDocx(bytes, maxEntryBytes: 100);
      expect(result, isA<IngestRefused>());
      expect(
        (result as IngestRefused).reason,
        isNot(contains('A' * 10)), // jamais un extrait du contenu
      );
    });

    test(
        'en-tête ZIP mensonger (petite taille déclarée) + flux deflate qui '
        'produit bien plus -> refusé quand même', () {
      // Contenu très répétitif : compresse à quelques octets, mais
      // décompresse vers 200 000 caractères. La taille déclarée dans
      // l'en-tête est falsifiée à 10 (bien en dessous du seuil de test) :
      // seul le plafond appliqué PENDANT la décompression réelle peut
      // détecter ce cas, pas la vérification de la taille déclarée.
      final content = 'A' * 200000;
      final bytes = buildDeflatedZip(
        'word/document.xml',
        content,
        declaredUncompressedSize: 10,
      );
      final result = ingestDocx(bytes, maxEntryBytes: 1000);
      expect(result, isA<IngestRefused>());
      final refused = result as IngestRefused;
      expect(refused.reason, isNot(contains('A' * 10)));
    });
  });
}
