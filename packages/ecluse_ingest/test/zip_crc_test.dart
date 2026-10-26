import 'dart:convert';

import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

/// Un octet du contenu modifié sans toucher à la somme de contrôle (CRC-32) de
/// l'archive doit faire **refuser** le fichier (P2-27) : sinon un texte altéré
/// est lu comme s'il était intact, « lu à moitié » sans le dire (règle 4).
const _texte = 'M. Julien Vasseur, tel 02 40 12 34 56.';

List<int> _altere(List<int> octets, String fragment) {
  final cible = utf8.encode(fragment);
  for (var i = 0; i + cible.length <= octets.length; i++) {
    var egal = true;
    for (var k = 0; k < cible.length; k++) {
      if (octets[i + k] != cible[k]) {
        egal = false;
        break;
      }
    }
    if (egal) {
      final copie = List<int>.from(octets);
      copie[i] = copie[i] == 0x41 ? 0x42 : 0x41; // remplace la 1re lettre
      return copie;
    }
  }
  throw StateError('fragment introuvable');
}

void main() {
  final docx = buildStoredZip({
    'word/document.xml':
        '<w:p><w:r><w:t xml:space="preserve">$_texte</w:t></w:r></w:p>',
  });
  final odt = buildStoredZip({
    'mimetype': 'application/vnd.oasis.opendocument.text',
    'content.xml': '<text:p>$_texte</text:p>',
  });

  test('référence : le .docx et le .odt intacts sont lus', () {
    expect(ingestFile(docx, filename: 'a.docx'), isA<IngestedText>());
    expect(ingestFile(odt, filename: 'a.odt'), isA<IngestedText>());
  });

  test('.docx dont le contenu ne correspond plus au CRC : refusé', () {
    final r = ingestFile(_altere(docx, 'Vasseur'), filename: 'a.docx');
    expect(r, isA<IngestRefused>(), reason: 'un texte altéré a été lu');
  });

  test('.odt dont le contenu ne correspond plus au CRC : refusé', () {
    final r = ingestFile(_altere(odt, 'Vasseur'), filename: 'a.odt');
    expect(r, isA<IngestRefused>(), reason: 'un texte altéré a été lu');
  });
}
