import 'package:ecluse_core/ecluse_core.dart';

/// Identifiant lu avec des **lettres d'OCR** à la place de chiffres (P2-268) :
/// « O » ou « o » pour 0, « l » ou « I » pour 1. Masqué en entier, à confiance
/// basse, quand il redevient un identifiant **valide une fois les lettres
/// relues comme des chiffres**.
///
/// Pourquoi : les détecteurs stricts d'`ecluse_core` exigent des chiffres
/// (« clé validée ou rien »). Un NIR ou un RPPS que l'OCR a lu « 2 55 O8 … »
/// leur échappe, et sans libellé personne d'autre ne le masque. Mesure P2-264,
/// par `Ecluse.redact` : fuite au caractère de 97,6 % (NIR), 98,8 % (RPPS),
/// 100 % (FINESS), 99,1 % (SIREN) sans libellé, 22,2 % pour l'IBAN. Même
/// derrière un libellé, FINESS et SIREN n'étaient pas relus, et les
/// séparateurs multiples (deux espaces insécables, tabulation) laissaient fuir
/// 22,7 % des NIR et 12,7 % des IBAN que `IdentifiantCleInvalideDetector`
/// aurait masqués s'ils n'avaient eu qu'un séparateur simple.
///
/// **Le texte n'est jamais réécrit** : la relecture ne sert qu'à juger ; la
/// valeur masquée et la table de restauration gardent l'écriture d'origine.
///
/// **Règle par type** (décision du 23 novembre, nuit, `DECISIONS.md`) :
///
/// - *Clé forte*, **avec ou sans libellé** : NIR (15 caractères, sexe 1 ou 2 sans
///   libellé et 1 à 8 avec, mois,
///   département et numéro d'ordre plausibles, clé mod 97) et IBAN français
///   (« FR » + 25 caractères, mod 97). Sans libellé, la suite entière doit avoir
///   exactement la longueur de l'identifiant (jamais une sous-suite d'une suite
///   plus longue) ; derrière un libellé, c'est la suite qui suit le libellé qui
///   est lue, même si elle se prolonge (« NIR : … 91 12 ans »).
/// - *Clé faible* (Luhn seul : RPPS, FINESS, SIREN, ADELI), **derrière un
///   libellé seulement**. Sans libellé, un nombre de 9 ou 11 chiffres a une
///   chance sur dix d'être Luhn-valide : le témoin durci de P2-268 donne 7
///   faux accords sur 450 documents sans identifiant (5 de neuf chiffres, 2 de
///   onze). Les mots-clés sont les seuls **libellés explicites** (« RPPS »,
///   « FINESS », « SIREN », « ADELI »), pas la liste élargie des nombres dictés
///   (P2-267), dont le mot « code » est trop large pour une suite écrite où il
///   précède aussi bien un code produit qu'un identifiant ; à rouvrir avec la
///   mesure de P2-270.
///
/// **Au moins une lettre d'OCR** est exigée dans la suite : sans elle, ce sont
/// les détecteurs stricts et `IdentifiantCleInvalideDetector` qui jugent, et
/// rien ne change (prédictions identiques sur tous les autres corpus).
///
/// **Séparateurs** : un à quatre blancs (espace, tabulation, espace insécable,
/// espace fine) ou un seul point, tiret ou barre oblique entre deux groupes. Les
/// fins de ligne ne sont pas franchies. Le NIR corse (« 2A »/« 2B ») n'est pas
/// relu ici (une lettre qui n'est pas d'OCR dans la suite l'écarte) ; limite
/// consignée dans `LIMITES.md`.
///
/// **Sortie** : confiance 0,3, [Provenance.lectureOcr] (l'avertissement
/// « à vérifier » et l'aperçu en dépendent), jamais de valeur dans un message.
/// Détecteur pur : aucune lecture hors du texte, aucun état.
final class IdentifiantOcrDetector implements EntityDetector {
  const IdentifiantOcrDetector();

  @override
  EntityType get type => EntityType.identifiant;

  /// Confiance des identifiants relus : la valeur peut être fausse, le
  /// masquage tient (décision, point 5).
  static const double confidence = 0.3;

  static final RegExp _jeton = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static const String _h = '[ \\t\\u00A0\\u202F\\u2009]';

  /// Entre le libellé et la suite : deux points, ou un marqueur « n° » /
  /// « numéro », ou de simples blancs. Jamais la continuation d'un mot.
  static const String _sep = '(?:$_h*:$_h*|$_h+(?:n[°º]$_h*|num[ée]ro$_h+)?)';

  static final RegExp _etiquetteNir = RegExp(
    '(?<![A-Za-zÀ-ÿ])(?:NIR'
    '|n[°º]$_h*de$_h+s[ée]curit[ée]$_h+sociale'
    '|num[ée]ro$_h+de$_h+s[ée]curit[ée]$_h+sociale'
    '|n[°º]$_h*SS'
    '|num[ée]ro$_h+SS)(?![A-Za-zÀ-ÿ])$_sep',
    caseSensitive: false,
  );

