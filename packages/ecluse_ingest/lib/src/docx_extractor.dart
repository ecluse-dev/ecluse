import 'dart:convert';

import 'package:archive/archive.dart';

import 'docx_xml.dart';
import 'ingest_result.dart';
import 'magic_bytes.dart';

/// Extrait le texte d'un fichier `.docx` (dézippage + lecture de
/// `word/document.xml`).
IngestResult ingestDocx(List<int> bytes) {
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

  final String xml;
  try {
    xml = utf8.decode(documentFile.content as List<int>);
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
