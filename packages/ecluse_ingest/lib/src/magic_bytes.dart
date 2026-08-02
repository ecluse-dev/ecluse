/// Détection par signature binaire (« magic bytes ») — défense en
/// profondeur en plus de l'extension déclarée. Un renommage (volontaire ou
/// non) d'un fichier binaire en `.txt`/`.md`, ou d'un fichier texte en
/// `.docx`, ne doit jamais être avalé silencieusement.
library;

/// Signature ZIP standard (en-tête de fichier local) : tout `.docx` valide
/// commence par ces quatre octets, puisqu'une archive ZIP non vide en
/// contient toujours au moins un.
const List<int> zipLocalFileSignature = [0x50, 0x4B, 0x03, 0x04];

final class KnownBinaryFormat {
  const KnownBinaryFormat(this.signature, this.label);

  final List<int> signature;
  final String label;
}

/// Signatures binaires reconnues, pour repérer un fichier déguisé en texte
/// brut (`.txt`/`.md`) alors que son contenu réel est un autre format.
const List<KnownBinaryFormat> knownBinarySignatures = [
  KnownBinaryFormat(zipLocalFileSignature, 'archive ZIP (docx/odt/xlsx…)'),
  KnownBinaryFormat([0x50, 0x4B, 0x05, 0x06], 'archive ZIP vide'),
  KnownBinaryFormat([0x25, 0x50, 0x44, 0x46], 'PDF'),
  KnownBinaryFormat(
    [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
    'document Office binaire (.doc/.xls historique)',
  ),
  KnownBinaryFormat([0x89, 0x50, 0x4E, 0x47], 'image PNG'),
  KnownBinaryFormat([0xFF, 0xD8, 0xFF], 'image JPEG'),
  KnownBinaryFormat([0x47, 0x49, 0x46, 0x38], 'image GIF'),
];

const List<int> utf16LeBom = [0xFF, 0xFE];
const List<int> utf16BeBom = [0xFE, 0xFF];
const List<int> utf8Bom = [0xEF, 0xBB, 0xBF];

bool bytesStartWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

/// Le format binaire connu dont la signature ouvre [bytes], le cas échéant.
KnownBinaryFormat? matchKnownBinarySignature(List<int> bytes) {
  for (final format in knownBinarySignatures) {
    if (bytesStartWith(bytes, format.signature)) return format;
  }
  return null;
}

bool hasUtf16Bom(List<int> bytes) =>
    bytesStartWith(bytes, utf16LeBom) || bytesStartWith(bytes, utf16BeBom);

/// Retire le BOM UTF-8 (`EF BB BF`) en tête de [bytes], s'il est présent.
/// Le BOM est un artefact d'encodage, pas du contenu : il ne doit jamais
/// apparaître dans le texte extrait ni décaler les offsets.
List<int> stripUtf8Bom(List<int> bytes) =>
    bytesStartWith(bytes, utf8Bom) ? bytes.sublist(utf8Bom.length) : bytes;
