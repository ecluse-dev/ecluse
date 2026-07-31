import 'dart:convert';
import 'dart:typed_data';

/// Construit un fichier ZIP minimal, **non compressé** (méthode « stored »),
/// pour les fixtures de test `.docx` — sans jamais passer par un encodeur
/// ZIP de bibliothèque tierce.
///
/// Copie de `packages/ecluse_ingest/test/zip_test_utils.dart` : chaque
/// package du monorepo garde ses propres fixtures de test, sans dépendance
/// croisée entre suites de test.
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
