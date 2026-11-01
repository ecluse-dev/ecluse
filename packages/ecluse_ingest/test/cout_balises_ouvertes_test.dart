import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

/// Coût d'un XML mal formé (P2-79). `<[^>]*>` repartait de chaque `<` jusqu'à la fin
/// du texte quand aucun `>` ne suit : 50 000 `<` prenaient 20 s, 100 000 70 s. Un
/// `document.xml` ou un `content.xml` mal formé suffit à geler l'application.
void main() {
  for (final (nom, contenu, entree) in [
    ('docx', '<' * 100000, 'word/document.xml'),
    ('odt', '<' * 100000, 'content.xml'),
  ]) {
    test('$nom : 100 000 « < » sans « > » en moins de 3 s', () {
      final zip = nom == 'docx'
          ? buildStoredZip({entree: contenu})
          : buildStoredZip({
              'mimetype': 'application/vnd.oasis.opendocument.text',
              entree: contenu,
            });
      final sw = Stopwatch()..start();
      final r = ingestFile(zip, filename: 'f.$nom');
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
      expect(r, anyOf(isA<IngestedText>(), isA<IngestRefused>()));
    });
  }
}
