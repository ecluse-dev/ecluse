import '../detector.dart';
import '../entity.dart';

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

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _candidate.allMatches(text)) {
      final raw = match.group(0)!;
      final digits = raw.replaceAll(' ', '');
      if (_isLuhnValid(digits)) {
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
    }
    return results;
  }

  /// Algorithme de Luhn standard : en partant de la droite, double un
  /// chiffre sur deux (en retranchant 9 si le résultat dépasse 9) ; la
  /// somme totale doit être un multiple de 10.
  static bool _isLuhnValid(String digits) {
    var sum = 0;
    var double = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits.codeUnitAt(i) - 0x30;
      if (double) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      double = !double;
    }
    return sum % 10 == 0;
  }
}
