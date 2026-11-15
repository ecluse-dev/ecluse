import 'package:ecluse_core/ecluse_core.dart';

/// Identifiant à clé de contrôle invalide, mais **annoncé par un libellé
/// fort** (P2-188) : « NIR », « N° de sécurité sociale », « numéro SS »
/// pour un NIR, « IBAN » pour un IBAN FR, « RPPS » pour un RPPS.
///
/// La règle « clé validée ou rien » (`DECISIONS.md`, 2026-06) vaut pour la
/// **détection** d'un identifiant sans contexte — c'est le rôle de
/// [NirDetector], [IbanFrDetector] et [RppsDetector], restés stricts dans
/// `ecluse_core`. Ici, le libellé fait la preuve à la place de la clé : une
/// faute de frappe ou une erreur de lecture (OCR, recopie manuelle) laisse
/// un chiffre faux dans un NIR, un IBAN ou un RPPS par ailleurs correctement
/// annoncé — rien ne dit que la personne qui l'a écrit avait l'intention
/// d'écrire autre chose qu'un identifiant réel. Masquer quand même, à
/// confiance basse, avec un avertissement, est le choix qui protège : une
/// clé invalide en clair à côté de son libellé est une fuite presque
/// certaine, pas un faux positif probable.
///
/// Exception documentée comme celle d'ADELI (`DECISIONS.md`, « Ouvert » du
/// 2026-10) : masquer à confiance basse un numéro dont la clé est invalide
/// déroge à « clé validée ou rien », retenu ici pour la même raison — un
/// champ explicitement étiqueté qui fuit est pire qu'un sur-masquage.
///
/// **Forme du candidat** : reprise des motifs `_candidate` de
/// [NirDetector], [IbanFrDetector] et [RppsDetector] (séparateur simple —
/// espace, point ou tiret — entre groupes de chiffres), volontairement
/// dupliquée plutôt qu'importée depuis `ecluse_core/src/…` : la frontière
/// entre paquets reste celle des exports publics, pas des fichiers internes.
/// Limite assumée : contrairement aux détecteurs stricts, cette copie ne
/// passe pas par `DigitCompaction` et ne reconnaît donc pas un identifiant
/// aux espaces internes insécables ou multiples (voir `LIMITES.md`).
///
/// **Lecture par OCR ou recopie (P2-191)** : derrière un libellé fort
/// **seulement**, le candidat accepte aussi les confusions de lecture
/// courantes — la lettre O ou o pour 0, l ou I pour 1 (dans le corps d'un NIR
/// ou d'un RPPS, dans la clé d'un IBAN : `FRO2…`) — et **une ligne vide** que
/// l'OCR insère entre deux groupes. Un tel candidat est masqué **même si sa
/// clé est juste après correction** : le détecteur strict ne le voit pas
/// (lettres, ligne vide), donc personne d'autre ne le masquera. Ces
/// tolérances restent ici, jamais dans les détecteurs stricts de
/// `ecluse_core` (« clé validée ou rien » y reste entière). Dans le corps
/// d'un IBAN, les lettres sont déjà permises (le RIB en contient) et ne sont
/// pas « corrigées ».
///
/// **Ne masque jamais** un libellé seul (« NIR : non communiqué »), suivi
/// d'autre chose qu'une forme d'identifiant (un montant, une date), ou d'un
/// candidat déjà **valide** (couvert par le détecteur strict correspondant,
/// de confiance plus haute : `resolveOverlaps` retient toujours ce
/// dernier sur le même empan).
final class IdentifiantCleInvalideDetector implements EntityDetector {
  const IdentifiantCleInvalideDetector();

  @override
  EntityType get type => EntityType.identifiant;

  static const String _h = '[ \\t\\u00A0\\u202F]';

  /// Entre le libellé et le candidat : deux points optionnels, ou un
  /// marqueur « n° »/« numéro », jamais seulement une continuation de mot.
  static const String _sep = '(?:$_h*:$_h*|$_h+(?:n[°º]$_h*|num[ée]ro$_h+)?)';

