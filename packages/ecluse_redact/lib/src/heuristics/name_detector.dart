import 'package:ecluse_core/ecluse_core.dart';

import 'french_first_names.dart';

/// Détecteur heuristique de noms de personnes — **v0 de démonstration**.
///
/// Contrairement aux détecteurs d'`ecluse_core`, il n'y a ici aucune clé
/// de contrôle possible : un nom propre n'a pas de structure vérifiable.
/// Ce détecteur combine deux indices :
///
/// 1. Une **civilité** (`M.`, `Mme`, `Mademoiselle`, `Monsieur`, `Madame`,
///    `Dr`, `Docteur`, `Pr`, `Professeur`, `Me`) suivie d'un prénom puis
///    d'un patronyme de 1 à 2 mots (particules `de`, `du`, `des`, `le`,
///    `la`, `van`, `von` admises devant un mot en casse de titre) →
///    confiance haute (0.9) : l'indice
///    est fort et rarement un faux positif.
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
/// **Deuxième passe — mentions partielles rattrapées via un patronyme déjà
/// établi.** Une fois les mentions ci-dessus détectées avec certitude, leur
/// patronyme est extrait (voir [_extractSurname]) et recherché ailleurs
/// dans le **même document** — jamais dans une liste externe. Couvre :
/// nom de famille seul après une mention complète (« Dr Costa » après
/// « Dr Nadia Costa »), initiale + nom (« S. Reynaud » — seul le patronyme
/// est masqué, l'initiale reste visible comme une civilité), et patronyme
/// suivi d'un prénom non reconnu par le gazetteer (« Morel Hélène » après
/// « MOREL Antoine » — jeton **différent**, décidé par [Ecluse.redact] sur
/// la base du prénom distinct, pas par ce détecteur). Confiance 0.6, comme
/// l'appariement bidirectionnel dont cette passe réutilise la logique de
/// mot adjacent. Un patronyme qui coïncide avec un sigle exclu (voir
/// [_excludedAcronyms]) n'est jamais retenu pour cette recherche.
///
/// Sera remplacé en phase 2 par un modèle NER local (voir ROADMAP.md).
final class NameDetector implements EntityDetector {
  const NameDetector();

  @override
  EntityType get type => EntityType.nom;

