/// Origine d'une détection, du plus fiable au plus incertain.
/// Sert au départage dans `resolveOverlaps` et, plus tard, à pondérer
/// la confiance et à savoir ce qui tourne on-device sans modèle.
enum DetectorTier {
  structural, // clé de contrôle vérifiée (NIR, RPPS, IBAN, FINESS, ADELI)
  reference, // présence dans une liste/gazetteer (commune, profession, prénom)
  pattern, // regex / heuristique de format (email, téléphone, date)
  statistical, // modèle NER (différé)
}

/// Priorité de départage en cas d'égalité (plus haut = gagne).
extension DetectorTierPriority on DetectorTier {
  int get priority => switch (this) {
        DetectorTier.structural => 3,
        DetectorTier.reference => 2,
        DetectorTier.pattern => 1,
        DetectorTier.statistical => 0,
      };
}