  /// Libellés forts d'un NIR : le sigle, « N° de sécurité sociale », «
  /// numéro de sécurité sociale », « numéro SS », « n° SS ».
  static final RegExp _etiquetteNir = RegExp(
    r'(?<![A-Za-zÀ-ÿ])(?:NIR'
            r'|n[°º]$_h*de$_h+s[ée]curit[ée]$_h+sociale'
            r'|num[ée]ro$_h+de$_h+s[ée]curit[ée]$_h+sociale'
            r'|n[°º]$_h*SS'
            r'|num[ée]ro$_h+SS)(?![A-Za-zÀ-ÿ])'
        .replaceAll(r'$_h', _h),
    caseSensitive: false,
  );

  static final RegExp _etiquetteIban = RegExp(
    r'(?<![A-Za-zÀ-ÿ])IBAN(?![A-Za-zÀ-ÿ])',
    caseSensitive: false,
  );

  static final RegExp _etiquetteRpps = RegExp(
    r'(?<![A-Za-zÀ-ÿ])RPPS(?![A-Za-zÀ-ÿ])',
    caseSensitive: false,
  );

  /// Séparateur entre deux groupes d'un candidat : un séparateur simple
  /// (espace, point, tiret) ou, depuis P2-191, **une ligne vide** (deux fins
  /// de ligne, blancs permis) que l'OCR insère au milieu d'un identifiant.
  static const String _sepGroupe = '(?:[ .\\-]|$_h*\\r?\\n$_h*\\r?\\n$_h*)?';

  /// Un chiffre ou sa confusion de lecture courante (O, o pour 0 ; l, I pour 1).
  static const String _d = '[0-9OoIl]';

  /// Même forme que `NirDetector._candidate` (15 chiffres, 1-8 puis six
  /// groupes, 2A/2B toléré), non ancrée à `DigitCompaction`, avec les
  /// confusions O/o → 0 et l/I → 1 (P2-191). Le premier chiffre ne peut être
  /// que 1 à 8 : O n'y est pas toléré.
  static final RegExp _candidatNir = RegExp(
    '[1-8Il]$_sepGroupe$_d{2}$_sepGroupe$_d{2}$_sepGroupe'
    '(?:$_d{2}|2[ABab])$_sepGroupe$_d{3}$_sepGroupe$_d{3}$_sepGroupe$_d{2}',
  );

  /// Même forme que `IbanFrDetector._candidate` ; la clé (deux chiffres après
  /// « FR ») tolère les confusions de lecture (`FRO2…`, P2-191), le corps
  /// admet déjà des lettres.
  static final RegExp _candidatIban = RegExp(
    '[Ff][Rr]$_d{2}(?:$_sepGroupe[0-9A-Za-z]){23}',
  );

  /// Même forme que `RppsDetector._candidate` (11 chiffres), avec les
  /// confusions de lecture (P2-191).
  static final RegExp _candidatRpps = RegExp(
    '$_d(?:$_sepGroupe$_d){10}',
  );

  static final RegExp _separators = RegExp(r'[ .\-\t\r\n\u00A0\u202F]');

  /// Ce qui suit immédiatement ne doit pas être un chiffre : sinon le
  /// candidat déborde dans une séquence plus longue (traité par le
  /// détecteur strict correspondant, ou pas un identifiant du tout).
  static bool _nonChiffreApres(String text, int fin) =>
      fin >= text.length || !RegExp(r'[0-9]').hasMatch(text[fin]);

  static bool _nonAlphanumAvant(String text, int debut) =>
      debut <= 0 || !RegExp(r'[A-Za-z0-9]').hasMatch(text[debut - 1]);

  /// Clé NIR (mod 97), sans le contrôle de plausibilité du mois / département
  /// / numéro d'ordre qu'applique `NirDetector` : seule la clé importe ici,
  /// une erreur de mois ou de département n'étant pas la panne visée par
  /// cette tâche.
  static bool _cleNirValide(String nir) {
    if (nir.length != 15) return false;
    final body =
        nir.substring(0, 13).replaceFirst('2A', '19').replaceFirst('2B', '18');
    final number = int.tryParse(body);
    if (number == null) return false;
    final attendue = 97 - (number % 97);
    final reelle = int.tryParse(nir.substring(13, 15));
    return reelle == attendue;
  }

