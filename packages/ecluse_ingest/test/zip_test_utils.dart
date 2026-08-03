import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Construit un fichier ZIP minimal, **non compressé** (méthode « stored »),
/// pour les fixtures de test `.docx` — sans jamais passer par un encodeur
/// ZIP de bibliothèque tierce.
///
/// `ecluse_ingest` est un package de LECTURE seule en v1 (aucun besoin
/// d'écrire du ZIP en production) : ce fichier isole toute construction de
/// ZIP dans les tests, à l'écart de `package:archive`, dont seule la classe
/// `ZipDecoder` est utilisée par `lib/` (voir `docx_extractor.dart`).
///
/// [entries] associe un nom d'entrée (ex. `word/document.xml`) à son
/// contenu texte, encodé en UTF-8.
List<int> buildStoredZip(Map<String, String> entries) {
  final localSections = <List<int>>[];
  final centralSections = <List<int>>[];
  var offset = 0;

  for (final entry in entries.entries) {
    final nameBytes = utf8.encode(entry.key);
    final content = utf8.encode(entry.value);
    final crc = _crc32(content);
    final size = content.length;

    final local = BytesBuilder()
      ..add(_uint32LE(0x04034b50))
      ..add(_uint16LE(20)) // version nécessaire à l'extraction
      ..add(_uint16LE(0)) // options
      ..add(_uint16LE(0)) // méthode : stored (aucune compression)
      ..add(_uint16LE(0)) // heure
      ..add(_uint16LE(0)) // date
      ..add(_uint32LE(crc))
      ..add(_uint32LE(size)) // taille compressée == taille réelle (stored)
      ..add(_uint32LE(size))
      ..add(_uint16LE(nameBytes.length))
      ..add(_uint16LE(0)) // longueur champ extra
      ..add(nameBytes)
      ..add(content);
    final localBytes = local.toBytes();
    localSections.add(localBytes);

    final central = BytesBuilder()
      ..add(_uint32LE(0x02014b50))
      ..add(_uint16LE(20)) // version « made by »
      ..add(_uint16LE(20)) // version nécessaire
      ..add(_uint16LE(0)) // options
      ..add(_uint16LE(0)) // méthode
      ..add(_uint16LE(0)) // heure
      ..add(_uint16LE(0)) // date
      ..add(_uint32LE(crc))
      ..add(_uint32LE(size))
      ..add(_uint32LE(size))
      ..add(_uint16LE(nameBytes.length))
      ..add(_uint16LE(0)) // extra
      ..add(_uint16LE(0)) // commentaire
      ..add(_uint16LE(0)) // numéro de disque
      ..add(_uint16LE(0)) // attributs internes
      ..add(_uint32LE(0)) // attributs externes
      ..add(_uint32LE(offset)) // offset de l'en-tête local
      ..add(nameBytes);
    centralSections.add(central.toBytes());

    offset += localBytes.length;
  }

  final centralDirectory = centralSections.expand((b) => b).toList();
  final endRecord = BytesBuilder()
    ..add(_uint32LE(0x06054b50))
    ..add(_uint16LE(0)) // numéro de ce disque
    ..add(_uint16LE(0)) // disque du début du répertoire central
    ..add(_uint16LE(entries.length)) // entrées sur ce disque
    ..add(_uint16LE(entries.length)) // entrées au total
    ..add(_uint32LE(centralDirectory.length))
    ..add(_uint32LE(offset)) // offset du début du répertoire central
    ..add(_uint16LE(0)); // longueur du commentaire

  return [
    ...localSections.expand((b) => b),
    ...centralDirectory,
    ...endRecord.toBytes(),
  ];
}

/// Construit un ZIP minimal à **une seule entrée compressée en deflate**
/// (méthode 8), pour tester le plafond de décompression du garde-fou zip
/// bomb — `buildStoredZip` ne peut pas servir à ça : en mode « stored »,
/// taille compressée == taille réelle, impossible de simuler un flux qui
/// décompresse vers plus que ce que l'en-tête annonce.
///
/// [declaredUncompressedSize] permet de **falsifier** la taille annoncée
/// dans l'en-tête (par défaut, la vraie taille) : sert spécifiquement à
/// tester qu'un en-tête ZIP mensonger ne suffit pas à contourner le
/// plafond réel appliqué pendant la décompression elle-même.
///
/// `dart:io`'s `ZLibCodec`, pas `package:archive` : ce fichier reste à
/// l'écart de tout encodeur ZIP de bibliothèque tierce (voir le
/// commentaire de [buildStoredZip]) ; `ZLibCodec` ne fait que la
/// compression deflate du contenu, pas la construction du conteneur ZIP.
List<int> buildDeflatedZip(
  String entryName,
  String content, {
  int? declaredUncompressedSize,
}) {
  final nameBytes = utf8.encode(entryName);
  final rawContent = utf8.encode(content);
  final compressed = ZLibCodec(raw: true).encode(rawContent);
  final crc = _crc32(rawContent);
  final declaredSize = declaredUncompressedSize ?? rawContent.length;
  const method = 8; // deflate

  final local = BytesBuilder()
    ..add(_uint32LE(0x04034b50))
    ..add(_uint16LE(20))
    ..add(_uint16LE(0))
    ..add(_uint16LE(method))
    ..add(_uint16LE(0))
    ..add(_uint16LE(0))
    ..add(_uint32LE(crc))
    ..add(_uint32LE(compressed.length))
    ..add(_uint32LE(declaredSize)) // potentiellement falsifiée
    ..add(_uint16LE(nameBytes.length))
    ..add(_uint16LE(0))
    ..add(nameBytes)
    ..add(compressed);
  final localBytes = local.toBytes();

  final central = BytesBuilder()
    ..add(_uint32LE(0x02014b50))
    ..add(_uint16LE(20))
    ..add(_uint16LE(20))
    ..add(_uint16LE(0))
    ..add(_uint16LE(method))
    ..add(_uint16LE(0))
    ..add(_uint16LE(0))
    ..add(_uint32LE(crc))
    ..add(_uint32LE(compressed.length))
    ..add(_uint32LE(declaredSize)) // potentiellement falsifiée — c'est
    // cette valeur, pas celle de l'en-tête local, que `package:archive`
    // retient au final pour `ArchiveFile.size` (voir zip_file.dart:
    // `uncompressedSize = header?.uncompressedSize ?? uncompressedSize`).
    ..add(_uint16LE(nameBytes.length))
    ..add(_uint16LE(0))
    ..add(_uint16LE(0))
    ..add(_uint16LE(0))
    ..add(_uint16LE(0))
    ..add(_uint32LE(0))
    ..add(_uint32LE(0))
    ..add(nameBytes);
  final centralBytes = central.toBytes();

  final endRecord = BytesBuilder()
    ..add(_uint32LE(0x06054b50))
    ..add(_uint16LE(0))
    ..add(_uint16LE(0))
    ..add(_uint16LE(1))
    ..add(_uint16LE(1))
    ..add(_uint32LE(centralBytes.length))
    ..add(_uint32LE(localBytes.length))
    ..add(_uint16LE(0));

  return [...localBytes, ...centralBytes, ...endRecord.toBytes()];
}

