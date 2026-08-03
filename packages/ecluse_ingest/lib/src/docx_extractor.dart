import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'docx_xml.dart';
import 'ingest_result.dart';
import 'magic_bytes.dart';
import 'zip_guard.dart';

/// Extrait le texte d'un fichier `.docx` (dézippage + lecture de
/// `word/document.xml`).
///
/// [maxEntryBytes] est un paramètre de test (valeur par défaut = la vraie
/// limite de production) : `ingestDocx` n'est pas exporté publiquement,
/// seul [ingestFile] l'est, donc l'exposer ici n'élargit pas l'API du
/// package.
IngestResult ingestDocx(List<int> bytes,
    {int maxEntryBytes = maxSafeZipEntryBytes}) {
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
    content = decompressBounded(documentFile, maxEntryBytes);
  } on ZipBombDetected {
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
