import '../detector.dart';
import '../digit_compaction.dart';
import '../entity.dart';
import '../luhn.dart';

/// Détecteur de NIR — Numéro d'Inscription au Répertoire, plus connu
/// comme « numéro de sécurité sociale » français.
///
/// Structure d'un NIR complet (15 chiffres) :
///
/// ```
/// S AA MM DD CCC OOO KK
/// │ │  │  │  │   │   └─ clé de contrôle (2 chiffres)
/// │ │  │  │  │   └───── numéro d'ordre (3 chiffres)
/// │ │  │  │  └───────── commune ou pays de naissance (3 chiffres)
/// │ │  │  └──────────── département (01-99, 2A, 2B)
/// │ │  └─────────────── mois de naissance (01-12, ou fictif 00, 20-42, 50-99)
/// │ └────────────────── année de naissance (2 chiffres)
/// └──────────────────── sexe / catégorie (1-8)
/// ```
///
/// La clé vaut `97 - (N mod 97)` où N est le NIR sans la clé, lu comme un
/// entier de 13 chiffres. Pour la Corse, `2A` est remplacé par `19` et
/// `2B` par `18` avant le calcul.
///
/// Ce détecteur ne retourne que des NIR dont la clé de contrôle est
/// **structurellement valide** (confiance 1.0). Un faux NIR syntaxiquement
/// plausible mais à clé invalide est ignoré : c'est ce qui distingue une
/// validation structurelle d'un simple motif regex, et ce qui maintient un
/// taux de faux positifs proche de zéro.
final class NirDetector implements EntityDetector {
  const NirDetector();

  @override
  EntityType get type => EntityType.nir;

  /// Candidats : 15 caractères utiles, séparateurs optionnels (espace,
  /// point, tiret), `2A`/`2B` accepté en position de département. Les
  /// lookarounds interdisent qu'un candidat soit enchâssé dans une
  /// séquence de chiffres plus longue.
  static final RegExp _candidate = RegExp(
    r'(?<![0-9])'
    r'[1-8][ .\-/]?'
    r'[0-9]{2}[ .\-/]?'
    r'[0-9]{2}[ .\-/]?'
    r'(?:[0-9]{2}|2[ABab])[ .\-/]?'
    r'[0-9]{3}[ .\-/]?'
    r'[0-9]{3}[ .\-/]?'
    r'[0-9]{2}'
    r'(?![0-9])',
  );

  static final RegExp _separators = RegExp(r'[ .\-/]');

  @override
  List<DetectedEntity> detect(String text) {
    // Neutralise d'abord les espaces (multiples, insécables, tabulations)
    // internes à une séquence de chiffres — un RIB en tableau ou un NIR
    // recopié à la main n'utilise pas toujours un séparateur simple.
    // `_candidate` tolère déjà un séparateur unique par groupe, donc ce
    // repli sur le format « collé » suffit à couvrir les deux cas.
    final compaction = DigitCompaction(text);

    final results = <DetectedEntity>[];
    for (final match in compaction.candidates(_candidate)) {
      final start = match.start;
      final end = match.end;
      final raw = text.substring(start, end);
      // Normalise depuis le match *compact* (déjà nettoyé des espaces
      // internes, quels qu'ils soient) plutôt que depuis `raw` : `raw`
      // vient du texte d'origine et peut encore contenir des séparateurs
      // que `_separators` ne connaît pas (tabulation, espace insécable).
      final normalized = match.text.replaceAll(_separators, '').toUpperCase();
      if (_isValidNir(normalized)) {
        results.add(
          DetectedEntity(
            type: EntityType.nir,
            start: start,
            end: end,
            value: raw,
            confidence: 1.0,
          ),
        );
      }
    }
    return results;
  }

  /// 01-12 réels ; `00` et `20`-`30` (mois inconnu), `31`-`42` (mois connu
  /// codé +30) et `50`-`99` (mois inconnu), d'après la nomenclature DGFiP
  /// (annexe 2) citée par le mainteneur — l'instruction INSEE n'a pas été
  /// lue. 13-19 et 43-49 restent rejetés.
  static bool _isPlausibleMonth(int month) =>
      (month >= 0 && month <= 12) ||
      (month >= 20 && month <= 42) ||
      (month >= 50 && month <= 99);