  /// Clé IBAN (ISO 7064 mod 97-10), copie de `IbanFrDetector._isValidIban`.
  static bool _cleIbanValide(String iban) {
    if (iban.length != 27) return false;
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    var remainder = 0;
    for (final unit in rearranged.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        remainder = (remainder * 10 + (unit - 0x30)) % 97;
      } else if (unit >= 0x41 && unit <= 0x5A) {
        remainder = (remainder * 100 + (unit - 0x41 + 10)) % 97;
      } else {
        return false;
      }
    }
    return remainder == 1;
  }

  /// Clé RPPS (Luhn), duplication volontaire et minimale de l'algorithme de
  /// `ecluse_core/src/luhn.dart` (« source unique : ne pas dupliquer
  /// ailleurs » y vaut à l'intérieur du paquet ; d'un paquet à l'autre, la
  /// frontière publique ne l'exporte pas).
  static bool _cleRppsValide(String rpps) {
    if (rpps.length != 11) return false;
    var sum = 0;
    var double = false;
    for (var i = rpps.length - 1; i >= 0; i--) {
      var d = rpps.codeUnitAt(i) - 0x30;
      if (d < 0 || d > 9) return false;
      if (double) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      double = !double;
    }
    return sum % 10 == 0;
  }

  /// O/o → 0, l/I → 1, sans toucher au reste (2A/2B d'un NIR corse inclus).
  static String _chiffres(String s) =>
      s.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp('[Il]'), '1');

  void _detecteType(
    String text,
    RegExp etiquette,
    RegExp candidat,
    int longueur,
    bool Function(String normalise) cleValide,
    EntityType entityType,
    List<DetectedEntity> resultats, {
    required bool iban,
  }) {
    for (final e in etiquette.allMatches(text)) {
      final sepMatch = RegExp(_sep).matchAsPrefix(text, e.end);
      if (sepMatch == null) continue;
      final c = candidat.matchAsPrefix(text, sepMatch.end);
      if (c == null) continue;
      final brut = c.group(0)!;
      if (!_nonAlphanumAvant(text, c.start) || !_nonChiffreApres(text, c.end)) {
        continue;
      }
      final sansSeparateur = brut.replaceAll(_separators, '');
      // Lecture par OCR (P2-191) : O/o → 0, l/I → 1 ; pour un IBAN, dans la
      // clé seulement (le corps admet des lettres). Une ligne vide dans
      // l'identifiant est elle aussi hors de portée du détecteur strict.
      final normalise = (iban
              ? sansSeparateur.substring(0, 2) +
                  _chiffres(sansSeparateur.substring(2, 4)) +
                  sansSeparateur.substring(4)
              : _chiffres(sansSeparateur))
          .toUpperCase();
      if (normalise.length != longueur) continue;
      final atypique = RegExp(r'[\r\n]').hasMatch(brut) ||
          (iban
              ? RegExp(r'[OoIl]').hasMatch(sansSeparateur.substring(2, 4))
              : RegExp(r'[OoIl]').hasMatch(sansSeparateur));
      // Valide et de forme ordinaire : affaire du détecteur strict
      // correspondant. Valide mais atypique : le détecteur strict ne le voit
      // pas, on le masque ici.
      if (!atypique && cleValide(normalise)) continue;
      resultats.add(
        DetectedEntity(
          type: entityType,
          start: c.start,
          end: c.end,
          value: brut,
          confidence: 0.3,
        ),
      );
    }
  }

  @override
  List<DetectedEntity> detect(String text) {
    final resultats = <DetectedEntity>[];
    _detecteType(text, _etiquetteNir, _candidatNir, 15, _cleNirValide,
        EntityType.nir, resultats,
        iban: false);
    _detecteType(text, _etiquetteIban, _candidatIban, 27, _cleIbanValide,
        EntityType.iban, resultats,
        iban: true);
    _detecteType(text, _etiquetteRpps, _candidatRpps, 11, _cleRppsValide,
        EntityType.rpps, resultats,
        iban: false);
    resultats.sort((a, b) => a.start - b.start);
    return resultats;
  }
}
