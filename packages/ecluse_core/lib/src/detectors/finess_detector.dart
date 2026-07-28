import '../detection/detector.dart';
import '../detection/detector_tier.dart';
import '../detection/normalized_text.dart';
import '../digit_compaction.dart';
import '../entity.dart';
import '../luhn.dart';

/// Détecteur de numéros FINESS — identifiant national d'établissement de
/// santé français (Fichier National des Établissements Sanitaires et
/// Sociaux).
///
/// Structure : 9 chiffres, dont le dernier est une clé de contrôle Luhn
/// mod 10 (source : documentation SNDS / Health Data Hub) — le même
/// algorithme que `RppsDetector`, réutilisé ici sans duplication.
///
/// **Collision structurelle avec le SIREN** (identifiant d'entreprise
/// français, 9 chiffres, même Luhn) : la validation structurelle ne peut
/// **pas** distinguer un FINESS d'un SIREN — contrairement au NIR/RPPS/IBAN,
/// dont les structures sont uniques. Ce détecteur ne prétend pas résoudre
/// cette ambiguïté par la structure ; il gradue la confiance selon la
/// présence d'un indice de contexte (« FINESS » à proximité) : confiance
/// haute si présent, basse sinon (collision SIREN assumée). Un SIREN
/// capté par erreur à confiance basse est un sur-masquage d'un identifiant
/// d'organisation, pas une fuite — coût acceptable (cf. `NOTES_SECURITE`).
///
/// Le préfixe département (2 premiers chiffres) n'est délibérément **pas**
/// vérifié, même comme signal doux : le format outre-mer reste incertain
/// (sources contradictoires) et le modèle de confiance de ce détecteur est
/// déjà entièrement défini par Luhn + contexte — ajouter une vérification
/// de préfixe non branchée sur une décision réelle serait du code mort.
final class FinessDetector implements Detector {
  const FinessDetector();

  @override
  DetectorTier get tier => DetectorTier.structural;

  @override
  String get name => 'finess';

  @override
  Future<List<DetectedEntity>> detect(NormalizedText text) async =>
      _detectSync(text.raw);

  /// 9 chiffres exacts après `DigitCompaction` (espacements irréguliers
  /// déjà neutralisés), sans tolérance de séparateur additionnelle dans le
  /// motif lui-même : tolérer un point/tiret par chiffre (comme le fait
  /// `NirDetector`) rouvrirait une fenêtre de 9 chiffres valide à
  /// l'intérieur d'un NIR ou RPPS **pointé**, puisque `DigitCompaction` ne
  /// neutralise que les espaces, jamais la ponctuation.
  static final RegExp _candidate = RegExp(r'(?<![0-9])[0-9]{9}(?![0-9])');

  /// Fenêtre de recherche du mot-clé de contexte, en caractères de chaque
  /// côté du match (sur le texte brut).
  static const int _contextWindow = 40;

  /// Seul indice de contexte nécessaire : les variantes du §2 du spec
  /// (« FINESS », « N° FINESS », « n°FINESS », « établissement … FINESS »)
  /// contiennent toutes littéralement cette sous-chaîne, insensible à la
  /// casse — pas besoin de pliage d'accents ici.
  static const String _contextKeyword = 'finess';

  /// Luhn OK + indice de contexte à proximité.
  static const double _highConfidence = 0.9;

  /// Luhn OK seul, sans contexte — collision SIREN assumée.
  static const double _lowConfidence = 0.5;

  static List<DetectedEntity> _detectSync(String raw) {
    final compaction = DigitCompaction(raw);
    final results = <DetectedEntity>[];
    for (final match in _candidate.allMatches(compaction.compact)) {
      final digits = match.group(0)!;
      if (!isLuhnValid(digits)) continue;

      final start = compaction.originalStart(match.start);
      final end = compaction.originalEnd(match.end);
      final hasContext = _hasContext(raw, start, end);
      results.add(
        DetectedEntity(
          type: EntityType.finess,
          start: start,
          end: end,
          value: raw.substring(start, end),
          confidence: hasContext ? _highConfidence : _lowConfidence,
        ),
      );
    }
    return results;
  }

  /// Le mot-clé « finess » apparaît-il dans une fenêtre de
  /// [_contextWindow] caractères autour de `raw[start:end)` ?
  static bool _hasContext(String raw, int start, int end) {
    final windowStart = (start - _contextWindow).clamp(0, raw.length);
    final windowEnd = (end + _contextWindow).clamp(0, raw.length);
    return raw
        .substring(windowStart, windowEnd)
        .toLowerCase()
        .contains(_contextKeyword);
  }
}
