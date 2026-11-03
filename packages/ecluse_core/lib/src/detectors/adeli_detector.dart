import '../detection/detector.dart';
import '../detection/detector_tier.dart';
import '../detection/normalized_text.dart';
import '../digit_compaction.dart';
import '../entity.dart';
import '../luhn.dart';

/// Détecteur de numéros ADELI — identifiant des professionnels de santé
/// enregistrés avant la bascule vers le RPPS (spec : `agent/specs/P1-06-adeli.md`).
///
/// Structure : 9 caractères. **Contexte obligatoire** : un ADELI numérique
/// n'est émis que si le mot « ADELI » est accolé au nombre. Sans ce mot, la
/// structure ne distingue pas un ADELI d'un SIREN ou d'un FINESS (même
/// longueur, même Luhn) : ce cas reste couvert par `FinessDetector`, sans
/// régression de protection.
///
/// **Clé de contrôle** : Luhn sur les 9 chiffres. Les sources consultées ne
/// fournissent pas l'algorithme officiel (fiche ANS non lue) ; Luhn est une
/// hypothèse de travail, cohérente avec le FINESS et le RPPS, et c'est
/// pourquoi une clé invalide n'écarte jamais un nombre explicitement étiqueté.
///
/// **Exception assumée à « détection stricte »** (décision du mainteneur,
/// `DECISIONS.md`) : un nombre de 9 chiffres à clé invalide, ou un numéro
/// corse (`2A`/`2B` + 7 chiffres, sans règle de clé établie), est masqué à
/// confiance 0,6 **uniquement** avec « ADELI » accolé. Un champ explicitement
/// étiqueté ADELI et mal saisi doit être masqué plutôt que laissé en clair.
final class AdeliDetector implements Detector {
  const AdeliDetector();

  @override
  DetectorTier get tier => DetectorTier.structural;

  @override
  String get name => 'adeli';

  @override
  Future<List<DetectedEntity>> detect(NormalizedText text) async =>
      _detectSync(text.raw);

  static final RegExp _numeric = RegExp(r'(?<![0-9])[0-9]{9}(?![0-9])');

  /// Département corse (lettre à la place d'un chiffre) + 7 chiffres.
  static final RegExp _corse =
      RegExp(r'(?<![0-9A-Za-z])2[ABab][0-9]{7}(?![0-9A-Za-z])');

  /// « Accolé » : le mot précède le nombre, avec au plus 30 caractères entre
  /// les deux (libellé `n°`, `numéro`, `saisi par erreur :`…), sans chiffre ni
  /// fin de phrase. Au-delà, ou après un point, le mot n'étiquette plus ce
  /// nombre. Évalué sur le texte qui précède le candidat, en minuscules.
  static final RegExp _prefix = RegExp(r'adeli[^0-9.!?\n]{0,30}$');

  /// Clé Luhn valide + mot accolé : plus fort qu'un FINESS de contexte
  /// (0,9), pour que l'étiquette « adeli » l'emporte dans `resolveOverlaps`.
  static const double _highConfidence = 0.95;

  /// Clé invalide ou numéro corse : forme plausible sans clé vérifiée.
  static const double _lowConfidence = 0.6;

  /// Fenêtre examinée avant le candidat (mot + 30 caractères de libellé).
  static const int _lookBehind = 40;

  static List<DetectedEntity> _detectSync(String raw) {
    final results = <DetectedEntity>[];

    for (final match in DigitCompaction(raw).candidates(_numeric)) {
      if (!_hasKeywordBefore(raw, match.start)) continue;
      results.add(_entity(
        raw,
        match.start,
        match.end,
        isLuhnValid(match.text) ? _highConfidence : _lowConfidence,
      ));
    }

    for (final match in _corse.allMatches(raw)) {
      if (!_hasKeywordBefore(raw, match.start)) continue;
      results.add(_entity(raw, match.start, match.end, _lowConfidence));
    }
    return results;
  }

  static DetectedEntity _entity(
    String raw,
    int start,
    int end,
    double confidence,
  ) =>
      DetectedEntity(
        type: EntityType.adeli,
        start: start,
        end: end,
        value: raw.substring(start, end),
        confidence: confidence,
      );

  static bool _hasKeywordBefore(String raw, int start) {
    final from = (start - _lookBehind).clamp(0, start);
    return _prefix.hasMatch(raw.substring(from, start).toLowerCase());
  }
}