  static RegExp _etiquette(String mot) => RegExp(
        '(?<![A-Za-zÀ-ÿ])$mot(?![A-Za-zÀ-ÿ])$_sep',
        caseSensitive: false,
      );

  static final RegExp _etiquetteRpps = _etiquette('RPPS');
  static final RegExp _etiquetteFiness = _etiquette('FINESS');
  static final RegExp _etiquetteSiren = _etiquette('SIREN');
  static final RegExp _etiquetteAdeli = _etiquette('ADELI');

  /// Au plus ce nombre de jetons dans une suite : borne le coût, un
  /// identifiant en comptant au plus une trentaine.
  static const int _maxJetons = 40;

  static bool _estBlanc(int c) =>
      c == 0x20 || c == 0x09 || c == 0xA0 || c == 0x202F || c == 0x2009;

  /// Vrai si [gap] (le texte entre deux jetons) sépare deux groupes d'un même
  /// identifiant : un à quatre blancs, ou un seul point, tiret ou barre.
  static bool _separeDeuxGroupes(String gap) {
    if (gap.isEmpty) return false;
    if (gap.length == 1) {
      final c = gap.codeUnitAt(0);
      return _estBlanc(c) || c == 0x2E || c == 0x2D || c == 0x2F;
    }
    if (gap.length > 4) return false;
    for (final c in gap.codeUnits) {
      if (!_estBlanc(c)) return false;
    }
    return true;
  }

  static bool _estPur(String jeton) {
    for (final c in jeton.codeUnits) {
      final chiffre = c >= 0x30 && c <= 0x39;
      if (!chiffre && c != 0x4F && c != 0x6F && c != 0x6C && c != 0x49) {
        return false;
      }
    }
    return true;
  }

  static bool _aUneLettreOcr(String s) => RegExp('[OolI]').hasMatch(s);

