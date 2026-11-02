import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:test/test.dart';

import 'support/cout.dart';
import 'zip_test_utils.dart';

/// Coût d'un XML mal formé (P2-79). `<[^>]*>` repartait de chaque `<` jusqu'à la fin
/// du texte quand aucun `>` ne suit : 50 000 `<` prenaient 20 s, 100 000 70 s. Un
/// `document.xml` ou un `content.xml` mal formé suffit à geler l'application.
void main() {
  for (final (nom, entree) in [
    ('docx', 'word/document.xml'),
    ('odt', 'content.xml'),
  ]) {
    List<int> zip(int n) => nom == 'docx'
        ? buildStoredZip({entree: '<' * n})
        : buildStoredZip({
            'mimetype': 'application/vnd.oasis.opendocument.text',
            entree: '<' * n,
          });

    // Coût mesuré par rapport de tailles (P2-100) : voir `support/cout.dart`.
    test('$nom : « < » sans « > », coût linéaire jusqu\'à 100 000', () async {
      final cache = {for (final n in [25000, 100000]) n: zip(n)};
      await expectCroissanceLineaire((n) {
        ingestFile(cache[n]!, filename: 'f.$nom');
      }, n: 25000);
      expect(ingestFile(cache[100000]!, filename: 'f.$nom'),
          anyOf(isA<IngestedText>(), isA<IngestRefused>()));
    });
  }
}
