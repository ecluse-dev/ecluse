import 'package:ecluse_core/ecluse_core.dart';

import 'french_first_names.dart';

/// Détecteur heuristique de noms de personnes — **v0 de démonstration**.
///
/// Contrairement aux détecteurs d'`ecluse_core`, il n'y a ici aucune clé
/// de contrôle possible : un nom propre n'a pas de structure vérifiable.
/// Ce détecteur combine deux indices :
///
/// 1. Une **civilité** (`M.`, `Mme`, `Monsieur`, `Madame`, `Dr`, `Docteur`,
///    `Me`) suivie d'un ou deux mots capitalisés → confiance haute (0.9) :
///    l'indice est fort et rarement un faux positif.
/// 2. Un **prénom français connu** (voir [frenchFirstNames]) adjacent à un
///    mot capitalisé (nom de famille supposé) → confiance moyenne (0.6).
///    Règle **bidirectionnelle** : le mot capitalisé peut précéder le
///    prénom (ordre « Nom Prénom », ex. « Dubreuil Thomas », ou convention
///    administrative tout-majuscules « DANNER Laurent ») ou le suivre
///    (ordre « Prénom Nom », ex. « Sophie Lambert »), sans condition de
///    casse dans un sens comme dans l'autre. Un prénom **composé** avec
///    tiret (« Jean-Marc », « Anne-Sophie ») est reconnu dès qu'un de ses
///    segments est un prénom connu — le motif capitalisé gourmand avale
///    déjà le tiret comme un seul jeton, donc le comparer tel quel au
///    gazetteer échouerait toujours. Un prénom peut aussi être un nom
///    commun capitalisé par erreur, ou le mot adjacent n'être pas un nom de
///    famille : d'où la confiance moyenne plutôt que haute. Limite connue
///    de cette symétrie : un mot capitalisé par simple position de début
///    de phrase (salutation, connecteur) et adjacent à un prénom connu peut
///    être capturé à tort — voir `LIMITES.md`.
/// 3. Un **prénom français connu** utilisé seul, sans nom de famille qui
///    suit (ex. « Sophie rappelle que… » dans un compte rendu où l'on
///    ne mentionne plus qu'un prénom une fois la personne présentée) →
///    confiance plus faible (0.5), mais détecté quand même : dans cette
///    version, on ne filtre jamais par confiance (voir `Ecluse.redact`),
///    donc un prénom isolé est masqué plutôt que de fuiter.
///
/// Un mot capitalisé isolé, sans civilité ni prénom reconnu (ex. début de
/// phrase), n'est **jamais** masqué : ce serait trop de faux positifs pour
/// une démonstration crédible.
///
/// Sera remplacé en phase 2 par un modèle NER local (voir ROADMAP.md).
final class NameDetector implements EntityDetector {
  const NameDetector();

  @override
  EntityType get type => EntityType.nom;

  static final RegExp _civility = RegExp(
    r'\b(?:M\.|Mme|Monsieur|Madame|Dr\.?|Docteur|Me)\s+'
    r"([A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*"
    r"(?:\s+[A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*)?)",
  );

  static final RegExp _capitalizedWord = RegExp(
    r"[A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*",
  );

  /// Mot capitalisé suivi uniquement d'espaces jusqu'à la fin de la chaîne
  /// passée : sert à trouver le mot juste avant une position [before] dans
  /// le texte complet, en appelant ce motif sur `text.substring(0, before)`
  /// — les indices du groupe capturé restent alors valides dans `text`.
  static final RegExp _wordBeforeEnd = RegExp(
    r"([A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*) +$",
  );

  /// Sigles métier — administratifs et cliniques — qui ne doivent jamais
  /// être traités comme un nom, **même écrits tout en majuscules et même
  /// s'ils coïncident avec un prénom du gazetteer** (ex. « EVA », Échelle
  /// Visuelle Analogique, qui est aussi un prénom français courant).
  ///
  /// La plupart des sigles métier sont déjà à l'abri par simple absence du
  /// gazetteer (voir le test de non-régression sur SSIAD, CARSAT, etc.) :
  /// cette liste protège spécifiquement les cas **ambigus**, où le sigle
  /// coïncide avec une entrée du gazetteer, plus une couverture générale
  /// des sigles cliniques/échelles courants du secteur médico-social —
  /// domaine cœur d'Écluse — pour éviter d'effacer une donnée clinique.
  /// Comparaison volontairement **sensible à la casse** : un prénom réel
  /// écrit normalement (« Eva ») reste détecté, seule la forme MAJUSCULE
  /// conventionnelle du sigle est exclue.
  static const _excludedAcronyms = {
    // Sigles administratifs et structures (secteur médico-social).
    'SSIAD', 'CARSAT', 'SAMSAH', 'EHPAD', 'MSP', 'PCH', 'PRADO', 'ALD',
    'CPTS', 'IDEL', 'UDAF', 'MDPH', 'CCAS', 'HAD', 'RCP', 'IPS', 'APA',
    'IDE', 'IDEC', 'ESAT', 'CSE', //
    // Échelles et sigles cliniques courants.
    'EVA', 'EVS', 'EN', 'ADL', 'IADL', 'MMS', 'MMSE', 'GIR', 'AGGIR',
    'ECPA', 'GCS', 'ECG', 'EEG', 'IRM', 'TDM', 'VNI', 'AVC', 'IDM', 'HTA',
    'BPCO', 'IRC', 'IRA', 'AVK', 'INR', 'TSH', 'NFS', 'CRP', 'IMC', 'ETP',
    'ASH', 'AMP', 'PTH', //
  };

