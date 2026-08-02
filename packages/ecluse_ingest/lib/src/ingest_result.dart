/// Formats de fichier pris en charge en v1.
enum IngestFormat { txt, md, docx }

/// Résultat d'une tentative d'ingestion de fichier.
///
/// Toujours l'un des deux cas explicites [IngestedText] ou [IngestRefused] —
/// jamais un texte vide silencieux pour un fichier qui n'a pas pu être lu :
/// c'est la faille n°1 identifiée pour Écluse (faux sentiment de sécurité).
sealed class IngestResult {
  const IngestResult();
}

/// Texte extrait avec succès, prêt à être transmis tel quel à
/// `Ecluse.redact` — aucune transformation supplémentaire ne doit
/// intervenir entre l'extraction et la détection, sous peine de décaler
/// les offsets des entités détectées.
final class IngestedText extends IngestResult {
  const IngestedText({
    required this.text,
    required this.format,
    this.warnings = const [],
  });

  final String text;
  final IngestFormat format;

  /// Signaux non bloquants sur l'extraction (ex. `'empty'` pour un fichier
  /// vide) — un succès reste un succès, mais l'appelant peut vouloir
  /// distinguer un texte vide attendu d'un texte vide suspect.
  final List<String> warnings;
}

/// Fichier explicitement refusé : format hors périmètre, contenu
/// incohérent avec l'extension, ou encodage non reconnu. [reason] est un
/// message humain destiné à être affiché tel quel à l'utilisateur.
final class IngestRefused extends IngestResult {
  const IngestRefused(this.reason);

  final String reason;
}