  /// Valide un NIR normalisé (15 caractères, sans séparateurs, majuscules).
  static bool _isValidNir(String nir) => _aLaForme(nir) && _cleJuste(nir);

  /// Tout sauf la clé : longueur, mois, département, numéro d'ordre. Partagé
  /// avec [NirCleInvalideDetector], qui exige la même forme.
  static bool _aLaForme(String nir) {
    if (nir.length != 15) return false;

    // Mois de naissance : 01 à 12, ou mois fictif attribué quand la date est
    // incomplète : 00, 20 à 42 et 50 à 99 (plages
    // telles que rapportées par la documentation publique du NIR, à
    // confirmer sur la source INSEE). La clé de contrôle reste exigée : la
    // détection ne devient pas moins stricte, seul le filtre de plage
    // s'élargit.
    final month = int.tryParse(nir.substring(3, 5));
    if (month == null || !_isPlausibleMonth(month)) return false;

    // Département : 01-99 ou 2A/2B (Corse).
    final dept = nir.substring(5, 7);
    final isCorsica = dept == '2A' || dept == '2B';
    if (!isCorsica) {
      final deptNum = int.tryParse(dept);
      if (deptNum == null || deptNum < 1) return false;
    }

    // Numéro d'ordre : 001 à 999.
    final order = int.tryParse(nir.substring(10, 13));
    if (order == null || order < 1) return false;
    return true;
  }

  /// Clé de contrôle (les 13 premiers caractères et les deux derniers).
  static bool _cleJuste(String nir) {
    final body = nir
        .substring(0, 13)
        .replaceFirst('2A', '19', 5)
        .replaceFirst('2B', '18', 5);
    final number = int.tryParse(body);
    if (number == null) return false;

    final expectedKey = 97 - (number % 97);
    final actualKey = int.tryParse(nir.substring(13, 15));
    return actualKey == expectedKey;
  }
}

/// NIR de forme complète mais à **clé de contrôle fausse** (P2-258), la lettre
/// « O » / « o » étant admise à la place d'un zéro, masqué en entier à
/// confiance basse.
///
/// Pourquoi : un numéro de sécurité sociale mal recopié reste celui d'un
/// patient (décision du 23 novembre, `DECISIONS.md`, comme l'IBAN de
/// P2-252). [NirDetector] l'ignore (« clé validée ou rien ») ; avant cette
/// tâche, par `Ecluse.redact`, les NIR à clé fausse du corpus partaient en
/// clair.
///
/// **Forme** : celle de [NirDetector] (15 caractères, mêmes séparateurs,
/// même compaction des blancs), avec sexe 1 ou 2, mois et département
/// plausibles comme [NirDetector], numéro d'ordre non nul, et la lettre
/// « O » ou « o » admise à la place d'un zéro dans toute position de
/// chiffre (confusion d'OCR ou de frappe, comme P2-254 pour l'IBAN). N'est
/// émis qu'un NIR dont la clé (« O » lu comme 0) est **fausse** : un NIR à clé
/// juste n'est jamais émis ici (tout en chiffres, c'est [NirDetector], à
/// confiance 1,0 ; avec des lettres « O » et sans libellé, il reste en clair,
/// comme avant : P2-191, `LIMITES.md` § 2).
///
/// **Où il tourne** : `Ecluse.redact` l'appelle sur le texte d'origine, pas sur
/// la vue de détection, comme `IdentifiantCleInvalideDetector` : la vue
/// neutralise le mot « clé » de « 2550814168025 clé 39 » (P2-42), et une clé
/// nommée à part fausse doit rester intacte (`DECISIONS.md`, P2-188).
///
/// **Type et confiance** : [EntityType.nir], confiance [confidence] (0,3),
/// avec le même avertissement « identifiant à clé invalide masqué : à
/// vérifier » que les autres identifiants à clé invalide, sans valeur dans le
/// message. Coût : un nombre de 15 chiffres de cette forme qui n'est pas un
/// NIR (référence, numéro de lot) est masqué : sur-masquage possible, jamais
/// une fuite. Le coût est mesuré sur les témoins négatifs (voir la PR).
final class NirCleInvalideDetector implements EntityDetector {
  /// [coupuresLibres] : n'impose pas que chaque coupure tombe entre deux groupes
  /// d'un NIR. Réservé à l'appel sur la vue de détection d'`Ecluse.redact`
  /// (P2-263), où une fin de ligne tombe n'importe où dans le numéro ; l'appelant
  /// ne garde alors que les détections dont l'étendue d'origine contient cette
  /// fin de ligne (ou une forme pleine chasse), jamais une coupure ordinaire.
  const NirCleInvalideDetector({this.coupuresLibres = false});

