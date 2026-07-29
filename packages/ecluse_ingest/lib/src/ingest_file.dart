import 'docx_extractor.dart';
import 'ingest_result.dart';
import 'plain_text_extractor.dart';

const List<String> supportedExtensions = ['txt', 'md', 'docx'];

/// Ingère un fichier déposé par nom [filename] et contenu [bytes].
///
/// Ne renvoie jamais un [IngestedText] vide pour un fichier qui n'a pas pu
/// être lu : tout format hors périmètre (dont `.pdf`, réservé à une v2), ou
/// tout contenu incohérent avec l'extension déclarée, produit un
/// [IngestRefused] explicite.
IngestResult ingestFile(List<int> bytes, {required String filename}) {
  final extension = _extensionOf(filename);

  switch (extension) {
    case 'txt':
      return ingestPlainText(bytes, IngestFormat.txt);
    case 'md':
      return ingestPlainText(bytes, IngestFormat.md);
    case 'docx':
      return ingestDocx(bytes);
    case null:
      return const IngestRefused(
        'Fichier sans extension reconnaissable : formats gérés en v1 -> '
        '.txt, .md, .docx.',
      );
    default:
      return IngestRefused(
        'Format « .$extension » non traité en v1 (formats gérés : .txt, '
        '.md, .docx). Écluse ne traite ni le PDF, ni l\'image, ni le '
        'manuscrit pour le moment.',
      );
  }
}

String? _extensionOf(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return null;
  return filename.substring(dot + 1).toLowerCase();
}
