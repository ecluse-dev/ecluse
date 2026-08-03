import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Plafond par défaut partagé par tous les extracteurs basés sur ZIP
/// (`.docx`, `.odt`, …) : la taille décompressée déclarée dans l'en-tête ZIP
/// ne doit jamais le dépasser, et la décompression réelle de l'entrée lue
/// (`word/document.xml`, `content.xml`, …) ne doit jamais le dépasser non
/// plus. 50 Mo, aligné sur `docs/spec-ecluse-ingest.md` § 6 (limite « taille
/// décompressée »).
const int maxSafeZipEntryBytes = 50 * 1024 * 1024;

/// Levée par [decompressBounded] dès que le plafond est dépassé.
final class ZipBombDetected implements Exception {
  const ZipBombDetected();
}

/// Décompresse [file] en bornant les octets réellement écrits à
/// [maxBytes], quelle que soit la méthode de compression déclarée. Lève
/// [ZipBombDetected] dès que le plafond est dépassé, pendant l'écriture —
/// jamais après coup, quand la mémoire a déjà servi à tout stocker.
Uint8List decompressBounded(ArchiveFile file, int maxBytes) {
  final raw = file.rawContent;
  if (raw == null) return Uint8List(0);

  final output = _BoundedOutputStream(maxBytes);
  if (file.compression == CompressionType.none) {
    output.writeStream(raw.getStream(decompress: false));
  } else {
    // OOXML (docx) et OpenDocument (odt) ne produisent que « stored » ou
    // « deflate » ; toute autre méthode est traitée comme deflate par
    // défaut, cohérent avec le comportement de `package:archive` lui-même.
    ZLibDecoder().decodeStream(
      raw.getStream(decompress: false),
      output,
      raw: true,
    );
  }
  return output.getBytes();
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
      throw const ZipBombDetected();
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