  /// O/o → 0, l/I → 1.
  static String _relue(String s) =>
      s.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp('[lI]'), '1');

  static bool _ibanValide(String iban) {
    if (iban.length != 27) return false;
    final rearrange = iban.substring(4) + iban.substring(0, 4);
    var reste = 0;
    for (final c in rearrange.codeUnits) {
      if (c >= 0x30 && c <= 0x39) {
        reste = (reste * 10 + (c - 0x30)) % 97;
      } else if (c >= 0x41 && c <= 0x5A) {
        reste = (reste * 100 + (c - 0x41 + 10)) % 97;
      } else {
        return false;
      }
    }
    return reste == 1;
  }

  /// Sans libellé, le sexe est 1 ou 2 (le prototype mesuré de P2-264 n'en
  /// acceptait pas d'autre) : avec 1 à 8 comme `NirDetector`, le témoin durci
  /// de P2-268 donnait 1 faux accord sur 450 documents (« 8OI6O.49703.o5067 »),
  /// contre 0 avec 1 ou 2. Derrière un libellé, 1 à 8 : le libellé fait la
  /// preuve (NIR provisoires et d'étrangers : sexe 3 à 8).
  static bool _nirValide(String d, {required bool sexeLarge}) {
    if (d.length != 15) return false;
    for (final c in d.codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
    final sexe = d.codeUnitAt(0) - 0x30;
    if (sexe < 1 || sexe > (sexeLarge ? 8 : 2)) return false;
    final mois = int.parse(d.substring(3, 5));
    if (!((mois <= 12) || (mois >= 20 && mois <= 42) || mois >= 50)) {
      return false;
    }
    if (int.parse(d.substring(5, 7)) < 1) return false;
    if (int.parse(d.substring(10, 13)) < 1) return false;
    final attendue = 97 - (int.parse(d.substring(0, 13)) % 97);
    return int.parse(d.substring(13, 15)) == attendue;
  }

  static bool _luhn9(String d) =>
      d.length == 9 && isLuhnValid(d.padLeft(11, '0'));

  static bool _luhn11(String d) => d.length == 11 && isLuhnValid(d);

  @override
  List<DetectedEntity> detect(String text) {
    // Sans lettre d'OCR dans tout le texte, rien à relire : sortie immédiate.
    if (!_aUneLettreOcr(text)) return const [];
    final jetons = [for (final m in _jeton.allMatches(text)) m];
    if (jetons.isEmpty) return const [];

    // Jeton i et jeton i+1 sont-ils deux groupes d'une même suite ?
    final lies = List<bool>.filled(jetons.length, false);
    for (var i = 0; i + 1 < jetons.length; i++) {
      lies[i] = _separeDeuxGroupes(
          text.substring(jetons[i].end, jetons[i + 1].start));
    }
    final purs = [for (final j in jetons) _estPur(j.group(0)!)];

    final resultats = <DetectedEntity>[];
    final vus = <(int, int)>{};

    void emet(EntityType t, int debut, int fin) {
      if (!vus.add((debut, fin))) return;
      resultats.add(DetectedEntity(
        type: t,
        start: debut,
        end: fin,
        value: text.substring(debut, fin),
        confidence: confidence,
        tier: DetectorTier.pattern,
        provenance: Provenance.lectureOcr,
      ));
    }

    // Sans libellé : NIR, seulement une suite entière de 15 caractères.
    var i = 0;
    while (i < jetons.length) {
      if (!purs[i]) {
        i++;
        continue;
      }
      var j = i;
      var longueur = jetons[i].group(0)!.length;
      var nombre = 1;
      while (j + 1 < jetons.length &&
          lies[j] &&
          purs[j + 1] &&
          nombre < _maxJetons) {
        j++;
        nombre++;
        longueur += jetons[j].group(0)!.length;
      }
      if (longueur == 15) {
        final brut = [for (var k = i; k <= j; k++) jetons[k].group(0)!].join();
        if (_aUneLettreOcr(brut) &&
            _nirValide(_relue(brut), sexeLarge: false)) {
          emet(EntityType.nir, jetons[i].start, jetons[j].end);
        }
      }
      i = j + 1;
    }

    // IBAN français, avec ou sans libellé : « FR » + 25 caractères.
    for (var k = 0; k < jetons.length; k++) {
      final premier = jetons[k].group(0)!;
      if (premier.length < 2 || premier.substring(0, 2).toUpperCase() != 'FR') {
        continue;
      }
      final fin = _fenetre(jetons, lies, k, 27, pur: false);
      if (fin < 0) continue;
      final brut = [for (var m = k; m <= fin; m++) jetons[m].group(0)!].join();
      final corps = brut.substring(2);
      if (!_aUneLettreOcr(corps)) continue;
      final majuscules = 'FR${corps.toUpperCase()}';
      // Valide tel quel : l'affaire de `IbanFrDetector` (confiance 1,0).
      if (_ibanValide(majuscules)) continue;
      if (_ibanValide('FR${_relue(corps)}'.toUpperCase())) {
        emet(EntityType.iban, jetons[k].start, jetons[fin].end);
      }
    }

    // Derrière un libellé : NIR (suite lue depuis le libellé), puis RPPS,
    // FINESS, SIREN, ADELI.
    void derriere(RegExp etiquette, int cible, EntityType t,
        bool Function(String) valide) {
      for (final e in etiquette.allMatches(text)) {
        final k = _jetonA(jetons, e.end);
        if (k < 0 || !purs[k]) continue;
        final fin = _fenetre(jetons, lies, k, cible, pur: true);
        if (fin < 0) continue;
        final brut =
            [for (var m = k; m <= fin; m++) jetons[m].group(0)!].join();
        if (!_aUneLettreOcr(brut)) continue;
        if (valide(_relue(brut))) {
          emet(t, jetons[k].start, jetons[fin].end);
        }
      }
    }

    derriere(_etiquetteNir, 15, EntityType.nir,
        (d) => _nirValide(d, sexeLarge: true));
    derriere(_etiquetteRpps, 11, EntityType.rpps, _luhn11);
    derriere(_etiquetteFiness, 9, EntityType.finess, _luhn9);
    derriere(_etiquetteSiren, 9, EntityType.siren, _luhn9);
    derriere(_etiquetteAdeli, 9, EntityType.adeli, _luhn9);

    resultats.sort((a, b) => a.start - b.start);
    return resultats;
  }

  /// Indice du jeton qui commence exactement à [position], ou -1.
  static int _jetonA(List<RegExpMatch> jetons, int position) {
    var bas = 0;
    var haut = jetons.length;
    while (bas < haut) {
      final milieu = (bas + haut) >> 1;
      if (jetons[milieu].start < position) {
        bas = milieu + 1;
      } else {
        haut = milieu;
      }
    }
    return bas < jetons.length && jetons[bas].start == position ? bas : -1;
  }

  /// Indice du dernier jeton de la fenêtre qui commence au jeton [debut] et
  /// totalise exactement [cible] caractères, ou -1. Avec [pur], tous les jetons
  /// sont de l'alphabet `[0-9OolI]`.
  static int _fenetre(
    List<RegExpMatch> jetons,
    List<bool> lies,
    int debut,
    int cible, {
    required bool pur,
  }) {
    var longueur = 0;
    for (var k = debut; k < jetons.length && k - debut < _maxJetons; k++) {
      final jeton = jetons[k].group(0)!;
      if (pur && !_estPur(jeton)) return -1;
      longueur += jeton.length;
      if (longueur == cible) return k;
      if (longueur > cible) return -1;
      if (!lies[k]) return -1;
    }
    return -1;
  }
}
