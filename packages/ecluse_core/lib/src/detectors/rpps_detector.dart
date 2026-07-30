import '../detector.dart';
import '../entity.dart';
import '../luhn.dart';

/// Détecteur de numéros RPPS — Répertoire Partagé des Professionnels de
/// Santé, l'identifiant national unique des professionnels de santé
/// français (médecins, pharmaciens, infirmiers, etc.).
///
/// Structure : 11 chiffres, dont le dernier est une clé de contrôle
/// calculée selon l'algorithme de Luhn sur le numéro complet.
///
/// Contrairement au NIR, le RPPS n'a pas de structure interne vérifiable
/// (pas de mois, pas de département) : la validation repose uniquement sur
/// la longueur et la clé de Luhn. Un nombre aléatoire de 11 chiffres a
/// environ 10 % de chances de passer Luhn, d'où une confiance de 0.9 et
/// non 1.0 — c'est l'illustration du modèle de confiance graduée d'Écluse.
final class RppsDetector implements EntityDetector {
  const RppsDetector();

  @override
  EntityType get type => EntityType.rpps;

  /// 11 chiffres, séparés au plus par une espace, non enchâssés dans une
  /// séquence de chiffres plus longue.
  static final RegExp _candidate = RegExp(
    r'(?<![0-9])[0-9](?: ?[0-9]){10}(?![0-9])',
  );

  /// Forme syntaxique d'un IBAN FR (mêmes tolérances que
  /// `IbanFrDetector._candidate`), **sans validation de la clé de
  /// contrôle**.
  ///
  /// Un IBAN affiché par blocs de chiffres séparés d'un espace unique a
  /// exactement la forme que tolère [_candidate] (un chiffre puis jusqu'à
  /// dix fois « espace optionnel + chiffre ») : une somme de blocs
  /// consécutifs totalisant 11 chiffres peut passer Luhn par coïncidence.
  /// Quand l'IBAN englobant est lui-même invalide, `IbanFrDetector` ne
  /// produit aucune entité — rien pour départager ce faux positif via
  /// `resolveOverlaps`. Se fier à la seule *forme* (pas à la validité)
  /// écarte le candidat à la source, que l'IBAN soit valide ou non.
  static final RegExp _ibanShapedContext = RegExp(
    r'(?<![A-Za-z0-9])[Ff][Rr][0-9]{2}(?:[ \-]?[0-9A-Za-z]){23}(?![0-9A-Za-z])',
  );

  @override
  List<DetectedEntity> detect(String text) {
    final ibanShapedRanges = [
      for (final m in _ibanShapedContext.allMatches(text)) (m.start, m.end),
    ];

    final results = <DetectedEntity>[];
    for (final match in _candidate.allMatches(text)) {
      final raw = match.group(0)!;
      final digits = raw.replaceAll(' ', '');
      if (!isLuhnValid(digits)) continue;
      final embeddedInIban = ibanShapedRanges.any(
        (r) => match.start < r.$2 && r.$1 < match.end,
      );
      if (embeddedInIban) continue;
      results.add(
        DetectedEntity(
          type: EntityType.rpps,
          start: match.start,
          end: match.end,
          value: raw,
          confidence: 0.9,
        ),
      );
    }
    return results;
  }
}
