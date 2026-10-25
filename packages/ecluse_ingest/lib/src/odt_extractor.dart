import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'ingest_result.dart';
import 'magic_bytes.dart';
import 'odt_xml.dart';
import 'xml_guards.dart';
import 'zip_guard.dart';

/// Type MIME attendu dans l'entrée `mimetype` d'un `.odt` valide (norme
/// OpenDocument, ODF 1.x, format « text »).
const String _odtMimeType = 'application/vnd.oasis.opendocument.text';

/// Plafond de lecture de l'entrée `mimetype` elle-même : cette entrée est
/// conventionnellement stockée non compressée et minuscule (~40 octets) ;
/// une limite dédiée, bien plus basse que [maxSafeZipEntryBytes], suffit et
/// évite de faire confiance à une taille annoncée avant de l'avoir vérifiée.
const int _maxMimetypeEntryBytes = 256;

/// Extrait le texte d'un fichier `.odt` (dézippage + vérification du type
/// MIME OpenDocument + lecture de `content.xml`).
///
/// [maxEntryBytes] est un paramètre de test (valeur par défaut = la vraie
/// limite de production) : `ingestOdt` n'est pas exporté publiquement,
/// seul [ingestFile] l'est, donc l'exposer ici n'élargit pas l'API du
/// package.
IngestResult ingestOdt(List<int> bytes,
    {int maxEntryBytes = maxSafeZipEntryBytes}) {
  if (!bytesStartWith(bytes, zipLocalFileSignature)) {
    return const IngestRefused(
      'Le fichier .odt est illisible : signature ZIP absente en tête de '
      'fichier (extension et contenu incohérents), fichier refusé.',
    );
  }

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (error) {
    return IngestRefused('Archive .odt corrompue ou illisible : $error.');
  }

  // Selon la version du package `archive`, un répertoire central illisible
  // lève une exception (cas ci-dessus) ou produit une archive vide sans
  // erreur. Un .odt sans aucune entrée n'est jamais valide : on le refuse
  // comme corrompu, pour que le motif ne dépende pas de la version de la
  // dépendance.
  if (archive.isEmpty) {
    return const IngestRefused(
      'Archive .odt corrompue ou illisible : aucune entrée lisible.',
    );
  }

  final mimetypeFile = archive.findFile('mimetype');
  if (mimetypeFile == null) {
    return const IngestRefused(
      'Fichier .odt invalide : entrée « mimetype » introuvable dans '
      "l'archive.",
    );
  }

  if (mimetypeFile.size > _maxMimetypeEntryBytes) {
    return const IngestRefused(
      'Fichier .odt invalide : entrée « mimetype » de taille inattendue.',
    );
  }

  final Uint8List mimetypeBytes;
  try {
    mimetypeBytes = decompressBounded(mimetypeFile, _maxMimetypeEntryBytes);
  } on ZipBombDetected {
    return const IngestRefused(
      'Fichier .odt invalide : entrée « mimetype » de taille inattendue.',
    );
  } catch (error) {
    return IngestRefused('Archive .odt corrompue ou illisible : $error.');
  }

  if (utf8.decode(mimetypeBytes, allowMalformed: true) != _odtMimeType) {
    return const IngestRefused(
      'Fichier .odt invalide : type MIME OpenDocument absent ou '
      'incorrect (fichier refusé).',
    );
  }

  final documentFile = archive.findFile('content.xml');
  if (documentFile == null) {
    return const IngestRefused(
      'Fichier .odt invalide : « content.xml » introuvable dans '
      "l'archive.",
    );
  }

  // Garde-fou zip bomb, couche 1 : rejet rapide sur la taille annoncée par
  // l'en-tête ZIP, avant toute décompression — capte la grande majorité
  // des cas (générateurs de zip bomb usuels, fichiers énormes par erreur)
  // sans le moindre coût de décompression.
  if (documentFile.size > maxEntryBytes) {
    return const IngestRefused(
      'Fichier .odt refusé : « content.xml » déclare une taille '
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
      'Fichier .odt refusé : « content.xml » dépasse la taille maximale '
      'autorisée une fois décompressé (protection zip bomb).',
    );
  } catch (error) {
    return IngestRefused('Archive .odt corrompue ou illisible : $error.');
  }

  final String xml;
  try {
    xml = utf8.decode(content);
  } on FormatException {
    return const IngestRefused(
      'Contenu de « content.xml » illisible (encodage inattendu).',
    );
  }

  final refusal = namespacePrefixRefusal(
        xml,
        namespace: _odtTextNamespace,
        expectedPrefix: 'text',
        format: '.odt',
      ) ??
      unsupportedXmlRefusal(xml, format: '.odt');
  if (refusal != null) return IngestRefused(refusal);

  final String text;
  try {
    text = extractOdtPlainText(xml);
  } catch (_) {
    return const IngestRefused(
      'Fichier .odt refusé : contenu XML de « content.xml » malformé '
      '(entité ou balise illisible).',
    );
  }

  return IngestedText(
    text: text,
    format: IngestFormat.odt,
    warnings: [
      if (text.trim().isEmpty) 'empty',
      if (_hasHeaderFooterText(archive, maxEntryBytes)) 'ignored_parts',
    ],
  );
}

const String _odtTextNamespace =
    'urn:oasis:names:tc:opendocument:xmlns:text:1.0';

final RegExp _headerFooterBlock = RegExp(
  r'<style:(?:header|footer)(?:-left|-first)?\b[^>]*>([\s\S]*?)'
  r'</style:(?:header|footer)(?:-left|-first)?>',
);

/// En-têtes et pieds de page ODT : ils vivent dans `styles.xml`, que
/// l'extracteur ne lit pas. Signalés quand ils contiennent du texte.
bool _hasHeaderFooterText(Archive archive, int maxEntryBytes) {
  final styles = archive.findFile('styles.xml');
  if (styles == null) return false;
  if (styles.size > maxEntryBytes) return true;
  try {
    final xml = utf8.decode(decompressBounded(styles, maxEntryBytes),
        allowMalformed: true);
    for (final block in _headerFooterBlock.allMatches(xml)) {
      if (extractOdtPlainText(block.group(1)!).trim().isNotEmpty) return true;
    }
    return false;
  } catch (_) {
    return true;
  }
}
