import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique de numéros de téléphone français — **v0 de
/// démonstration**.
///
/// Formats couverts : `0X XX XX XX XX`, `+33 X XX XX XX XX`, `(+33) X ...`,
/// `+33 (0)X ...`, `0033 X ...` et les indicatifs d'outre-mer (`+262`, `+590`,
/// `+594`, `+596`), les pays voisins et le Maghreb (P2-60), avec séparateurs espace, point, tiret,
/// espace insécable (NBSP, U+202F) ou sans séparateur. Les numéros courts
/// (15, 112, 3114…) ne sont jamais détectés : le motif exige 10 chiffres.
/// Aucune clé de contrôle n'existe pour un numéro de téléphone : confiance
/// modérée (0.8), le motif étant néanmoins très spécifique.
final class TelephoneDetector implements EntityDetector {
  const TelephoneDetector();

  @override
  EntityType get type => EntityType.telephone;

  /// Séparateur toléré entre groupes : espace, point, tiret, barre oblique,
  /// NBSP, U+202F.
  static const String _sep = r'[ .\-/\u00A0\u202F]';

  /// Préfixe national `0X`, national entre parenthèses `(0X)`, international
  /// `+33 X` / `+33 (0)X` / `0033 X` / `00 33 X`. Le chiffre significatif X
  /// va de 1 à 9 ; `(0)` n'est admis que parenthésé (un `+33 0…` nu n'est pas
  /// un format valide).
  static const String _prefixe = '(?:\\(0[1-9]\\)|0[1-9]|'
      '(?:\\+33|\\(\\+33\\)|00$_sep?33)$_sep?(?:\\(0\\)$_sep?)?[1-9])';

  /// Indicatifs des départements d'outre-mer, numéros français : La Réunion et
  /// Mayotte `+262`, Guadeloupe `+590`, Guyane `+594`, Martinique `+596`
  /// (« +262 692 12 34 56 », soit `0692 12 34 56`).
  static const String _outreMer = '\\+(?:262|590|594|596)$_sep?'
      '(?:\\(0\\)$_sep?)?[1-9][0-9]{2}(?:$_sep?[0-9]{2}){3}';

  /// Pays étrangers couverts (P2-60) : indicatif, nombre minimal et maximal de
  /// chiffres du numéro national (hors `(0)` facultatif). Voisins de la France et
  /// Maghreb ; les autres pays ne sont pas couverts. L'indicatif est obligatoire
  /// (`+cc`, `(+cc)` ou `00cc`) et la longueur doit être celle du pays.
  static const List<(String, int, int)> _pays = [
    ('32', 8, 9), // Belgique
    ('41', 9, 9), // Suisse
    ('352', 6, 9), // Luxembourg
    ('49', 8, 13), // Allemagne
    ('34', 9, 9), // Espagne
    ('39', 8, 11), // Italie
    ('44', 9, 10), // Royaume-Uni
    ('212', 9, 9), // Maroc
    ('213', 8, 9), // Algérie
    ('216', 8, 8), // Tunisie
  ];

  static final String _etranger = _pays.map((p) {
    final (cc, min, max) = p;
    // L'Italie conserve le 0 initial des lignes fixes (« +39 06 1234 5678 »).
    final premier = cc == '39' ? '[0-9]' : '[1-9]';
    return '(?:\\+|\\(\\+|00$_sep?)$cc\\)?$_sep?(?:\\(0\\)$_sep?)?'
        '$premier(?:$_sep?[0-9]){${min - 1},${max - 1}}';
  }).join('|');

  static final RegExp _pattern = RegExp(
    '(?<![0-9])(?:'
    // Dix chiffres en groupes de 2 (format courant).
    '$_prefixe(?:$_sep?[0-9]{2}){4}'
    // Format 4-3-3 (« 0612 345 678 »).
    '|0[1-9][0-9]{2}$_sep[0-9]{3}$_sep[0-9]{3}'
    // Indicatifs d'outre-mer (« +262 692 12 34 56 »).
    '|$_outreMer'
    // Pays voisins et Maghreb (P2-60).
    '|$_etranger'
    ')(?![0-9])',
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
      results.add(
        DetectedEntity(
          type: EntityType.telephone,
          start: match.start,
          end: match.end,
          value: match.group(0)!,
          confidence: 0.8,
        ),
      );
    }
    return results;
  }
}
