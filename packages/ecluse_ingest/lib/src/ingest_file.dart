import 'docx_extractor.dart';
import 'ingest_result.dart';
import 'odt_extractor.dart';
import 'pdf/pdf_guard.dart';
import 'plain_text_extractor.dart';

const List<String> supportedExtensions = ['txt', 'md', 'docx', 'odt', 'pdf'];

/// Ingère un fichier déposé par nom [filename] et contenu [bytes].
///
/// Ne renvoie jamais un [IngestedText] vide pour un fichier qui n'a pas pu
/// être lu : tout format hors périmètre (dont le PDF image ou numérisé), ou
/// tout contenu incohérent avec l'extension déclarée, produit un
/// [IngestRefused] explicite.
IngestResult ingestFile(List<int> bytes, {required String filename}) {
  try {
    return _ingest(bytes, filename);
  } catch (_) {
    // Filet de sécurité : quoi qu'il arrive dans un extracteur, l'appelant
    // reçoit un refus explicite, jamais une exception ni un texte vide. Le
    // message ne reprend pas l'erreur (elle pourrait citer du contenu).
    return const IngestRefused(
      'Fichier illisible : erreur interne pendant la lecture. Fichier '
      'refusé.',
    );
  }
}

IngestResult _ingest(List<int> bytes, String filename) {
  final extension = _extensionOf(filename);

  switch (extension) {
    case 'txt':
      return ingestPlainText(bytes, IngestFormat.txt);
    case 'md':
      return ingestPlainText(bytes, IngestFormat.md);
    case 'docx':
      return ingestDocx(bytes);
    case 'odt':
      return ingestOdt(bytes);
    case 'pdf':
      return ingestPdf(bytes);
    case null:
      return const IngestRefused(
        'Fichier sans extension reconnaissable : formats gérés -> .txt, '
        '.md, .docx, .odt, .pdf (texte natif).',
      );
    default:
      return IngestRefused(
        'Format « .$extension » non traité (formats gérés : .txt, .md, '
        '.docx, .odt, .pdf à texte natif). Écluse ne traite ni l\'image, '
        'ni le scan, ni le manuscrit pour le moment.',
      );
  }
}

String? _extensionOf(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return null;
  return filename.substring(dot + 1).toLowerCase();
}
