import 'entity.dart';

/// Contrat commun à tous les détecteurs d'entités d'Écluse.
///
/// Un détecteur est pur et sans état : même texte en entrée, mêmes
/// entités en sortie. Aucun accès réseau, aucun effet de bord. C'est la
/// garantie fondamentale du fonctionnement on-device.
abstract interface class EntityDetector {
  /// Type d'entité que ce détecteur sait reconnaître.
  EntityType get type;

  /// Détecte toutes les occurrences dans [text].
  ///
  /// Les entités retournées sont triées par position de début croissante
  /// et ne se chevauchent pas.
  List<DetectedEntity> detect(String text);
}