  final bool coupuresLibres;

  /// Confiance du NIR à clé invalide (voir la doc de la classe).
  static const double confidence = 0.3;

  @override
  EntityType get type => EntityType.nir;

  static final RegExp _candidate = RegExp(
    r'(?<![0-9Oo])'
    r'[12][ .\-/]?'
    r'[0-9Oo]{2}[ .\-/]?'
    r'[0-9Oo]{2}[ .\-/]?'
    r'(?:[0-9Oo]{2}|2[ABab])[ .\-/]?'
    r'[0-9Oo]{3}[ .\-/]?'
    r'[0-9Oo]{3}[ .\-/]?'
    r'[0-9Oo]{2}'
    r'(?![0-9Oo])',
  );

  /// NIR en cinq groupes de trois (P2-263) : « 285.057.800.608.446 ». Avec des
  /// espaces, la compaction des blancs le ramène à la forme collée de
  /// [_candidate] ; seuls les points, tirets et barres obligent à ce motif.
  static final RegExp _candidateTroisParCinq = RegExp(
    r'(?<![0-9Oo])'
    r'[12][0-9Oo]{2}[.\-/]'
    r'[0-9Oo]{3}[.\-/]'
    r'[0-9Oo]{3}[.\-/]'
    r'[0-9Oo]{3}[.\-/]'
    r'[0-9Oo]{3}'
    r'(?![0-9Oo])',
  );

  static final RegExp _separators = RegExp(r'[ .\-/]');

  /// Positions (en caractères utiles) entre les groupes d'un NIR : 1 + 2 + 2 +
  /// 2 + 3 + 3 + 2.
  static const Set<int> _frontieres = {1, 3, 5, 7, 10, 13};

  /// Vrai si chaque coupure de [brut] (suite de blancs ou de séparateurs)
  /// tombe entre deux groupes d'un NIR. Sans coupure : vrai. Sans cette
  /// règle, une clé fausse accepte n'importe quelle coupure, donc un RPPS
  /// valide suivi d'un nombre de quatre chiffres serait avalé en un « NIR »
  /// (P2-174, mesuré : 17 documents sur 4 800 passaient de 2 à 19 défauts).
  /// Coût assumé : un NIR à clé fausse écrit en groupes d'une autre taille que
  /// celle d'un NIR ou que cinq groupes de trois (P2-263) n'est pas masqué
  /// (`LIMITES.md` § 2).
  static bool _coupuresDeNir(String brut) {
    var utiles = 0;
    var dansCoupure = false;
    final coupures = <int>[];
    var tailleNir = true;
    for (final unite in brut.runes) {
      final c = String.fromCharCode(unite);
      if (RegExp(r'[0-9A-Za-z]').hasMatch(c)) {
        dansCoupure = false;
        utiles++;
      } else if (!dansCoupure) {
        dansCoupure = true;
        coupures.add(utiles);
        if (!_frontieres.contains(utiles)) tailleNir = false;
      }
    }
    if (tailleNir) return true;
    // P2-263 : cinq groupes de trois, et seulement cela (les quatre coupures
    // aux positions 3, 6, 9 et 12) ; un RPPS suivi d'un nombre coupe à 11.
    return coupures.length == 4 &&
        coupures[0] == 3 &&
        coupures[1] == 6 &&
        coupures[2] == 9 &&
        coupures[3] == 12;
  }