  static bool _isExcludedAcronym(String word) =>
      _excludedAcronyms.contains(word);

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    final claimed = <_Range>[];

    for (final match in _civility.allMatches(text)) {
      final name = match.group(1)!;
      final nameStart =
          match.end - name.length; // groupe 1 ancré en fin de match
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: nameStart,
          end: match.end,
          value: name,
          confidence: 0.9,
        ),
      );
      claimed.add(_Range(match.start, match.end)); // réserve civilité + nom
    }

    for (final match in _capitalizedWord.allMatches(text)) {
      final word = match.group(0)!;
      if (_isExcludedAcronym(word)) continue;
      if (!_looksLikeKnownFirstName(word)) continue;
      if (claimed.any((r) => r.overlaps(match.start, match.end))) continue;

      // Règle bidirectionnelle : un nom de famille supposé peut précéder
      // ou suivre le prénom reconnu, sans condition de casse dans un sens
      // comme dans l'autre (voir le commentaire de classe).
      final before = _matchPrevCapitalizedWord(text, match.start);
      final hasFreeLastNameBefore = before != null &&
          !claimed.any((r) => r.overlaps(before.start, before.end));

      final after = _matchNextCapitalizedWord(text, match.end);
      final hasFreeLastNameAfter = after != null &&
          !claimed.any((r) => r.overlaps(after.start, after.end));

      final int start;
      final int end;
      final double confidence;
      if (hasFreeLastNameBefore) {
        start = before.start;
        end = match.end;
        confidence = 0.6;
      } else if (hasFreeLastNameAfter) {
        start = match.start;
        end = after.end;
        confidence = 0.6;
      } else {
        start = match.start;
        end = match.end;
        confidence = 0.5;
      }
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: confidence,
        ),
      );
      claimed.add(_Range(start, end));
    }

    results.sort((a, b) => a.start - b.start);
    return results;
  }

  /// [word] est-il un prénom français connu, tel quel ou via l'un de ses
  /// segments s'il s'agit d'un prénom composé (« Jean-Marc », « Anne-
  /// Sophie ») ? Le motif capitalisé englobe déjà le tiret dans un seul
  /// jeton (voir [_capitalizedWord]), donc un prénom composé n'apparaît
  /// jamais tel quel dans [frenchFirstNames] : il faut regarder ses
  /// segments plutôt que le jeton entier.
  static bool _looksLikeKnownFirstName(String word) {
    if (frenchFirstNames.contains(word.toLowerCase())) return true;
    if (!word.contains('-')) return false;
    return word
        .split('-')
        .any((part) => frenchFirstNames.contains(part.toLowerCase()));
  }

  /// Cherche le mot capitalisé suivant immédiatement (séparé uniquement par
  /// des espaces) la position [from]. Retourne `null` s'il n'y en a pas.
  ///
  /// `matchAsPrefix` ancre déjà la recherche à [from] : il ne faut pas de
  /// `^` dans le motif, qui référence le tout début de la chaîne et non la
  /// position de départ passée en argument.
  static Match? _matchNextCapitalizedWord(String text, int from) {
    final gapMatch = RegExp(r' +').matchAsPrefix(text, from);
    if (gapMatch == null) return null;
    final wordMatch = _capitalizedWord.matchAsPrefix(text, gapMatch.end);
    if (wordMatch == null || _isExcludedAcronym(wordMatch.group(0)!)) {
      return null;
    }
    return wordMatch;
  }

  /// Cherche un mot capitalisé (majuscules ou casse normale) séparé
  /// uniquement par des espaces de la position [before]. Retourne `null`
  /// s'il n'y en a pas, ou si ce mot est un sigle exclu (voir
  /// [_excludedAcronyms]) — un sigle ne doit jamais être avalé comme s'il
  /// s'agissait d'un nom de famille adjacent à un prénom reconnu.
  static _WordSpan? _matchPrevCapitalizedWord(String text, int before) {
    final head = text.substring(0, before);
    final match = _wordBeforeEnd.firstMatch(head);
    if (match == null) return null;
    final word = match.group(1)!;
    if (_isExcludedAcronym(word)) return null;
    // Le groupe capturé est en tête du motif : son début coïncide avec
    // celui du match entier.
    return _WordSpan(match.start, match.start + word.length);
  }
}

final class _WordSpan {
  const _WordSpan(this.start, this.end);
  final int start;
  final int end;
}

final class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;

  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && start < otherEnd;
}
