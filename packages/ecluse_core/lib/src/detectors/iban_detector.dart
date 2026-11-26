import '../detector.dart';
import '../digit_compaction.dart';
import '../entity.dart';

/// Détecteur d'IBAN français (International Bank Account Number).
///
/// Structure d'un IBAN FR (27 caractères) :
///
/// ```
/// FR KK BBBBB GGGGG CCCCCCCCCCC RR
/// │  │  │     │     │           └─ clé RIB (2 chiffres)
/// │  │  │     │     └───────────── numéro de compte (11 alphanumériques)
/// │  │  │     └─────────────────── code guichet (5 chiffres)
/// │  │  └───────────────────────── code banque (5 chiffres)
/// │  └──────────────────────────── clé de contrôle IBAN (2 chiffres)
/// └─────────────────────────────── code pays
/// ```
///
/// Validation par la clé de contrôle ISO 7064 : les 4 premiers caractères
/// sont déplacés à la fin, les lettres converties en nombres (A=10 …
/// Z=35), et le tout doit être congru à 1 modulo 97. Cette clé est
/// fortement discriminante, d'où une confiance de 1.0.
final class IbanFrDetector implements EntityDetector {
  const IbanFrDetector();

  @override
  EntityType get type => EntityType.iban;

  /// `FR` + 2 chiffres + 23 alphanumériques, séparateurs espace ou tiret
  /// tolérés, non enchâssé dans une séquence alphanumérique plus longue.
  static final RegExp _candidate = RegExp(
    r'(?<![A-Za-z0-9])[Ff][Rr][0-9]{2}(?:[ \-./]?[0-9A-Za-z]){23}(?![0-9A-Za-z])',
  );

  static final RegExp _separators = RegExp(r'[ \-./]');

  /// Écriture en paires derrière « FR » + séparateur (P2-283) : « FR 24 30 00
  /// … », clé en chiffres, onze paires, un dernier caractère, un séparateur
  /// entre chaque groupe. Même forme **stricte** que celle de
  /// [IbanCleInvalideDetector] (P2-277), et pour la même raison : une forme plus
  /// large (n'importe quel groupement derrière « FR » + séparateur) masquait
  /// des codes de pièce à tort. Ici la clé mod 97 doit en plus être juste :
  /// un faux accord est de l'ordre d'un sur 97.
  static final RegExp _candidatePaires = RegExp(
    r'(?<![A-Za-z0-9])[Ff][Rr][ \-./][0-9]{2}(?:[ \-./][0-9A-Za-z]{2}){11}'
    r'[ \-./][0-9A-Za-z](?![0-9A-Za-z])',
  );