/// Méthode de compression d'une entrée pour [buildZip].
enum ZipCompression { stored, deflated }

/// Une entrée à écrire dans un ZIP construit par [buildZip].
///
/// [declaredUncompressedSize] permet de falsifier la taille annoncée dans
/// l'en-tête (par défaut, la vraie taille) — même usage que dans
/// [buildDeflatedZip], voir son commentaire.
class ZipTestEntry {
  const ZipTestEntry(
    this.name,
    this.content, {
    this.compression = ZipCompression.stored,
    this.declaredUncompressedSize,
  });

  final String name;
  final String content;
  final ZipCompression compression;
  final int? declaredUncompressedSize;
}

/// Construit un ZIP à **plusieurs entrées, à compression mixte**
/// (`stored`/`deflated` par entrée) — utile pour des fixtures qui
/// combinent une petite entrée non compressée (ex. `mimetype` d'un
/// `.odt`) avec une entrée deflate potentiellement gonflable (ex.
/// `content.xml`), sans quoi [buildStoredZip] (tout stored) et
/// [buildDeflatedZip] (une seule entrée deflate) ne suffisent pas.
List<int> buildZip(List<ZipTestEntry> entries) {
  final localSections = <List<int>>[];
  final centralSections = <List<int>>[];
  var offset = 0;

  for (final entry in entries) {
    final nameBytes = utf8.encode(entry.name);
    final rawContent = utf8.encode(entry.content);
    final deflated = entry.compression == ZipCompression.deflated;
    final compressed =
        deflated ? ZLibCodec(raw: true).encode(rawContent) : rawContent;
    final crc = _crc32(rawContent);
    final declaredSize = entry.declaredUncompressedSize ?? rawContent.length;
    final method = deflated ? 8 : 0;

    final local = BytesBuilder()
      ..add(_uint32LE(0x04034b50))
      ..add(_uint16LE(20))
      ..add(_uint16LE(0))
      ..add(_uint16LE(method))
      ..add(_uint16LE(0))
      ..add(_uint16LE(0))
      ..add(_uint32LE(crc))
      ..add(_uint32LE(compressed.length))
      ..add(_uint32LE(declaredSize))
      ..add(_uint16LE(nameBytes.length))
      ..add(_uint16LE(0))
      ..add(nameBytes)
      ..add(compressed);
    final localBytes = local.toBytes();
    localSections.add(localBytes);

    final central = BytesBuilder()
      ..add(_uint32LE(0x02014b50))
      ..add(_uint16LE(20))
      ..add(_uint16LE(20))
      ..add(_uint16LE(0))
      ..add(_uint16LE(method))
      ..add(_uint16LE(0))
      ..add(_uint16LE(0))
      ..add(_uint32LE(crc))
      ..add(_uint32LE(compressed.length))
      ..add(_uint32LE(declaredSize))
      ..add(_uint16LE(nameBytes.length))
      ..add(_uint16LE(0))
      ..add(_uint16LE(0))
      ..add(_uint16LE(0))
      ..add(_uint16LE(0))
      ..add(_uint32LE(0))
      ..add(_uint32LE(offset))
      ..add(nameBytes);
    centralSections.add(central.toBytes());

    offset += localBytes.length;
  }

  final centralDirectory = centralSections.expand((b) => b).toList();
  final endRecord = BytesBuilder()
    ..add(_uint32LE(0x06054b50))
    ..add(_uint16LE(0))
    ..add(_uint16LE(0))
    ..add(_uint16LE(entries.length))
    ..add(_uint16LE(entries.length))
    ..add(_uint32LE(centralDirectory.length))
    ..add(_uint32LE(offset))
    ..add(_uint16LE(0));

  return [
    ...localSections.expand((b) => b),
    ...centralDirectory,
    ...endRecord.toBytes(),
  ];
}

List<int> _uint16LE(int value) => [value & 0xFF, (value >> 8) & 0xFF];

List<int> _uint32LE(int value) => [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];

/// CRC-32 standard (polynôme 0xEDB88320), calculé bit à bit — les fixtures
/// de test sont minuscules, aucun besoin d'une table précalculée.
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
