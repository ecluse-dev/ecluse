import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'docx_xml.dart';
import 'ingest_result.dart';
import 'magic_bytes.dart';

/// Plafond commun aux deux couches du garde-fou zip bomb ci-dessous : la
/// taille décompressée déclarée dans l'en-tête ZIP ne doit jamais la
/// dépasser, et la décompression réelle de `word/document.xml` ne doit
/// jamais la dépasser non plus. 50 Mo, aligné sur
/// `docs/spec-ecluse-ingest.md` § 6 (limite « taille décompressée »).
const int _maxDocxEntryBytes = 50 * 1024 * 1024;

/// Extrait le texte d'un fichier `.docx` (dézippage + lecture de
/// `word/document.xml`).
///
/// [maxEntryBytes] est un paramètre de test (valeur par défaut = la vraie
/// limite de production) : `ingestDocx` n'est pas exporté publiquement,
/// seul [ingestFile] l'est, donc l'exposer ici n'élargit pas l'API du
/// package.
IngestResult ingestDocx(List<int> bytes,
    {int maxEntryBytes = _maxDocxEntryBytes}) {
  if (!bytesStartWith(bytes, zipLocalFileSignature)) {
    return const IngestRefused(
      'Le fichier .docx est illisible : signature ZIP absente en tête de '
      'fichier (extension et contenu incohérents), fichier refusé.',
    );
  }

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (error) {
    return IngestRefused('Archive .docx corrompue ou illisible : $error.');
  }

  final documentFile = archive.findFile('word/document.xml');
  if (documentFile == null) {
    return const IngestRefused(
      'Fichier .docx invalide : « word/document.xml » introuvable dans '
      "l'archive.",
    );
  }

  // Garde-fou zip bomb, couche 1 : rejet rapide sur la taille annoncée par
  // l'en-tête ZIP, avant toute décompression — capte la grande majorité
  // des cas (générateurs de zip bomb usuels, fichiers énormes par erreur)
  // sans le moindre coût de décompression.
  if (documentFile.size > maxEntryBytes) {
    return const IngestRefused(
      'Fichier .docx refusé : « word/document.xml » déclare une taille '
      'décompressée excessive (protection zip bomb).',
    );
  }

  // Garde-fou zip bomb, couche 2 : plafond appliqué PENDANT la
  // décompression elle-même, sur les octets réellement produits — au cas
  // où l'en-tête mentirait sur la taille déclarée (couche 1 seule fait
  // confiance à une métadonnée du fichier, jamais garantie honnête).
  final Uint8List content;
  try {
    content = _decompressBounded(documentFile, maxEntryBytes);
  } on _ZipBombDetected {
    return const IngestRefused(
      'Fichier .docx refusé : « word/document.xml » dépasse la taille '
      'maximale autorisée une fois décompressé (protection zip bomb).',
    );
  } catch (error) {
    return IngestRefused('Archive .docx corrompue ou illisible : $error.');
  }

  final String xml;
  try {
    xml = utf8.decode(content);
  } on FormatException {
    return const IngestRefused(
      'Contenu de « word/document.xml » illisible (encodage inattendu).',
    );
  }

  return IngestedText(
    text: extractDocxPlainText(xml),
    format: IngestFormat.docx,
  );
}

/// Décompresse [file] en bornant les octets réellement écrits à
/// [maxBytes], quelle que soit la méthode de compression déclarée. Lève
/// [_ZipBombDetected] dès que le plafond est dépassé, pendant l'écriture —
/// jamais après coup, quand la mémoire a déjà servi à tout stocker.
Uint8List _decompressBounded(ArchiveFile file, int maxBytes) {
  final raw = file.rawContent;
  if (raw == null) return Uint8List(0);

  final output = _BoundedOutputStream(maxBytes);
  if (file.compression == CompressionType.none) {
    output.writeStream(raw.getStream(decompress: false));
  } else {
    // OOXML (docx) ne produit que « stored » ou « deflate » ; toute autre
    // méthode est traitée comme deflate par défaut, cohérent avec le
    // comportement de `package:archive` lui-même pour un .docx réel.
    ZLibDecoder().decodeStream(
      raw.getStream(decompress: false),
      output,
      raw: true,
    );
  }
  return output.getBytes();
}

/// Levée par [_BoundedOutputStream] dès que le plafond est dépassé.
final class _ZipBombDetected implements Exception {
  const _ZipBombDetected();
}

/// [OutputStream] qui refuse d'accumuler plus de [maxBytes] octets — le
/// dépassement est détecté au fil de l'écriture, pas en relisant le
/// résultat final, pour ne jamais laisser la mémoire gonfler au-delà du
/// plafond avant de s'en apercevoir.
final class _BoundedOutputStream extends OutputStream {
  _BoundedOutputStream(this.maxBytes)
      : super(byteOrder: ByteOrder.littleEndian);

  final int maxBytes;
  final List<Uint8List> _chunks = [];
  int _length = 0;

  @override
  int get length => _length;

  void _accumulate(Uint8List chunk) {
    _length += chunk.length;
    if (_length > maxBytes) {
      throw const _ZipBombDetected();
    }
    _chunks.add(chunk);
  }

  @override
  void writeByte(int value) => _accumulate(Uint8List.fromList([value]));

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final n = length ?? bytes.length;
    _accumulate(Uint8List.fromList(bytes.take(n).toList()));
  }

  @override
  void writeStream(InputStream stream) => _accumulate(stream.toUint8List());

  @override
  void flush() {}

  @override
  void clear() {
    _chunks.clear();
    _length = 0;
  }

  @override
  Uint8List subset(int start, [int? end]) {
    final all = getBytes();
    return all.sublist(start, end);
  }

  @override
  Uint8List getBytes() {
    final result = Uint8List(_length);
    var offset = 0;
    for (final chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }
}