  /// Capture prénom + jusqu'à 2 unités de patronyme supplémentaires
  /// (`PATRONYME{1,2}` de la spec adresse multiligne, borne basse ramenée à
  /// 0 pour préserver le comportement existant « civilité + un seul mot »,
  /// ex. `Dr Martin` -> `Martin`, un patronyme seul sans prénom qui suit).
  /// Chaque unité peut être précédée d'une particule en minuscules (`de`,
  /// `du`, `des`, `le`, `la`, `van`, `von`) à condition d'être suivie d'un
  /// mot en casse de titre — sinon la particule n'est jamais absorbée seule.
  ///
  /// Tous les séparateurs sont `[ \t]+` (espace horizontal), jamais `\s+` :
  /// la spec (§ 3) exige que civilité, prénom et patronyme restent sur la
  /// **même ligne**. `\s` matche aussi `\n`/`\r`, ce qui laissait le
  /// patronyme absorber le premier mot capitalisé de la ligne suivante.
  static final RegExp _civility = RegExp(
    r'\b(?:M\.|Mme|Mademoiselle|Monsieur|Madame|Dr\.?|Docteur|Pr\.?|'
    r'Professeur|Me)[ \t]+'
    r"([A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*"
    r'(?:[ \t]+(?:(?:de|du|des|le|la|van|von)[ \t]+)?'
    r"[A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*){0,2})",
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

  /// Titres professionnels : révèlent une profession, un quasi-identifiant
  /// de premier ordre en contexte hospitalier — le span masqué les inclut
  /// désormais (voir `LIMITES.md`). Périmètre strict et volontairement
  /// distinct des civilités de genre (`M.`, `Mme`, `Mademoiselle`,
  /// `Monsieur`, `Madame`), qui restent en clair : ce choix-là n'est pas
  /// tranché, celui-ci l'est. Comparaison sur le texte de civilité déjà
  /// matché (trim, sans l'espace de séparation), pas sur une nouvelle
  /// regex — la liste doit rester synchronisée avec l'alternation de
  /// [_civility].
  static const _professionalTitles = {
    'Dr', 'Dr.', 'Docteur', 'Pr', 'Pr.', 'Professeur', 'Me', //
  };

  static bool _isProfessionalTitle(String civility) =>
      _professionalTitles.contains(civility.trim());

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    // Parallèle à `results` (même index) : le nom seul, sans le titre
    // professionnel éventuel, pour la deuxième passe (voir
    // [_extractSurname]). Nécessaire parce que `results[i].value` inclut
    // désormais le titre pour une entité issue d'un titre professionnel,
    // ce qui casserait l'extraction du patronyme si on la lisait dessus.
    final surnameSources = <String>[];
    final claimed = <_Range>[];

    for (final match in _civility.allMatches(text)) {
      final name = match.group(1)!;
      final nameStart =
          match.end - name.length; // groupe 1 ancré en fin de match
      final civility = text.substring(match.start, nameStart);
      final includeTitle = _isProfessionalTitle(civility);
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: includeTitle ? match.start : nameStart,
          end: match.end,
          value: includeTitle ? text.substring(match.start, match.end) : name,
          confidence: 0.9,
        ),
      );
      surnameSources.add(name);
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
      surnameSources.add(text.substring(start, end));
      claimed.add(_Range(start, end));
    }

    // --- Deuxième passe : rattrapage des mentions partielles via un
    // patronyme déjà établi par la première passe (voir le commentaire de
    // classe). Ne s'exécute que si au moins un patronyme fiable a été
    // extrait — sur un document sans mention complète, rien ne change.
    //
    // Lit `surnameSources`, pas `results[i].value` : pour une entité issue
    // d'un titre professionnel, `value` inclut le titre (« Pr Nadia
    // Costa »), ce qui ferait échouer `_extractSurname` (borné à 1 ou 2
    // mots). `surnameSources[i]` reste le nom seul dans tous les cas.
    final knownSurnames = <String>{};
    for (var i = 0; i < results.length; i++) {
      final surname = _extractSurname(results[i].confidence, surnameSources[i]);
      if (surname == null || _isExcludedAcronym(surname)) continue;
      knownSurnames.add(surname.toLowerCase());
    }

    if (knownSurnames.isNotEmpty) {
      for (final match in _capitalizedWord.allMatches(text)) {
        final word = match.group(0)!;
        if (_isExcludedAcronym(word)) continue;
        if (!knownSurnames.contains(word.toLowerCase())) continue;
        if (claimed.any((r) => r.overlaps(match.start, match.end))) continue;

        // Uniquement la direction « après » (pas « avant ») : sans
        // vérification gazetteer sur le mot adjacent — le principe même de
        // cette passe est de couvrir des prénoms absents du gazetteer —
        // apparier vers l'avant est nettement moins exposé aux faux
        // positifs qu'apparier vers l'arrière, où un mot capitalisé de
        // début de phrase précède très souvent un patronyme sans aucun
        // rapport (voir la limite déjà documentée sur la règle
        // bidirectionnelle).
        final after = _matchNextCapitalizedWord(text, match.end);
        final hasFreeWordAfter = after != null &&
            !claimed.any((r) => r.overlaps(after.start, after.end));

        final int start;
        final int end;
        if (hasFreeWordAfter) {
          start = match.start;
          end = after.end;
        } else {
          start = match.start;
          end = match.end;
        }
        results.add(
          DetectedEntity(
            type: EntityType.nom,
            start: start,
            end: end,
            value: text.substring(start, end),
            confidence: 0.6,
          ),
        );
        claimed.add(_Range(start, end));
      }
    }

    results.sort((a, b) => a.start - b.start);
    return results;
  }

  /// Patronyme extrait d'une mention **certaine** (civilité, ou couple
  /// prénom+nom bidirectionnel), utilisé pour amorcer la deuxième passe.
  /// Retourne `null` quand aucun patronyme fiable ne peut être isolé — un
  /// prénom isolé (confiance 0.5, sans nom de famille adjacent) n'établit
  /// aucun patronyme.
  ///
  /// [value] est le **nom seul**, jamais le titre professionnel éventuel
  /// (voir `surnameSources` dans [detect]) : un titre inclus ferait
  /// gonfler le nombre de mots et empêcherait toute extraction.
  static String? _extractSurname(double confidence, String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      // Un seul mot : fiable uniquement depuis la civilité (confiance
      // 0.9), où le mot qui suit « Dr »/« Mme »/etc. est conventionnellement
      // un nom de famille en usage professionnel français.
      return confidence == 0.9 ? words.first : null;
    }
    if (words.length == 2) {
      final first = words[0];
      final second = words[1];
      final firstIsFirstName = _looksLikeKnownFirstName(first);
      final secondIsFirstName = _looksLikeKnownFirstName(second);
      if (firstIsFirstName && !secondIsFirstName) return second;
      if (secondIsFirstName && !firstIsFirstName) return first;
      // Ambigu (aucun des deux mots reconnu comme prénom, ou les deux) :
      // convention la plus fréquente en français courant, « Prénom Nom »
      // -> le second mot est retenu comme patronyme.
      return second;
    }
    return null;
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
