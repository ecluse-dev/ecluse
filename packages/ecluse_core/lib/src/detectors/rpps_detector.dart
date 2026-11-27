import '../detector.dart';
import '../digit_compaction.dart';
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

  /// 11 chiffres, séparés au plus par un espace, un point ou un tiret, non
  /// enchâssés dans une séquence de chiffres plus longue.
  ///
  /// S'applique au texte *compacté* par [DigitCompaction] : les blancs
  /// exotiques (NBSP, espace fine insécable, tabulation, espaces multiples)
  /// y ont déjà disparu, comme pour `NirDetector`.
  static final RegExp _candidate = RegExp(
    r'(?<![0-9])[0-9](?:[ .\-]?[0-9]){10}(?![0-9])',
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
    r'(?<![A-Za-z0-9])[Ff][Rr][0-9]{2}(?:[ \-./]?[0-9A-Za-z]){23}(?![0-9A-Za-z])',
  );

  /// Pas de garde « FINESS suivi d'une date » (P2-306). Neuf chiffres de Luhn
  /// juste, un blanc, deux chiffres puis une date ou « ans » se lisent comme
  /// un FINESS suivi du jour d'une date, mais aussi comme un RPPS écrit en deux
  /// groupes ; rien ne les départage. Une garde de P2-174 écartait ce candidat
  /// et les deux derniers chiffres d'un RPPS partaient en clair (mesure
  /// P2-303 : 39 / 39, 117 caractères sur 468). Décision du mainteneur, « dans
  /// le doute, masquer » : les onze chiffres sont masqués en entier. Coût : un
  /// FINESS suivi d'un jour dont les onze chiffres passent Luhn (un sur dix)
  /// est masqué comme RPPS, jour compris (`LIMITES.md`).

  /// Mêmes entités que [detect], mais **sans** l'écart d'un candidat qui finit
  /// au milieu d'une date complète (`DigitCompaction`). Sert uniquement à
  /// mesurer ce que cette garde écarte (P2-309, principe du 26 novembre,
  /// point 0) : la différence avec [detect] donne les candidats écartés.
  /// Ne produit aucun masquage.
  List<DetectedEntity> detectSansGardeDate(String text) =>
      _detecte(text, ecarteDevantDate: false);

  @override
  List<DetectedEntity> detect(String text) => _detecte(text);

  List<DetectedEntity> _detecte(String text, {bool ecarteDevantDate = true}) {
    final results = <DetectedEntity>[];
    final compaction =
        DigitCompaction(text, ecarteDevantDate: ecarteDevantDate);
    // La forme d'IBAN est cherchée par les mêmes passages que les candidats
    // (P2-174) : sinon un IBAN à blancs irréguliers (insécables, espaces
    // multiples), que le passage régularisé lit maintenant groupe par groupe,
    // n'était plus reconnu comme contexte et l'un de ses blocs de onze
    // chiffres pouvait passer pour un RPPS.
    final ibanShapedRanges = [
      for (final m in compaction.candidates(_ibanShapedContext))
        (m.start, m.end),
    ];
    for (final match in compaction.candidates(_candidate)) {
      // Positions déjà dans le texte d'origine (invariant d'offsets).
      final start = match.start;
      final end = match.end;
      final digits = match.text.replaceAll(RegExp(r'[ .\-]'), '');
      if (!isLuhnValid(digits)) continue;
      final embeddedInIban = ibanShapedRanges.any(
        (r) => start < r.$2 && r.$1 < end,
      );
      if (embeddedInIban) continue;
      results.add(
        DetectedEntity(
          type: EntityType.rpps,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: 0.9,
        ),
      );
    }
    return results;
  }
}