  @override
  List<DetectedEntity> detect(String text) {
    // Neutralise d'abord les espaces (multiples, insécables, tabulations)
    // internes à une séquence de chiffres — un RIB affiché en tableau
    // n'utilise pas toujours un séparateur simple entre les groupes.
    // `_candidate` tolère déjà un séparateur unique par caractère, donc ce
    // repli sur le format « collé » suffit à couvrir les deux cas.
    final compaction = DigitCompaction(text);

    final results = <DetectedEntity>[];
    for (final match in [
      ...compaction.candidates(_candidate),
      ...compaction.candidates(_candidatePaires),
    ]) {
      final start = match.start;
      final end = match.end;
      final raw = text.substring(start, end);
      // Normalise depuis le match *compact* (déjà nettoyé des espaces
      // internes, quels qu'ils soient) plutôt que depuis `raw` : `raw`
      // vient du texte d'origine et peut encore contenir des séparateurs
      // que `_separators` ne connaît pas (tabulation, espace insécable).
      final normalized = match.text.replaceAll(_separators, '').toUpperCase();
      if (_isValidIban(normalized)) {
        results.add(
          DetectedEntity(
            type: EntityType.iban,
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

  /// Valide un IBAN normalisé (27 caractères, majuscules, sans séparateurs)
  /// selon ISO 7064 (mod 97-10).
  static bool _isValidIban(String iban, [int longueur = 27]) {
    if (iban.length != longueur) return false;

    // Réarrangement : BBAN + code pays + clé.
    final rearranged = iban.substring(4) + iban.substring(0, 4);

    // Calcul du modulo 97 en flux, chiffre par chiffre, pour éviter tout
    // dépassement d'entier (l'équivalent numérique fait ~30 chiffres).
    var remainder = 0;
    for (final unit in rearranged.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        // Chiffre.
        remainder = (remainder * 10 + (unit - 0x30)) % 97;
      } else if (unit >= 0x41 && unit <= 0x5A) {
        // Lettre A-Z → 10-35, soit deux chiffres.
        final value = unit - 0x41 + 10;
        remainder = (remainder * 100 + value) % 97;
      } else {
        return false;
      }
    }
    return remainder == 1;
  }
}

/// IBAN de forme française complète mais à **clé de contrôle invalide**
/// (P2-252), masqué en entier à confiance basse.
///
/// Pourquoi : un IBAN mal recopié reste celui de quelqu'un. Avant cette
/// tâche, [IbanFrDetector] l'ignorait (« clé validée ou rien », `DECISIONS.md`),
/// et une fenêtre de 9 chiffres qui passait Luhn par hasard à l'intérieur
/// était masquée comme FINESS, ou une fenêtre de 12 comme téléphone : le
/// reste du numéro de compte partait en clair (10 cas sur 200 000 documents du
/// corpus d'identifiants au moteur seul, 43 par `Ecluse.redact`). Une entité
/// qui couvre tout l'IBAN l'emporte sur ces sous-fenêtres dans
/// `resolveOverlaps` (la plus longue gagne), donc plus de masquage partiel.
///
/// **Type et confiance** : [EntityType.iban], confiance [confidence] (0,3). Le
/// type reste « iban » : c'est bien un IBAN, et le jeton restauré le dira. La
/// confiance 0,3 est celle des identifiants à clé invalide annoncés par un
/// libellé fort (`IdentifiantCleInvalideDetector`, P2-188) : `Ecluse.redact`
/// l'accompagne du même avertissement « identifiant à clé invalide masqué : à
/// vérifier », sans valeur dans le message. Aucun seuil ne filtre les
/// entités : le coût est un sur-masquage possible d'une suite alphanumérique
/// de forme `FR` + 2 chiffres + 23 caractères qui n'est pas un IBAN, jamais
/// une fuite.
///
/// **Périmètre** : la forme de [IbanFrDetector] (27 caractères, mêmes
/// séparateurs, même compaction des blancs), la clé pouvant porter la lettre
/// « o » ou « O » à la place d'un chiffre (P2-254). Un IBAN valide n'est jamais émis
/// ici (confiance 1,0 par [IbanFrDetector] / [IbanDetector]). Les IBAN
/// d'autres pays à clé invalide ne sont pas traités.
final class IbanCleInvalideDetector implements EntityDetector {
  const IbanCleInvalideDetector();

  /// Confiance de l'IBAN à clé invalide (voir la doc de la classe).
  static const double confidence = 0.3;

  @override
  EntityType get type => EntityType.iban;

  /// Même forme que [IbanFrDetector], mais la clé admet la lettre « o » ou
  /// « O » à la place d'un chiffre (P2-254) : confusion d'OCR ou de frappe
  /// (zéro / lettre). Sans libellé pour l'annoncer, 4 IBAN sur 50 du corpus
  /// « libellé fort » à clé fausse partaient en clair (`Ecluse.redact`), tous
  /// avec cette lettre dans la clé. Seule la clé est élargie : le reste de
  /// l'IBAN accepte déjà les lettres. Coût : une suite `FR` + `o` + 24
  /// caractères alphanumériques qui n'est pas un IBAN (référence, code) est
  /// masquée à confiance 0,3, jamais une fuite.
  ///
  /// **Paires (P2-277).** Un séparateur peut suivre « FR » quand l'IBAN est
  /// écrit en paires de chiffres (« FR 07 76 41 … ») : la sonde de P2-272 ne
  /// couvrait aucun des 40 cas. La forme est **strictement** celle-là : clé en
  /// chiffres, onze paires, un dernier caractère, un séparateur (espace, tiret,
  /// point ou barre) entre chaque groupe. Une version plus large (n'importe quel groupement derrière
  /// « FR » + séparateur) masquait 9 codes de pièce de plus au témoin durci de
  /// P2-268 (14 → 23 documents à tort). Un IBAN dont la clé est **juste**,
  /// écrit ainsi, est pris par [IbanFrDetector] (P2-283).
  static final RegExp _candidate = RegExp(
    r'(?<![A-Za-z0-9])[Ff][Rr][0-9Oo]{2}(?:[ \-./]?[0-9A-Za-z]){23}(?![0-9A-Za-z])',
  );

  static final RegExp _candidatePaires = RegExp(
    r'(?<![A-Za-z0-9])[Ff][Rr][ \-./][0-9]{2}(?:[ \-./][0-9A-Za-z]{2}){11}'
    r'[ \-./][0-9A-Za-z](?![0-9A-Za-z])',
  );

  static final RegExp _cleEnChiffres = RegExp(r'^FR[0-9]{2}');

  static final RegExp _separateur = RegExp(r'[\s\-./]');
  static final RegExp _separateurs = RegExp(r'[\s\-./]+');

  /// Garde `iban_g45` (P2-272, décision du 26 novembre, point 1) : un IBAN à
  /// clé **fausse** écrit avec des séparateurs n'est masqué que s'il est groupé
  /// comme un IBAN : 4-4-4-4-4-4-3 (la forme imprimée), 4-5-5-11-2 (RIB) ou
  /// 4-5-5-5-5-3. Sans séparateur : accepté. « FR » + 25 caractères en groupes de
  /// trois ou d'une autre taille est surtout un code de pièce : 10 des 14
  /// masquages à tort du témoin durci de P2-268, 0 identifiant perdu sur v3,
  /// libellé fort, OCR et 200 000 documents. **Coût mesuré** : un IBAN à clé
  /// fausse recopié en groupes de trois n'est plus masqué (40 sur 40 de la
  /// sonde) ; principe 0 de la décision : `Ecluse.redact` le signale « à
  /// vérifier » à la place ([ecartes]). Ne s'applique pas à l'écriture en paires
  /// derrière « FR » + séparateur (P2-277), dont la forme est déjà stricte.
  static bool _groupesUsuels(String brut) {
    if (!_separateur.hasMatch(brut)) return true;
    final l = brut.split(_separateurs).map((g) => g.length).toList();
    final quatre =
        l.length == 7 && l.sublist(0, 6).every((x) => x == 4) && l[6] == 3;
    final rib = l.length == 5 &&
        l[0] == 4 &&
        l[1] == 5 &&
        l[2] == 5 &&
        l[3] == 11 &&
        l[4] == 2;
    final cinq = l.length == 6 &&
        l[0] == 4 &&
        l.sublist(1, 5).every((x) => x == 5) &&
        l[5] == 3;
    return quatre || rib || cinq;
  }

  @override
  List<DetectedEntity> detect(String text) => _analyse(text).retenus;

  /// Empans des IBAN à clé fausse que la garde [_groupesUsuels] n'a **pas**
  /// masqués (bornes dans [text], jamais la valeur). `Ecluse.redact` en tire un
  /// avertissement « à vérifier » : une garde ne rend jamais une donnée
  /// silencieuse (décision du 26 novembre, principe 0).
  List<({int start, int end})> ecartes(String text) => _analyse(text).ecartes;

  ({List<DetectedEntity> retenus, List<({int start, int end})> ecartes})
      _analyse(String text) {
    final compaction = DigitCompaction(text);
    final retenus = <DetectedEntity>[];
    final ecartes = <({int start, int end})>[];
    final candidats = [
      for (final m in compaction.candidates(_candidate)) (m, false),
      for (final m in compaction.candidates(_candidatePaires)) (m, true),
    ];
    for (final (match, paires) in candidats) {
      final normalized =
          match.text.replaceAll(IbanFrDetector._separators, '').toUpperCase();
      // Un IBAN valide est émis par IbanFrDetector, à condition que sa clé
      // soit faite de chiffres : avec un « o » dans la clé il ne l'est jamais,
      // et « O » vaudrait 24 au calcul mod 97, sans signification ici.
      final cleChiffres = _cleEnChiffres.hasMatch(normalized);
      // (Écrit en paires derrière « FR » + séparateur, un IBAN valide est émis
      // par IbanFrDetector depuis P2-283 ; il est donc écarté ici aussi.)
      if (cleChiffres && IbanFrDetector._isValidIban(normalized)) continue;
      if (!paires && !_groupesUsuels(text.substring(match.start, match.end))) {
        ecartes.add((start: match.start, end: match.end));
        continue;
      }
      retenus.add(
        DetectedEntity(
          type: EntityType.iban,
          start: match.start,
          end: match.end,
          value: text.substring(match.start, match.end),
          confidence: confidence,
        ),
      );
    }
    return (retenus: retenus, ecartes: ecartes);
  }
}

/// Détecteur d'IBAN de l'espace SEPA (P2-62) : les 38 pays de la table
/// [longueurs], dont la France. Même validation que [IbanFrDetector] — clé
/// ISO 7064 mod 97-10, confiance 1.0 — avec, en plus, la **longueur propre au
/// pays** : un IBAN belge fait 16 caractères, un maltais 31. Un code pays hors
/// table (États-Unis, Maroc…) n'est jamais détecté ; le BIC n'est pas traité
/// (pas de clé, trop de faux positifs).
///
/// Les longueurs sont celles du registre IBAN (ISO 13616) ; 23 sur 38 ont été
/// recoupées avec des documents bancaires publics, les autres sont reprises du
/// registre (voir `LIMITES.md`). Une longueur fausse entraînerait un IBAN
/// manqué, jamais un faux positif : la clé de contrôle reste exigée.
///
/// **[cleInvalideFr]** (P2-252, faux par défaut : comportement d'avant) : en
/// plus des IBAN valides, rend aussi les IBAN de forme française à clé
/// invalide, tels que [IbanCleInvalideDetector] les produit (confiance 0,3,
/// empan entier). Une option plutôt qu'un détecteur de plus dans
/// `Ecluse.defaultDetectors` : la description du moteur écrite au journal
/// d'audit liste les noms des détecteurs et se réduit à leur nombre au-delà de
/// 200 caractères ; un dix-neuvième nom la ferait basculer.
final class IbanDetector implements EntityDetector {
  const IbanDetector({this.cleInvalideFr = false});

  /// Voir la doc de la classe.
  final bool cleInvalideFr;

  @override
  EntityType get type => EntityType.iban;

  /// Longueur totale d'un IBAN, par code pays.
  static const Map<String, int> longueurs = {
    'AD': 24, 'AT': 20, 'BE': 16, 'BG': 22, 'CH': 21, 'CY': 28, 'CZ': 24,
    'DE': 22, 'DK': 18, 'EE': 20, 'ES': 24, 'FI': 18, 'FO': 18, 'FR': 27,
    'GB': 22, 'GI': 23, 'GR': 27, 'HR': 21, 'HU': 28, 'IE': 22, 'IS': 26,
    'IT': 27, 'LI': 21, 'LT': 20, 'LU': 20, 'LV': 21, 'MC': 27, 'MT': 31,
    'NL': 18, 'NO': 15, 'PL': 28, 'PT': 25, 'RO': 24, 'SE': 24, 'SI': 19,
    'SK': 24, 'SM': 27, 'VA': 22, //
  };

  /// Une branche par pays : code pays, 2 chiffres, puis exactement
  /// `longueur - 4` alphanumériques (séparateur unique toléré entre eux), non
  /// enchâssé dans une séquence alphanumérique plus longue.
  static final RegExp _candidate = RegExp(
    '(?<![A-Za-z0-9])(?:${longueurs.entries.map(_branche).join('|')})'
    '(?![0-9A-Za-z])',
  );

  static String _branche(MapEntry<String, int> pays) {
    final lettres =
        pays.key.split('').map((c) => '[$c${c.toLowerCase()}]').join();
    return '$lettres[0-9]{2}(?:[ \\-./]?[0-9A-Za-z]){${pays.value - 4}}';
  }

  static final RegExp _separators = RegExp(r'[ \-./]');

  @override
  List<DetectedEntity> detect(String text) {
    final compaction = DigitCompaction(text);
    final results = <DetectedEntity>[];
    if (cleInvalideFr) {
      results.addAll(const IbanCleInvalideDetector().detect(text));
    }
    // P2-283 : « FR 24 30 00 … » (paires derrière « FR » + séparateur), forme
    // que `_candidate` ne couvre pas. Même clé mod 97, même confiance 1,0.
    for (final match
        in compaction.candidates(IbanFrDetector._candidatePaires)) {
      final normalized = match.text.replaceAll(_separators, '').toUpperCase();
      if (!IbanFrDetector._isValidIban(normalized)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.iban,
          start: match.start,
          end: match.end,
          value: text.substring(match.start, match.end),
          confidence: 1.0,
        ),
      );
    }
    for (final match in compaction.candidates(_candidate)) {
      final normalized = match.text.replaceAll(_separators, '').toUpperCase();
      if (!IbanFrDetector._isValidIban(
          normalized, longueurs[normalized.substring(0, 2)]!)) {
        continue;
      }
      results.add(
        DetectedEntity(
          type: EntityType.iban,
          start: match.start,
          end: match.end,
          value: text.substring(match.start, match.end),
          confidence: 1.0,
        ),
      );
    }
    return results;
  }
}