  /// Vrai si une coupure de [brut] tombe après neuf ou onze chiffres de clé de
  /// Luhn juste : un FINESS, un SIREN ou un RPPS suivi d'un nombre (« RPPS
  /// 10192209566⏎1250 places », P2-174) n'est pas un NIR coupé. Seul garde-fou de
  /// la lecture à coupures libres (P2-263) : un NIR coupé à cet endroit, dont les
  /// premiers chiffres sont par hasard de Luhn juste (un sur dix), reste en
  /// clair.
  static bool _prefixeIdentifiantCourt(String brut) {
    final chiffres = StringBuffer();
    var dansCoupure = false;
    for (final unite in brut.runes) {
      final c = String.fromCharCode(unite);
      if (RegExp(r'[0-9A-Za-z]').hasMatch(c)) {
        dansCoupure = false;
        chiffres.write(c);
      } else if (!dansCoupure) {
        dansCoupure = true;
        final avant = chiffres.toString();
        if ((avant.length == 9 || avant.length == 11) &&
            RegExp(r'^[0-9]+$').hasMatch(avant) &&
            isLuhnValid(avant)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Séparateur puis groupe de un à quatre caractères parmi chiffres et
  /// confusions d'OCR (o, O, l, I), dont au moins une lettre, collé à la suite
  /// d'un candidat (P2-276). Mesuré sur `Ecluse.redact` : 1 masquage à tort du
  /// témoin durci de P2-268 en moins, 0 identifiant perdu sur v3, libellé fort,
  /// OCR, la sonde et 200 000 documents.
  static final RegExp _suiteAbimee =
      RegExp(r'[ .\-/](?=[0-9oOlI]{0,3}[oOlI])[0-9oOlI]{1,4}(?![0-9A-Za-z])');

  @override
  List<DetectedEntity> detect(String text) => _analyse(text, null);

  /// Empans des NIR à clé fausse que la garde « suite abîmée » (P2-276) a
  /// écartés (bornes dans [text], jamais la valeur). `Ecluse.redact` en tire un
  /// avertissement « à vérifier » : une garde ne rend jamais une donnée
  /// silencieuse (principe du 26 novembre, point 0 ; P2-304). Ne couvre pas les
  /// coupures hors des groupes d'un NIR, qui écartent aussi sans rien dire
  /// (`agent/specs/P2-303.md`).
  List<({int start, int end})> ecartes(String text) {
    final ecartes = <({int start, int end})>[];
    _analyse(text, ecartes);
    return ecartes;
  }

  List<DetectedEntity> _analyse(
      String text, List<({int start, int end})>? ecartes) {
    final compaction = DigitCompaction(text);
    final results = <DetectedEntity>[];
    final vus = <int>{};
    for (final match in [
      ...compaction.candidates(_candidate),
      ...compaction.candidates(_candidateTroisParCinq),
    ]) {
      if (!vus.add(match.start)) continue;
      final brut =
          match.text.replaceAll(NirCleInvalideDetector._separators, '');
      final normalise = brut.toUpperCase().replaceAll('O', '0');
      if (!NirDetector._aLaForme(normalise)) continue;
      // Un nombre voisin collé à un identifiant plus court (RPPS de onze
      // chiffres + « 1250 » = quinze chiffres) n'est pas un NIR : ses
      // coupures ne tombent pas entre les groupes d'un NIR.
      final brutAvecCoupures = text.substring(match.start, match.end);
      if (coupuresLibres
          ? _prefixeIdentifiantCourt(brutAvecCoupures)
          : !_coupuresDeNir(brutAvecCoupures)) {
        continue;
      }
      // Clé juste : celui de NirDetector s'il est tout en chiffres ; avec des
      // lettres « O », jamais masqué sans libellé (`LIMITES.md` § 2).
      if (NirDetector._cleJuste(normalise)) continue;
      // Suite abîmée (P2-276) : un groupe court collé à la suite, qui porte
      // une lettre de confusion d'OCR (« 19226.71o31.753o6.26I »), montre un
      // numéro de pièce plus long, pas un NIR coupé. Une suite faite de
      // chiffres seuls (« … 12 pièces ») ne compte pas : le NIR reste masqué.
      if (_suiteAbimee.matchAsPrefix(text, match.end) != null) {
        ecartes?.add((start: match.start, end: match.end));
        continue;
      }
      results.add(
        DetectedEntity(
          type: EntityType.nir,
          start: match.start,
          end: match.end,
          value: text.substring(match.start, match.end),
          confidence: confidence,
        ),
      );
    }
    return results;
  }
}
