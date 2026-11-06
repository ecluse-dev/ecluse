/// Casse d'un texte, pour choisir les détecteurs qui s'y appliquent
/// (P2-138).
///
/// Les détecteurs habituels reconnaissent un nom, une commune ou un
/// établissement à sa majuscule initiale. Un texte qui n'en porte pas — tout
/// en minuscules, tout en capitales, ou en « casse de phrase » (seule la
/// première lettre de la phrase est en majuscule : « Rdv avec m. julien
/// chevrier ») — passe par des détecteurs dédiés. La casse de phrase est la
/// plus courante (saisie rapide, correcteur qui ne capitalise que le début) :
/// avant P2-138, seul le texte **sans aucune** majuscule était traité, et la
/// fuite globale du corpus réaliste en casse de phrase était de 61,9 %.
///
/// Interne au paquet : non exporté par `ecluse_redact.dart`.
enum CasseTexte {
  /// Des majuscules hors début de phrase : noms propres probablement
  /// capitalisés, détecteurs habituels.
  ordinaire,

  /// Aucune majuscule, ou seulement en début de phrase, de ligne ou dans un
  /// sigle (« SSIAD »). Une majuscule après une abréviation (« M. Dupont »)
  /// est celle d'un nom propre : casse ordinaire.
  minuscules,

  /// Aucune minuscule.
  capitales,
}

final RegExp _majuscule = RegExp(r'\p{Lu}', unicode: true);
final RegExp _minuscule = RegExp(r'\p{Ll}', unicode: true);
final RegExp _mot = RegExp(r"[\p{L}][\p{L}'’-]*", unicode: true);

/// Avant un mot en début de phrase : début du texte, fin de phrase (. ! ? :
/// ; …), saut de ligne, puis blancs, tirets de liste, puces ou guillemets.
final RegExp _debutDePhrase =
    RegExp(r'(?:^|[.!?:;…\n])[ \t  ]*(?:[-–—•*>«"(][ \t  ]*)*$', unicode: true);

/// Abréviation juste avant un mot (« M. Dupont », « Dr. Martin », « J. ») :
/// la majuscule qui suit est celle d'un nom propre, pas d'un début de phrase.
/// Sans cette règle, « M. Dupont est venu. » passait pour un texte en casse
/// de phrase (mesure P2-138 : tests existants « M. J. est venu », « M.
/// Bénéficiaire du RSA »).
final RegExp _apresAbreviation = RegExp(
    r'(?:^|[^\p{L}])(?:m|mme|mlle|mr|dr|pr|me|st|ste|\p{L})\.[ \t\u00A0\u202F]*$',
    unicode: true,
    caseSensitive: false);

/// Casse de [text].
CasseTexte casseDuTexte(String text) {
  if (!_majuscule.hasMatch(text)) return CasseTexte.minuscules;
  if (!_minuscule.hasMatch(text)) return CasseTexte.capitales;
  for (final m in _mot.allMatches(text)) {
    final mot = m.group(0)!;
    if (!_majuscule.hasMatch(mot)) continue;
    // Sigle tout en capitales (deux lettres au moins) : neutre.
    if (!_minuscule.hasMatch(mot) &&
        mot.replaceAll(RegExp(r"['’-]"), '').length >= 2) {
      continue;
    }
    // Seule l'initiale est en capitale, et le mot ouvre une phrase.
    final reste = mot.substring(1);
    final debut = m.start > 40 ? m.start - 40 : 0;
    final avant = text.substring(debut, m.start);
    if (!_majuscule.hasMatch(reste) &&
        _debutDePhrase.hasMatch(avant) &&
        !_apresAbreviation.hasMatch(avant)) {
      continue;
    }
    return CasseTexte.ordinaire;
  }
  return CasseTexte.minuscules;
}

/// [text] en minuscules, ou `null` si la longueur changerait (les positions
/// ne vaudraient plus pour l'original).
String? enMinuscules(String text) {
  final bas = text.toLowerCase();
  return bas.length == text.length ? bas : null;
}
