import 'detection/detector_tier.dart';

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

  /// Numéro FINESS — identifiant national d'établissement de santé
  /// français. Partage son algorithme de clé (Luhn) avec le SIREN : voir
  /// `FinessDetector` pour la collision structurelle assumée.
  finess,

  /// Nom de personne (détection heuristique, voir `ecluse_redact`).
  nom,

  /// Date de naissance (détection heuristique, voir `ecluse_redact`).
  dateNaissance,

  /// Adresse postale simple (détection heuristique, voir `ecluse_redact`).
  adresse,

  /// Numéro de téléphone français (détection heuristique, voir
  /// `ecluse_redact`).
  telephone,

  /// Adresse email (détection heuristique, voir `ecluse_redact`).
  email,

  /// Nom d'établissement (détection heuristique, voir `ecluse_redact`).
  etablissement,
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
    this.tier,
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

  /// Origine de la détection (départage dans `resolveOverlaps`).
  ///
  /// N'entre pas dans `==`/`hashCode` : c'est une métadonnée de provenance
  /// attachée par le moteur qui a produit l'entité, pas une composante de
  /// son identité (même entité, même position, que `tier` soit renseigné
  /// ou non).
  final DetectorTier? tier;

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
  String toString() => 'DetectedEntity(${type.name}, [$start, $end), '
      'confidence: $confidence, tier: ${tier?.name})';
}
