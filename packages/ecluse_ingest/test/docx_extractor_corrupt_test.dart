import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:ecluse_ingest/src/docx_extractor.dart';
import 'package:test/test.dart';

/// Enregistrement de fin de répertoire central (EOCD) d'apparence valide
/// (signature correcte, 1 entrée annoncée) mais dont l'offset de
/// répertoire central (999 999) dépasse la taille du fichier. Selon la
/// version du package `archive`, `ZipDecoder` lève une exception ou
/// renvoie une archive vide : `ingestDocx` doit refuser dans les deux cas,
/// avec le même motif.
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

void main() {
  group('ingestDocx — archive corrompue', () {
    test('répertoire central illisible -> refus « corrompue »', () {
      final bytes = [
        0x50, 0x4B, 0x03, 0x04, // signature ZIP en tête (magic bytes)
        ..._eocdWithBogusOffset,
      ];
      final result = ingestDocx(bytes);
      expect(result, isA<IngestRefused>());
      expect((result as IngestRefused).reason, contains('corrompue'));
    });
  });
}
