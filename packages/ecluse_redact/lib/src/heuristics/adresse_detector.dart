import 'package:ecluse_core/ecluse_core.dart';

import 'mots_neutres.dart';

/// Détecteur heuristique d'adresses postales simples — **v0 de
/// démonstration**.
///
/// Reconnaît deux motifs :
///
/// 1. `numéro + type de voie + nom de voie + code postal (5 chiffres) +
///    commune`, par exemple `12 rue des Lilas, 75015 Paris` → confiance
///    modérée (0.7) : le numéro et le type de voie sont un indice fort.
/// 2. `code postal (5 chiffres) + commune` **seul**, sans numéro ni type de
///    voie devant (ex. adresse sur sa propre ligne dans un formulaire :
///    `70160 Saint Rémy en Comté`) → confiance plus faible (0.55) : sans le
///    numéro/type de voie, l'indice est moins spécifique. Un code postal
///    isolé, sans nom de commune qui suit, n'est **jamais** masqué à lui
///    seul (5 chiffres seuls n'identifient personne).
///
/// Aucune validation possible dans les deux cas (pas d'annuaire des voies ni
/// des communes embarqué). Ne couvre pas les adresses sans code postal, les
/// boîtes postales, ni les formats étrangers. Sera affiné en phase 2 (NER +
/// table INSEE).
final class AdresseDetector implements EntityDetector {
  const AdresseDetector();

  @override
  EntityType get type => EntityType.adresse;

  static const _voies = [
    'rue',
    'avenue',
    'boulevard',
    'chemin',
    'impasse',
    'allée',
    'allee',
    'place',
    'route',
    'quai',
    'square',
    'passage',
    'cours',
    'lotissement',
    'chaussée',
    'chaussee',
    'faubourg',
    'esplanade',
    'villa',
    'hameau',
    'cité',
    'cite',
    // Abréviations courantes (point facultatif, voir [_voieMotif]).
    'av',
    'ave',
    'bd',
    'bvd',
    'rte',
    'fbg',
    'r',
    'pl',
    'ch',
    'imp',
    'all',
    'sq',
    'crs',
    // Autres types de voie (P2-49).
    'sentier',
    'ruelle',
    'traverse',
    'venelle',
    'parvis',
    'promenade',
    'montée',
    'montee',
    'clos',
  ];

  /// `code postal (5 chiffres) + commune`, réutilisé tel quel comme fin du
  /// motif complet et comme motif autonome pour une adresse sans numéro ni
  /// type de voie. Le premier mot de la « commune » est capturé à part
  /// (groupe nommé `commune`) pour pouvoir l'écarter s'il ressemble à une
  /// unité de mesure plutôt qu'à un nom de lieu — voir [_looksLikeUnit].
  ///
  /// Deux garde-fous généraux, indépendants de tout document précis :
  /// - `(?<!\d)` avant les 5 chiffres : un code postal est le **début**
  ///   d'une séquence de chiffres, jamais une fenêtre choisie au milieu
  ///   d'un numéro plus long (RPPS, NIR non reconnu comme tel, etc.).
  /// - `[ \t]` au lieu de `\s` entre le code postal et la commune : un
  ///   code postal et sa commune sont toujours sur la **même ligne** dans
  ///   un document réel ; `\s` matche aussi le saut de ligne, ce qui
  ///   laissait un span avaler la ligne suivante en entier.
  static const _codePostalCommune = '(?<!\\d)\\d{5}$_h+(?<commune>$_motCommune)'
      '(?:[ \\u00A0\\u202F-]$_connecteurs*(?!$_titres$_finDeTitre)$_motCommune){0,3}'
      '$_suffixeCedex';

  /// « CEDEX » et son numéro de distribution (P2-164). Le mot « CEDEX » en
  /// capitales ou « Cedex » était déjà pris comme dernier mot de la commune ;
  /// le numéro qui suit (« CEDEX 9 », « Cedex 09 ») restait en clair, comme
  /// « cedex » en minuscules ou après une virgule (mesure P2-157 : 53
  /// adresses sur 155 du corpus flou adversarial). Le numéro n'est lu
  /// qu'**après le mot « CEDEX »** et sur la même ligne, 1 ou 2 chiffres
  /// (1 à 99 ; « CEDEX 2026 dossiers », « CEDEX 9e étage » : le nombre reste
  /// en clair) : un nombre qui suit une commune sans CEDEX n'est jamais
  /// absorbé (« 70000 VESOUL 3 agents »).
  static const _suffixeCedex = '(?:(?:,?$_h*$_cedex)?(?<=$_cedex)'
      '(?:$_h+\\d{1,2}(?![\\dA-Za-zÀ-ÿ]))?)?';

