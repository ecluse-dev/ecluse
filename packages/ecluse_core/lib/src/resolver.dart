import 'dart:collection';

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

  // Les entités retenues sont disjointes : parmi elles, seule celle qui commence
  // le plus tard avant la fin du candidat peut le chevaucher (les suivantes
  // commencent après sa fin, les précédentes finissent avant son début). Une table
  // triée par début donne cette entité en O(log n) au lieu de comparer le candidat
  // à toutes les retenues (80 000 entités : 18 s, P2-66).
  final kept = SplayTreeMap<int, DetectedEntity>();
  for (final candidate in byPriority) {
    final avant = kept.lastKeyBefore(candidate.end);
    final overlaps = avant != null && kept[avant]!.end > candidate.start;
    if (!overlaps) kept[candidate.start] = candidate;
  }

  return kept.values.toList();
}
