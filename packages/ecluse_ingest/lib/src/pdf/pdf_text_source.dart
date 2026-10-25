import 'dart:typed_data';

/// Ce que l'ingestion sait d'une page, indépendamment de la bibliothèque PDF
/// qui l'a lue. Le garde-fou (`pdf_guard.dart`) ne raisonne que sur ces
/// valeurs : changer de bibliothèque ne touche pas ses règles.
final class PdfPageInfo {
  const PdfPageInfo({
    required this.text,
    required this.hasContent,
    required this.hasImage,
    required this.hasInvisibleText,
    this.hasTextOperators = false,
  });

  /// Texte extrait, tel quel (aucune transformation : les offsets des
  /// entités sont relatifs à ce texte).
  final String text;

  /// La page a un flux de contenu non vide. Une page sans contenu est
  /// *blanche* ; une page avec contenu mais sans texte est suspecte
  /// (image, texte vectorisé).
  final bool hasContent;

  /// La page dessine une image (XObject image ou image en ligne). Les images
  /// atteintes seulement par un XObject de formulaire ne sont pas vues : un
  /// manque conservateur, jamais un faux refus.
  final bool hasImage;

  /// Texte en mode de rendu invisible (`3 Tr`) : couche laissée par un OCR
  /// sur un scan.
  final bool hasInvisibleText;

  /// Le contenu de la page affiche du texte (`Tj`, `TJ`). Combiné à un texte
  /// extrait vide, c'est une police illisible (sans table `ToUnicode`) :
  /// du texte est là, l'extracteur n'a pas su le lire.
  final bool hasTextOperators;
}

/// Éléments hors du texte de page, que l'ingestion ne lit pas : ils peuvent
/// contenir des identifiants (spec P1-09 §4), donc donnent un avertissement.
final class PdfExtras {
  const PdfExtras({
    this.hasMetadata = false,
    this.hasAnnotations = false,
    this.hasForms = false,
    this.hasJavaScript = false,
  });

  final bool hasMetadata;
  final bool hasAnnotations;
  final bool hasForms;
  final bool hasJavaScript;
}

/// Un PDF ouvert. [page] ne doit être appelée qu'une fois, dans l'ordre :
/// l'implémentation peut libérer ce qu'elle a lu.
abstract interface class PdfOpenDocument {
  bool get isEncrypted;
  int get pageCount;
  PdfExtras get extras;
  PdfPageInfo page(int index);
}

/// Le PDF est illisible (structure invalide, mot de passe requis…).
/// [encrypted] distingue le cas « mot de passe requis ».
final class PdfSourceException implements Exception {
  const PdfSourceException({this.encrypted = false});

  final bool encrypted;
}

/// Interface mince devant la bibliothèque PDF, pour la remplacer sans
/// toucher au garde-fou (spec P1-09 §2). Aucune exécution de JavaScript,
/// aucun lien suivi : une implémentation ne fait que lire.
abstract interface class PdfTextSource {
  /// Ouvre [bytes] sans mot de passe. Lève [PdfSourceException] si le
  /// document est illisible.
  PdfOpenDocument open(Uint8List bytes);
}