  /// « cedex » dans toutes les casses (le motif d'adresse est sensible à la
  /// casse), jamais collé à une lettre qui suit.
  static const _cedex = '[Cc][Ee][Dd][Ee][Xx](?![A-Za-zÀ-ÿ])';

  /// Blanc horizontal : espace, tabulation, espace insécable (U+00A0), espace
  /// fine insécable (U+202F). Jamais un saut de ligne.
  static const _h = '[ \\t\\u00A0\\u202F]';

  /// Mot de commune : majuscule initiale (le motif est sensible à la casse,
  /// voir [_pattern]). `\w` ne couvre que l'ASCII sans le drapeau `unicode`
  /// (Dart) : les classes `À-ÖØ-Þ`/`à-öø-ÿ` ajoutent les lettres accentuées
  /// latin-1, mais s'arrêtent à `ÿ` (U+00FF) et laissent dehors la ligature
  /// « œ »/« Œ » (U+0153/U+0152, hors Latin-1) — 109 communes du référentiel
  /// (« Annœullin », « Œuilly ») perdaient leur nom à partir de cette lettre
  /// ou, en initiale, n'étaient pas reconnues comme commune du tout
  /// (P2-180, § 1).
  static const _motCommune = "[A-ZÀ-ÖØ-ÞŒ][\\wÀ-ÖØ-Þà-öø-ÿœŒ'’-]*";

  /// Petits mots **en minuscules** qui lient les parties d'un nom de commune
  /// (« Saint-Rémy en Comté », « Neuilly sur Seine », « Villeneuve d'Ascq »).
  /// Tout autre mot en minuscules arrête la commune : sinon le span avale le
  /// texte qui suit (un email, un nom) et la résolution des chevauchements
  /// supprime l'entité voisine au lieu de la masquer (fuite).
  static const _connecteurs =
      "(?:(?:de|du|des|la|le|les|en|sur|sous|lès|lez|aux)[ -]|[dl]['’])";

  /// Civilités et titres qui ne sont jamais le dernier mot d'une commune :
  /// ils annoncent un nom de personne, détecté à part.
  static const _titres =
      '(?:Mme|Mlle|Mr|Madame|Monsieur|Mademoiselle|Dr|Docteur|Pr|Professeur|Me|Maître|M)';

  /// Fin de mot après un titre (« M », « Pr »…), équivalent de `\b` mais qui
  /// tient compte des lettres accentuées : `\b` de Dart se fonde sur `\w`
  /// ASCII (sans drapeau `unicode`), qui ne voit pas « é » comme une lettre.
  /// « Pr\b » matchait donc déjà entre le « r » et le « é » de « Pré » : un
  /// nom de commune en un seul mot qui commence comme un titre abrégé
  /// (« Le Pré-Saint-Gervais », « Les Mées », « Le Mée-sur-Seine ») était pris
  /// pour une civilité annonçant un nom et n'était jamais inclus dans la
  /// commune (P2-180, § 1). Une vraie civilité est toujours suivie d'un
  /// espace ou d'un point avant le nom (« Mme Durand », « M. Durand ») : la
  /// différence ne change donc rien aux civilités réelles.
  static const _finDeTitre = "(?![\\wÀ-ÖØ-Þà-öø-ÿœŒ'’-])";

  /// Sépare le nom de voie du `CP_COMMUNE` qui suit : soit sur la **même
  /// ligne** (virgule optionnelle, comportement historique), soit via **un
  /// unique** saut de ligne (`SEP_LIGNE_UNIQUE` de la spec adresse
  /// multiligne). Un second saut de ligne consécutif (ligne vide) fait
  /// naturellement échouer les deux alternatives : `\d{5}` ne suit alors
  /// plus immédiatement (aux espaces horizontaux près), donc le span
  /// s'interrompt — pas de logique de garde séparée à écrire.
  static const _voieVersCpCommune =
      '(?:,?[ \\t\\u00A0\\u202F]*|[ \\t]*\\r?\\n[ \\t]*)';

