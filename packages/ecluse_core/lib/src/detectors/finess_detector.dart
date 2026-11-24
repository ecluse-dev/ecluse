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
///
/// **SIREN nommé (P2-248).** Quand le texte appelle le nombre « SIREN » ou
/// « SIRET » (même fenêtre de 40 caractères que le mot « FINESS », avant ou
/// après), l'entité est de type [EntityType.siren], à confiance haute : le
/// mot lève l'ambiguïté que la structure ne peut pas lever, et le SIREN d'un
/// entrepreneur individuel désigne une personne, donc il reste **masqué**. Si
/// le mot « FINESS » est aussi dans la fenêtre, le FINESS l'emporte (deux mots
/// contradictoires : la lecture « établissement de santé » garde son type
/// d'avant). Sans aucun des deux mots, rien ne change : FINESS à confiance
/// basse.
///
/// **SIRET nommé (P2-259).** Quatorze chiffres (collés, ou groupés « 3 3 3 5 »)
/// à moins de 40 caractères du mot « SIRET » sont masqués en entier, type
/// [EntityType.siren] : le SIRET contient le SIREN, qui désigne une personne
/// quand il s'agit d'un entrepreneur individuel (décision du 23 novembre).
/// Clé de Luhn sur les quatorze chiffres juste : confiance haute ; fausse :
/// confiance [confianceSiretCleFausse] (0,3), que `Ecluse.redact` accompagne de
/// l'avertissement « identifiant à clé invalide masqué : à vérifier ». Sans le
/// mot « SIRET », quatorze chiffres ne sont jamais masqués (aucun gabarit
/// propre) : le coût est un sur-masquage de quatorze chiffres que le texte
/// appelle « SIRET », jamais une fuite.
///
/// **Numéro de TVA intracommunautaire (P2-260).** « FR » + clé de deux
/// caractères + SIREN de neuf chiffres (blancs simples admis entre les
/// groupes) : masqué en entier, type [EntityType.siren], pour la même raison
/// que le SIREN nommé. La clé se vérifie par calcul, `(12 + 3 × (SIREN mod 97))
/// mod 97` : clé juste (deux chiffres) → confiance haute, sans libellé exigé ;
/// clé fausse ou à lettre → seulement si « TVA » ou « intracommunautaire » est
/// à moins de 40 caractères, confiance [confianceTvaCleFausse] (0,3) avec
/// l'avertissement « à vérifier » de `Ecluse.redact`. L'entité (treize
/// caractères) l'emporte dans `resolveOverlaps` sur le RPPS de onze chiffres
/// qu'une clé et un SIREN formaient par hasard (6 cas sur 35 au corpus étendu,
/// « FR » restait en clair). Coût : « FR » + onze chiffres dont la clé est
/// juste (1 chance sur 97) qui n'est pas une TVA est masqué : sur-masquage,
/// jamais une fuite.
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

  /// Mots qui nomment un SIREN (« SIRET » : son préfixe de neuf chiffres).
  static final RegExp _sirenKeyword = RegExp('siren|siret');

  /// Quatorze chiffres d'un SIRET, collés après compaction (P2-259).
  static final RegExp _siretCandidate = RegExp(r'(?<![0-9])[0-9]{14}(?![0-9])');

  /// Écriture groupée « 732 829 320 00124 » (3-3-3-5), espace simple : comme
  /// [_candidateGroupe], pour qu'un nombre voisin soudé par la compaction ne
  /// fasse pas rejeter le SIRET.
  static final RegExp _siretGroupe =
      RegExp(r'(?<![0-9])[0-9]{3} [0-9]{3} [0-9]{3} [0-9]{5}(?![0-9])');

  /// Confiance d'un SIRET nommé dont la clé de Luhn est fausse (P2-259) : la
  /// même que les autres identifiants à clé invalide masqués à tort permis.
  static const double confianceSiretCleFausse = 0.3;

  /// « FR » + clé (deux caractères) + SIREN, avec au plus un blanc simple (espace
  /// ou insécable) entre « FR », la clé et chaque groupe de trois chiffres
  /// (P2-260). Lu sur le texte d'origine, hors compaction.
  static final RegExp _tvaCandidate = RegExp(
    r'(?<![0-9A-Za-z])[Ff][Rr][ \u00A0\u202F]?[0-9A-Za-z]{2}'
    r'[ \u00A0\u202F]?[0-9]{3}[ \u00A0\u202F]?[0-9]{3}[ \u00A0\u202F]?[0-9]{3}'
    r'(?![0-9A-Za-z])',
  );

  /// Libellé qui annonce une TVA : le mot « TVA » entier ou « intracommunautaire ».
  static final RegExp _tvaLibelle = RegExp(r'\btva\b|intracommunautaire');

  /// Confiance d'une TVA à clé fausse derrière son libellé (P2-260).
  static const double confianceTvaCleFausse = 0.3;

  /// Luhn OK + indice de contexte à proximité.
  static const double _highConfidence = 0.9;

  /// Luhn OK seul, sans contexte — collision SIREN assumée.
  static const double _lowConfidence = 0.5;

  /// Blanc ou séparateur facultatif, puis groupe de un à trois caractères parmi
  /// chiffres et confusions d'OCR (o, O, l, I) dont au moins une lettre, collé
  /// à la suite d'un FINESS sans contexte (P2-276).
  static final RegExp _suiteAbimee = RegExp(
    r'[\s\u00A0\u202F.\-/]?(?=[0-9oOlI]{0,2}[oOlI])[0-9oOlI]{1,3}'
    r'(?![0-9A-Za-z])',
  );

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
      final fenetre = _fenetre(raw, start, end);
      final hasContext = fenetre.contains(_contextKeyword);
      final siren = !hasContext && _sirenKeyword.hasMatch(fenetre);
      // Sans contexte, neuf chiffres suivis d'un groupe court à lettre de
      // confusion d'OCR (« 697 296 556 I1 ») sont un identifiant plus long
      // (P2-276). Avec contexte ou mot SIREN, la suite ne compte pas.
      if (!hasContext &&
          !siren &&
          _suiteAbimee.matchAsPrefix(raw, end) != null) {
        continue;
      }
      results.add(
        DetectedEntity(
          type: siren ? EntityType.siren : EntityType.finess,
          start: start,
          end: end,
          value: raw.substring(start, end),
          confidence: (hasContext || siren) ? _highConfidence : _lowConfidence,
        ),
      );
    }
    final siretVus = <(int, int)>{};
    final siret = [
      ...compaction.candidates(_siretCandidate),
      ...compaction.candidates(_siretGroupe),
    ]..sort((a, b) => a.start - b.start);
    for (final match in siret) {
      if (!siretVus.add((match.start, match.end))) continue;
      if (!_fenetre(raw, match.start, match.end).contains('siret')) continue;
      final juste = isLuhnValid(match.text.replaceAll(' ', ''));
      results.add(
        DetectedEntity(
          type: EntityType.siren,
          start: match.start,
          end: match.end,
          value: raw.substring(match.start, match.end),
          confidence: juste ? _highConfidence : confianceSiretCleFausse,
        ),
      );
    }
    for (final m in _tvaCandidate.allMatches(raw)) {
      final compact = m.group(0)!.replaceAll(RegExp(r'[ \u00A0\u202F]'), '');
      final cle = compact.substring(2, 4);
      final siren = compact.substring(4);
      final cleNumerique = int.tryParse(cle);
      final juste = cleNumerique != null &&
          RegExp(r'^[0-9]{2}$').hasMatch(cle) &&
          cleNumerique == (12 + 3 * (int.parse(siren) % 97)) % 97;
      if (!juste && !_tvaLibelle.hasMatch(_fenetre(raw, m.start, m.end))) {
        continue;
      }
      results.add(
        DetectedEntity(
          type: EntityType.siren,
          start: m.start,
          end: m.end,
          value: raw.substring(m.start, m.end),
          confidence: juste ? _highConfidence : confianceTvaCleFausse,
        ),
      );
    }
    return results;
  }

  /// Texte en minuscules dans une fenêtre de [_contextWindow] caractères autour
  /// de `raw[start:end)`, où l'on cherche les mots de contexte.
  static String _fenetre(String raw, int start, int end) {
    final windowStart = (start - _contextWindow).clamp(0, raw.length);
    final windowEnd = (end + _contextWindow).clamp(0, raw.length);
    return raw.substring(windowStart, windowEnd).toLowerCase();
  }
}
