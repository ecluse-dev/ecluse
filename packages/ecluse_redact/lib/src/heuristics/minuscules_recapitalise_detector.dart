import 'package:ecluse_core/ecluse_core.dart';

import 'etablissement_keywords.dart';
import 'mots_neutres.dart';

/// Rend aux adresses et aux établissements d'un texte **sans aucune
/// majuscule** la casse que leurs détecteurs attendent (P2-120).
///
/// Pourquoi : [AdresseDetector] et [EtablissementDetector] reconnaissent un
/// nom de voie, une commune ou un nom d'établissement à sa majuscule
/// initiale. Sur un texte en minuscules, la mesure P2-117 trouve 100 % de
/// fuite pour les deux. Plutôt que d'écrire une seconde version de chaque
/// motif, ce détecteur passe au détecteur [interne] un **texte d'ombre** où
/// chaque mot reçoit une majuscule initiale (sauf les mots outils et les
/// unités, voir [_neutres]), et les sigles d'établissement
/// connus (« ehpad », « ssiad ») sont remis en capitales. Le texte d'ombre a
/// **la même longueur** que l'original : les positions rendues valent pour
/// l'original, et la valeur est relue dans l'original.
///
/// Actif **seulement** si le texte n'a aucune majuscule, ou aucune minuscule
/// (texte en capitales, P2-122 : il est d'abord mis en minuscules) : sur un
/// texte en casse ordinaire il ne rend rien, et le comportement d'Écluse y
/// est inchangé.
/// Si une mise en capitale changeait la longueur (cas d'écriture rares), le
/// détecteur ne rend rien plutôt que des positions fausses.
///
/// Les noms de personnes ne passent **pas** par ce texte d'ombre : tout
/// capitaliser ferait d'un mot sur deux un nom possible. Ils ont leur
/// détecteur dédié, `NomMinusculesDetector` (P2-119).
final class MinusculesRecapitaliseDetector implements EntityDetector {
  const MinusculesRecapitaliseDetector(this.interne,
      {this.communesSeules = false, this.capitales = true});

  /// Traiter aussi un texte sans aucune minuscule. Faux pour les adresses :
  /// `AdresseDetector` lit déjà un texte en capitales (1,9 % de fuite sur
  /// l'adversarial, P2-121) et en écarte lui-même les mots neutres (P2-122).
  final bool capitales;

  /// Détecteur appliqué au texte d'ombre.
  final EntityDetector interne;

  /// Ne recapitaliser que la commune qui suit un code postal. Pour les
  /// adresses : une voie sans code postal n'est reconnue qu'à la majuscule de
  /// son nom, et tout recapitaliser ferait une adresse de « 3 chemin de fer »
  /// ou « 12 place disponible » (règle tenue par
  /// `adresse_sans_code_postal_test.dart`). Une voie sans code postal reste
  /// donc non détectée dans un texte en minuscules.
  final bool communesSeules;

  /// Code postal suivi des mots de la commune, jusqu'à une ponctuation ou une
  /// fin de ligne.
  static final RegExp _cpCommune = RegExp(
      r"(?<!\d)\d{5}[ \t\u00A0\u202F]+([\p{L}'’\- \t\u00A0\u202F]+)",
      unicode: true);

  /// Indice d'adresse suivi de ce qui le suit sur la même ligne (P2-131) :
  /// « située 30 boulevard aristide briand », « demeurant 3 route de
  /// vellexon », « adresse du chantier : 8 chemin des vignes ». Après un tel
  /// indice, le nom de voie est recapitalisé même sans code postal ; sans
  /// lui, « 3 chemin de fer » reste intact (`adresse_sans_code_postal_test`).
  static final RegExp _indiceAdresse = RegExp(
      r'(?<![\p{L}])(?:situ[ée]e?s?|sise?s?|demeurant|domicili[ée]e?s?|'
      r'r[ée]sidant|adresse[^:\n]{0,30}:)[ \t\u00A0\u202F]*(?:\n[ \t]*)?'
      r'(\d{1,4}[^\n,.;]{0,60})',
      unicode: true);

  @override
  EntityType get type => interne.type;

  static final RegExp _majuscule = RegExp(r'\p{Lu}', unicode: true);

  static final RegExp _motEntier = RegExp(r'\p{L}+', unicode: true);

  /// Mots laissés en minuscules dans le texte d'ombre : laissés tels quels,
  /// les connecteurs des noms de commune (« port sur saone » → « Port sur
  /// Saone ») restent corrects, et « 70000 euros » ne devient pas une
  /// adresse. Voir [motsNeutres].
  static const Set<String> _neutres = motsNeutres;