  /// Rend une chaîne insensible à la casse lettre par lettre (`rue` devient
  /// `[Rr][Uu][Ee]`). Dart ne propose pas de drapeau local : le motif entier
  /// ne peut pas être `caseSensitive: false` sans rendre la commune
  /// insensible à la casse aussi.
  static String _ci(String word) => word.split('').map((c) {
        final up = c.toUpperCase();
        final low = c.toLowerCase();
        return up == low ? c : '[$up$low]';
      }).join();

  /// Type de voie, avec point facultatif pour les abréviations (`av.`, `bd.`).
  static final String _voieMotif = '(?:${_voies.map(_ci).join('|')})\\.?';

  /// Numéro de voie : 1 à 4 chiffres, suffixe facultatif `bis`, `ter`… ou une
  /// lettre majuscule A-F (« 12 bis rue », « 12bis rue », « 12 B rue »). La
  /// lettre doit être majuscule et isolée : le type de voie qui suit reste
  /// obligatoire, ce qui écarte « Annexe 12 B : voir page 3 ».
  static final String _numero = '\\d{1,4}(?:$_h*(?:${[
    'bis',
    'ter',
    'quater',
    'quinquies'
  ].map(_ci).join('|')}|[A-F](?![A-Za-zÀ-ÿ])))?';

  /// Nom de voie borné à 80 caractères : le quantificateur paresseux non
  /// borné rendait le motif quadratique quand « N rue » se répète sans code
  /// postal (16 Ko = plus de 5 s). Un nom de voie plus long n'est plus
  /// reconnu en entier : seul « code postal + commune » est alors masqué.
  static const String _nomVoie = "[A-ZÀ-ÖØ-Þa-zà-öø-ÿ0-9'’\\- ]{1,80}?";

  static final RegExp _pattern = RegExp(
    '$_numero$_h*(?:,$_h*)?$_voieMotif'
    '$_h+$_nomVoie'
    '$_voieVersCpCommune'
    '$_codePostalCommune',
  );

  /// Variante sans numéro (« rue des Lilas, 75015 Paris ») : exige que le
  /// type de voie ne soit pas collé à un mot qui précède, et un code postal
  /// + commune derrière. Confiance plus faible (0.6) que la forme numérotée.
  static final RegExp _patternSansNumero = RegExp(
    '(?<![\\wÀ-ÿ])$_voieMotif'
    '$_h+$_nomVoie'
    '$_voieVersCpCommune'
    '$_codePostalCommune',
  );

  static final RegExp _codePostalCommuneOnly = RegExp(_codePostalCommune);

  /// Types de voie reconnus **sans code postal** (P2-56) : en toutes lettres
  /// ou abréviations d'au moins deux lettres sans autre sens courant. « r »,
  /// « pl », « ch », « all », « sq », « crs », « imp » en sont exclus : après un
  /// nombre, ils désignent des chambres, des places ou des chapitres.
  static const _voiesSansCodePostal = [
    'rue', 'avenue', 'boulevard', 'chemin', 'impasse', 'allée', 'allee',
    'place', 'route', 'quai', 'square', 'passage', 'cours', 'lotissement',
    'chaussée', 'chaussee', 'faubourg', 'esplanade', 'villa', 'hameau', //
    'cité', 'cite', 'av', 'bd', 'bvd', 'rte', 'fbg', 'sentier', 'ruelle',
    'traverse', 'venelle', 'parvis', 'promenade', 'montée', 'montee', 'clos',
  ];

  /// Mot d'un nom de voie : majuscule initiale ou nombre (« rue du 8 Mai »).
  static const String _motVoie = "(?:[A-ZÀ-ÖØ-Þ][\\wÀ-ÿ'’-]*|\\d{1,4})";

  static const String _particuleVoie =
      "(?:(?:de|du|des|la|le|les|aux|sur|en|von|van)[ \\t]+|[dl]['’])";

  /// Adresse sans code postal : numéro + type de voie + nom de voie de 1 à 5
  /// mots en majuscule initiale (particules en minuscules tolérées). Le nom en
  /// minuscules (« 12 place disponible », « 3 chemin de fer ») n'est jamais une
  /// adresse. Confiance 0.55 : aucune validation possible.
  static final RegExp _patternSansCodePostal = RegExp(
    '(?<![\\wÀ-ÿ])$_numero$_h*(?:,$_h*)?'
    '(?:${_voiesSansCodePostal.map(_ci).join('|')})\\.?$_h+'
    '(?:$_particuleVoie)*$_motVoie'
    '(?:[ \\t-]+(?:$_particuleVoie)*$_motVoie){0,4}',
  );

  /// Unités de mesure courantes (SI et posologie clinique) — un nombre à 5
  /// chiffres suivi d'une unité (« 10000 UI », « 20000 ML ») a exactement
  /// la même forme syntaxique qu'un code postal suivi d'une commune, mais
  /// n'a rien d'une adresse : effacer une posologie serait une fuite de
  /// donnée clinique plus grave que le faux négatif évité. Liste générale,
  /// indépendante de tout document précis.
  static const _measurementUnits = {
    'ui', 'iu', 'mg', 'mcg', 'ng', 'pg', //
    'ml', 'cl', 'dl', 'kg', 'mol', 'mmol', 'meq', //
    'cm', 'mm', 'km', 'kcal', //
  };

  static final RegExp _minuscule = RegExp(r'\p{Ll}', unicode: true);
  static final RegExp _majuscule = RegExp(r'\p{Lu}', unicode: true);

  static bool _sansMinuscule(String text) =>
      !_minuscule.hasMatch(text) && _majuscule.hasMatch(text);

  static bool _communeNeutre(RegExpMatch match) {
    final commune = match.namedGroup('commune');
    if (commune == null) return false;
    final premier = RegExp(r"^[^ \t\u00A0\u202F'’-]+").stringMatch(commune);
    return premier != null && motsNeutres.contains(premier.toLowerCase());
  }

  static bool _looksLikeUnit(RegExpMatch match) {
    final commune = match.namedGroup('commune');
    return commune != null && _measurementUnits.contains(commune.toLowerCase());
  }

  /// Règle CP_COMMUNE de la spec : « un token de commune commence par une
  /// majuscule ». Ne peut pas être imposé par la classe de caractères de
  /// `commune` elle-même : `_pattern` et `_codePostalCommuneOnly` sont
  /// `caseSensitive: false` (nécessaire pour matcher les types de voie en
  /// minuscules), ce qui rend `[A-ZÀ-ÖØ-Þ]` insensible à la casse par la
  /// même occasion et laissait passer des faux positifs comme
  /// « 70000 euros ». Vérification a posteriori, sur la sous-chaîne
  /// réellement matchée, indépendante du flag de casse du motif.
  static final RegExp _uppercaseFirstLetter = RegExp(r'^[A-ZÀ-ÖØ-ÞŒ]');

  static bool _communeStartsWithUppercase(RegExpMatch match) {
    final commune = match.namedGroup('commune');
    return commune != null && _uppercaseFirstLetter.hasMatch(commune);
  }

  /// Tournure de **quantité ou de référence** juste avant un nombre à cinq
  /// chiffres (P2-167) : « commande **de** 70000 unités », « **environ** 12345
  /// exemplaires », « **lot** 70000 », « **réf.** 54321 », « **n°** 17514 »,
  /// « **total :** 70000 ». Un code postal n'est pas introduit ainsi : il suit
  /// une voie, une virgule, un retour à la ligne, « à » ou une étiquette
  /// d'adresse. Mesure de départ (`bench/generate_corpus_cinq_chiffres.py`,
  /// 400 phrases sans adresse) : 132 adresses prédites à tort par
  /// `Ecluse.redact`.
  ///
  /// Les mots de la tournure sont des mots de grammaire (préposition de
  /// quantité, étiquettes de pièce ou de commande), pas des valeurs tirées d'un
  /// corpus. Les mots qui **suivent** le nombre ne sont pas jugés : « 70000
  /// Vesoul » et « 70000 Alpha » ont la même forme.
  ///
  /// « de » seul n'est **pas** une tournure de quantité (décision du
  /// 13 novembre) : « la mairie de 70000 Vesoul », « originaire de 25000
  /// Besançon » restent masqués. « de » ne compte qu'après un nom de pièce ou
  /// de quantité (« commande de 70000 unités », « un lot de 12345 pièces »).
  /// Mieux vaut un nombre masqué à tort qu'un code postal laissé en clair.
  static final RegExp _introduitParQuantite = RegExp(
    r'(?<![\p{L}])(?:(?:commande|lot|total|quantité|quantite|montant|facture|'
    r'dossier|stock|livraison|tirage)s?'
    r"(?:[ \t\u00A0\u202F]+(?:de|d['’]))?|"
    r'environ|n°|réf\.?|ref\.?|référence|reference)'
    r'[ \t\u00A0\u202F]*:?[ \t\u00A0\u202F]*$',
    caseSensitive: false,
    unicode: true,
  );

  /// Borne la partie du texte relue avant le nombre : le coût reste linéaire
  /// quand les nombres à cinq chiffres se répètent.
  static const int _fenetreQuantite = 40;

  static bool _estIntroduitParQuantite(String text, int debut) {
    final depart = debut > _fenetreQuantite ? debut - _fenetreQuantite : 0;
    return _introduitParQuantite.hasMatch(text.substring(depart, debut));
  }

  static bool _chevauche(List<_Range> tries, int start, int end) {
    var lo = 0;
    var hi = tries.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (tries[mid].start < end) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    // `lo` : premier intervalle commençant à `end` ou après ; les précédents
    // sont disjoints et triés, seul le dernier peut déborder sur `start`.
    return lo > 0 && tries[lo - 1].end > start;
  }

  @override
  List<DetectedEntity> detect(String text) {
    // Texte sans aucune minuscule : la règle « la commune commence par une
    // majuscule » ne filtre plus rien (« 70000 EUROS HORS TAXES » devenait
    // une adresse : 194 faux positifs sur le témoin, mesure P2-121). On y
    // écarte une commune qui commence par un mot neutre (P2-122).
    final capitales = _sansMinuscule(text);
    final results = <DetectedEntity>[];
    final claimed = <_Range>[];

    for (final match in _pattern.allMatches(text)) {
      if (_looksLikeUnit(match)) continue;
      if (!_communeStartsWithUppercase(match)) continue;
      if (capitales && _communeNeutre(match)) continue;
      final start = match.start;
      final end = match.end;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: start,
          end: end,
          value: match.group(0)!,
          confidence: 0.7,
        ),
      );
      claimed.add(_Range(start, end));
    }

    // Voie sans numéro : après la forme numérotée (qui la contient), pour
    // ne pas produire deux entités sur la même adresse.
    for (final match in _patternSansNumero.allMatches(text)) {
      if (_looksLikeUnit(match)) continue;
      if (!_communeStartsWithUppercase(match)) continue;
      if (capitales && _communeNeutre(match)) continue;
      final start = match.start;
      final end = match.end;
      if (claimed.any((r) => r.overlaps(start, end))) continue;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: start,
          end: end,
          value: match.group(0)!,
          confidence: 0.6,
        ),
      );
      claimed.add(_Range(start, end));
    }

    // Adresse sans code postal (P2-56), en dernier : une adresse complète déjà
    // reconnue la contient. Intervalles déjà retenus triés (disjoints par
    // construction), recherche dichotomique plutôt que balayage.
    final retenus = [...claimed]..sort((a, b) => a.start - b.start);
    for (final match in _patternSansCodePostal.allMatches(text)) {
      if (_chevauche(retenus, match.start, match.end)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: match.start,
          end: match.end,
          value: match.group(0)!,
          confidence: 0.55,
        ),
      );
      claimed.add(_Range(match.start, match.end));
    }

    for (final match in _codePostalCommuneOnly.allMatches(text)) {
      if (_looksLikeUnit(match)) continue;
      if (!_communeStartsWithUppercase(match)) continue;
      if (capitales && _communeNeutre(match)) continue;
      final start = match.start;
      final end = match.end;
      if (_estIntroduitParQuantite(text, start)) continue;
      // Déjà couvert par une adresse complète (numéro + voie) ci-dessus :
      // ne pas ajouter un doublon pour le seul suffixe "code postal +
      // commune" de cette même adresse.
      if (claimed.any((r) => r.overlaps(start, end))) continue;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: start,
          end: end,
          value: match.group(0)!,
          confidence: 0.55,
        ),
      );
      claimed.add(_Range(start, end));
    }

    results.sort((a, b) => a.start - b.start);
    return results;
  }
}

final class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;

  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && start < otherEnd;
}
