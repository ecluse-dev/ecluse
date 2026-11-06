import 'package:ecluse_core/ecluse_core.dart';

import 'etablissement_keywords.dart';

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
/// Actif **seulement** si le texte n'a aucune majuscule : sur un texte
/// ordinaire il ne rend rien, et le comportement d'Écluse y est inchangé.
/// Si une mise en capitale changeait la longueur (cas d'écriture rares), le
/// détecteur ne rend rien plutôt que des positions fausses.
///
/// Les noms de personnes ne passent **pas** par ce texte d'ombre : tout
/// capitaliser ferait d'un mot sur deux un nom possible. Ils ont leur
/// détecteur dédié, `NomMinusculesDetector` (P2-119).
final class MinusculesRecapitaliseDetector implements EntityDetector {
  const MinusculesRecapitaliseDetector(this.interne,
      {this.communesSeules = false});

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

  @override
  EntityType get type => interne.type;

  static final RegExp _majuscule = RegExp(r'\p{Lu}', unicode: true);

  static final RegExp _motEntier = RegExp(r'\p{L}+', unicode: true);

  /// Mots laissés en minuscules dans le texte d'ombre : mots outils, unités,
  /// monnaie. Capitalisés, « 70000 euros » ou « 75015 pour l'antenne »
  /// prendraient la forme d'un code postal suivi d'une commune (mesure
  /// P2-120 sur le corpus témoin) ; laissés tels quels, les connecteurs des
  /// noms de commune (« port sur saone » → « Port sur Saone ») restent
  /// corrects.
  static const Set<String> _neutres = {
    'le', 'la', 'les', 'l', 'de', 'du', 'des', 'd', 'au', 'aux', 'et', //
    'ou', 'à', 'en', 'sur', 'sous', 'pour', 'par', 'avec', 'sans', 'chez', //
    'vers', 'dans', 'un', 'une', 'ce', 'cet', 'cette', 'ces', 'son', 'sa', //
    'ses', 'leur', 'leurs', 'qui', 'que', 'est', 'sont', //
    'euro', 'euros', 'eur', 'centimes', 'habitants', 'personnes', //
    'patients', 'ans', 'mois', 'jours', 'heures', 'minutes', //
    // Noms de comptage courants après un grand nombre (« 21000 dossiers »,
    // « 39100 numéros », ponctuation perdue) : mesure P2-120, témoin sans
    // ponctuation.
    'dossier', 'dossiers', 'numéro', 'numéros', 'lits', 'places', //
    'agents', 'salariés', 'résidents', 'appels', 'actes', //
    'ui', 'iu', 'mg', 'mcg', 'ng', 'pg', 'ml', 'cl', 'dl', 'kg', 'mol', //
    'mmol', 'meq', 'cm', 'mm', 'km', 'kcal', //
  };

  /// Sigles d'établissement entièrement en capitales dans la liste partagée.
  static final Set<String> _sigles = {
    for (final k in etablissementKeywords)
      if (k.length > 1 && k == k.toUpperCase()) k.toLowerCase(),
  };

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
        final premier = _motEntier.firstMatch(commune)?.group(0);
        if (premier == null || _neutres.contains(premier)) return m.group(0)!;
        final debut =
            m.group(0)!.substring(0, m.group(0)!.length - commune.length);
        return debut +
            commune.replaceAllMapped(
                _motEntier, (w) => _recapitalise(w.group(0)!));
      });
    }
    return t.length == text.length ? t : null;
  }

  @override
  List<DetectedEntity> detect(String text) {
    if (_majuscule.hasMatch(text)) return const [];
    final t = ombre(text, seulementCommunes: communesSeules);
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