  /// Sigles d'établissement entièrement en capitales dans la liste partagée.
  /// « CEDEX » s'écrit en capitales dans une adresse ; « Cedex 9 » n'est
  /// pas reconnu jusqu'au numéro (mesure P2-122).
  static final Set<String> _sigles = {
    for (final k in etablissementKeywords)
      if (k.length > 1 && k == k.toUpperCase()) k.toLowerCase(),
    'cedex',
  };

  /// Élision en tête de commune (« 25250 l'isle-sur-le-doubs ») : « l » et
  /// « d » y prennent la majuscule, alors qu'ils restent neutres ailleurs.
  static final RegExp _elisionCommune = RegExp(
      r"(?<!\d)(\d{5}[ \t\u00A0\u202F]+)([ld])(?=['’]\p{L})",
      unicode: true);

  static String _recapitalise(String mot) {
    if (_sigles.contains(mot)) return mot.toUpperCase();
    if (_neutres.contains(mot)) return mot;
    final initiale = mot[0].toUpperCase();
    if (initiale.length != 1) return mot;
    return initiale + mot.substring(1);
  }

  /// Texte d'ombre, ou `null` si sa longueur différerait de l'original.
  /// Avec [seulementCommunes], seuls les mots qui suivent un code postal sont
  /// recapitalisés, et rien si le premier est un mot neutre (« 70000 euros »).
  static String? ombre(String text, {bool seulementCommunes = false}) {
    final String t;
    if (!seulementCommunes) {
      t = text.replaceAllMapped(_motEntier, (m) => _recapitalise(m.group(0)!));
    } else {
      t = text.replaceAllMapped(_cpCommune, (m) {
        final commune = m.group(1)!;
        // « l'isle » : l'élision ne décide pas, c'est le mot qui la suit.
        final mots = [
          for (final w in _motEntier.allMatches(commune)) w.group(0)!
        ];
        final premier = mots.length > 1 &&
                (mots[0] == 'l' || mots[0] == 'd') &&
                commune.trimLeft().length > 1 &&
                "'’".contains(commune.trimLeft()[1])
            ? mots[1]
            : (mots.isEmpty ? null : mots[0]);
        if (premier == null || _neutres.contains(premier)) return m.group(0)!;
        final debut =
            m.group(0)!.substring(0, m.group(0)!.length - commune.length);
        return debut +
            commune.replaceAllMapped(
                _motEntier, (w) => _recapitalise(w.group(0)!));
      });
    }
    var v = t;
    if (seulementCommunes) {
      v = v.replaceAllMapped(_indiceAdresse, (m) {
        final voie = m.group(1)!;
        final tete = m.group(0)!.substring(0, m.group(0)!.length - voie.length);
        return tete +
            voie.replaceAllMapped(
                _motEntier, (w) => _recapitalise(w.group(0)!));
      });
    }
    final u =
        v.replaceAllMapped(_elisionCommune, (m) => m.group(0)!.toUpperCase());
    return u.length == text.length ? u : null;
  }

  static final RegExp _minuscule = RegExp(r'\p{Ll}', unicode: true);

  /// Texte de départ du texte d'ombre : le texte lui-même s'il n'a aucune
  /// majuscule ; sa version en minuscules s'il n'a aucune minuscule (texte
  /// entièrement en capitales, P2-122) ; `null` sinon (casse ordinaire, les
  /// détecteurs habituels suffisent).
  static String? _base(String text) {
    if (!_majuscule.hasMatch(text)) return text;
    if (_minuscule.hasMatch(text)) return null;
    final bas = text.toLowerCase();
    return bas.length == text.length ? bas : null;
  }

  @override
  List<DetectedEntity> detect(String text) {
    final base = _base(text);
    if (base == null || (!capitales && !identical(base, text))) {
      return const [];
    }
    // [communesSeules] ne vaut que pour un texte en minuscules : en
    // capitales, `AdresseDetector` reconnaissait déjà les voies sans code
    // postal (« 3 ROUTE DE VELLEXON ») avant P2-122, on ne les perd pas.
    final t =
        ombre(base, seulementCommunes: communesSeules && identical(base, text));
    if (t == null) return const [];
    return [
      for (final e in interne.detect(t))
        DetectedEntity(
          type: e.type,
          start: e.start,
          end: e.end,
          value: text.substring(e.start, e.end),
          confidence: e.confidence,
          tier: e.tier,
        ),
    ];
  }
}
