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
/// d'organisation, pas une fuite — coût acceptable (cf. `LIMITES.md` § 1).
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

  /// Écriture groupée usuelle d'un FINESS, « 12 345 678 9 » (2-3-3-1), avec
  /// une espace simple entre les groupes (P2-174).
  ///
  /// Pourquoi un second motif : sans nombre voisin, la compaction ramène
  /// cette écriture à neuf chiffres collés et [_candidate] suffit. Mais suivi
  /// d'une date, d'un âge ou d'une quantité (`12 345 678 9 12/03/2024`), la
  /// compaction soude le voisin, [_candidate] voit onze chiffres et rejette :
  /// le FINESS partait en clair (312 cas sur 800 au témoin
  /// `bench/generate_corpus_identifiant_suivi.py`). Ce motif n'est cherché que
  /// sur le texte d'origine et sur le texte régularisé, où les espaces
  /// subsistent. Groupement **strict** et espace seule : un point ou un tiret
  /// rouvrirait la fenêtre de neuf chiffres dans un NIR ou un RPPS pointé
  /// (voir [_candidate]) ; les groupes d'un NIR (1-2-2-2-3-3-2), d'un RPPS
  /// (5-5-1) ou d'un IBAN (par 4) n'ont pas cette forme.
  static final RegExp _candidateGroupe =
      RegExp(r'(?<![0-9])[0-9]{2} [0-9]{3} [0-9]{3} [0-9](?![0-9])');

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
    final vus = <(int, int)>{};
    final candidats = [
      ...compaction.candidates(_candidate),
      ...compaction.candidates(_candidateGroupe),
    ]..sort((a, b) => a.start - b.start);
    for (final match in candidats) {
      final digits = match.text.replaceAll(' ', '');
      if (!isLuhnValid(digits)) continue;

      final start = match.start;
      final end = match.end;
      if (!vus.add((start, end))) continue;
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
