/// Types d'entités personnelles détectables par Écluse.
///
/// La liste s'étendra au fil des détecteurs (FINESS, téléphones, etc.).
enum EntityType {
  /// Numéro d'Inscription au Répertoire (numéro de sécurité sociale français).
  nir,

  /// Numéro RPPS — Répertoire Partagé des Professionnels de Santé
  /// (identifiant national des professionnels de santé français).
  rpps,

  /// IBAN français (International Bank Account Number, préfixe FR).
  iban,
}

/// Une entité personnelle détectée dans un texte.
///
/// [start] et [end] sont des index de code units dans la chaîne d'origine,
/// utilisables directement avec `String.substring(start, end)`.
final class DetectedEntity {
  const DetectedEntity({
    required this.type,
    required this.start,
    required this.end,
    required this.value,
    required this.confidence,
  })  : assert(start >= 0, 'start doit être positif'),
        assert(end > start, 'end doit être strictement supérieur à start'),
        assert(
          confidence >= 0 && confidence <= 1,
          'confidence doit être dans [0, 1]',
        );

  /// Type de l'entité détectée.
  final EntityType type;

  /// Index de début (inclus) dans le texte d'origine.
  final int start;

  /// Index de fin (exclus) dans le texte d'origine.
  final int end;

  /// Valeur brute telle qu'elle apparaît dans le texte.
  final String value;

  /// Niveau de confiance de la détection, entre 0 et 1.
  ///
  /// 1.0 signifie une validation structurelle complète : champs internes
  /// vérifiés ET clé de contrôle discriminante (ex. NIR, IBAN).
  /// Une validation plus faible (ex. Luhn seul sur le RPPS, sans structure
  /// interne vérifiable) donne une confiance légèrement inférieure.
  final double confidence;

  @override
  bool operator ==(Object other) =>
      other is DetectedEntity &&
      other.type == type &&
      other.start == start &&
      other.end == end &&
      other.value == value &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(type, start, end, value, confidence);

  @override
  String toString() =>
      'DetectedEntity(${type.name}, [$start, $end), confidence: $confidence)';
}
