import 'detection/detector_tier.dart';
import 'entity.dart';

/// Résout les chevauchements entre entités issues de plusieurs détecteurs.
///
/// Quand deux détections se chevauchent (ex. une fenêtre de 11 chiffres
/// passant Luhn par hasard à l'intérieur d'un IBAN groupé par 4), une
/// seule doit survivre. Règle de priorité :
///
/// 1. l'entité la plus **longue** gagne (elle porte plus de contexte) ;
/// 2. à longueur égale, la **confiance** la plus haute ;
/// 3. à confiance égale, le `tier` le plus fiable (structurel > référence
///    > motif > statistique — voir `DetectorTier`) ;
/// 4. à tier égal (ou absent des deux côtés), la plus à **gauche**.
///
/// Retourne une liste triée par position de début, sans chevauchements.
/// Ce comportement a été ajouté après que le harnais de benchmark a mis
/// en évidence des faux positifs RPPS enchâssés dans des IBAN (voir
/// `bench/README.md`). Le critère de `tier` (Jalon 1 du refactor detection/)
/// n'a d'effet qu'à partir du moment où plusieurs tiers coexistent au même
/// endroit — un seul tier par position aujourd'hui, donc sortie inchangée.
List<DetectedEntity> resolveOverlaps(List<DetectedEntity> entities) {
  final byPriority = [...entities]..sort((a, b) {
      final lengthA = a.end - a.start;
      final lengthB = b.end - b.start;
      if (lengthA != lengthB) return lengthB - lengthA;
      final byConfidence = b.confidence.compareTo(a.confidence);
      if (byConfidence != 0) return byConfidence;
      final tierA = a.tier?.priority ?? -1;
      final tierB = b.tier?.priority ?? -1;
      if (tierA != tierB) return tierB - tierA;
      return a.start - b.start;
    });

  final kept = <DetectedEntity>[];
  for (final candidate in byPriority) {
    final overlaps = kept.any(
      (k) => candidate.start < k.end && k.start < candidate.end,
    );
    if (!overlaps) kept.add(candidate);
  }

  kept.sort((a, b) => a.start - b.start);
  return kept;
}
