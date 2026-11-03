import 'package:ecluse_core/ecluse_core.dart';

import 'risque.dart';

/// Résultat d'un appel à `Ecluse.redact`.
final class RedactResult {
  const RedactResult({
    required this.maskedText,
    required this.mapping,
    required this.entities,
    this.warnings = const [],
    this.risque,
    this.manuelles = const [],
  });

  /// Texte à envoyer à l'IA — les entités personnelles sont remplacées par
  /// des jetons typés (`[NOM_1]`, `[NIR_1]`, …).
  final String maskedText;

  /// Table de correspondance jeton ↔ valeur réelle.
  ///
  /// **Ne quitte jamais le processus local** : ni envoyée, ni journalisée,
  /// ni écrite sur disque. Elle ne sert qu'à l'appel à `Ecluse.restore`.
  final Map<String, String> mapping;

  /// Entités détectées dans le texte d'origine, triées par position,
  /// sans chevauchement (voir `resolveOverlaps`).
  final List<DetectedEntity> entities;

  /// Avertissements à montrer à l'utilisateur (hors texte envoyé). Pour
  /// l'instant : un secret technique a été masqué et doit être considéré
  /// comme compromis s'il a déjà quitté la machine.
  final List<String> warnings;

  /// Rapport de risque de ré-identification, seulement si l'appelant a fourni
  /// `riskReference` à `Ecluse.redact` ; `null` signifie « fonction inactive »,
  /// **pas** « aucun risque ». Ne modifie ni [maskedText] ni [mapping].
  final RiskReport? risque;

  /// Entités ajoutées à la main dans un aperçu (`Apercu.applique`), déjà
  /// comprises dans [entities] : c'est leur marque de provenance. Toujours
  /// vide pour `Ecluse.redact`.
  final List<DetectedEntity> manuelles;
}
