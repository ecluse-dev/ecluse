import 'package:meta/meta.dart';

/// Table des substitutions couramment observées en sortie d'OCR.
///
/// Chaque clé est un caractère (ou digramme) qu'un OCR peut confondre
/// avec l'ensemble des valeurs. Les substitutions vont dans les deux
/// sens (`O`↔`0`) et sont **symétriques par convention** : la table doit
/// contenir les deux directions.
///
/// Sources : littérature OCR + observations empiriques sur les
/// caractères fréquemment confondus dans les documents santé français
/// scannés (NIR, RPPS, dates de naissance).
class AmbiguitySubstitutions {
  const AmbiguitySubstitutions(this.singles, this.digrams);

  /// Substitutions caractère → caractère(s).
  final Map<String, Set<String>> singles;

  /// Substitutions digramme → caractère (et inverse).
  /// Utilisé pour les cas type `rn` ↔ `m`, `cl` ↔ `d`.
  final Map<String, Set<String>> digrams;

  /// Table par défaut adaptée aux OCR courants sur documents santé FR.
  static const AmbiguitySubstitutions defaults = AmbiguitySubstitutions(
    {
      // Chiffres et lettres qui se confondent.
      'O': {'0'}, '0': {'O', 'Q', 'D'},
      'I': {'1', 'l', '|'}, '1': {'I', 'l', '|'},
      'l': {'1', 'I'},
      'S': {'5'}, '5': {'S'},
      'B': {'8'}, '8': {'B'},
      'Z': {'2'}, '2': {'Z'},
      'G': {'6'}, '6': {'G'},
      'T': {'7'}, '7': {'T'},
      'g': {'9'}, '9': {'g', 'q'},
      'q': {'9'},
      'D': {'0'},
      'Q': {'0'},
    },
    {
      'rn': {'m'},
      'm': {'rn'},
      'cl': {'d'},
      'd': {'cl'},
      'vv': {'w'},
      'w': {'vv'},
      'ii': {'ü', 'll'},
    },
  );
}

/// Génère les variantes plausibles d'une string bruitée par OCR.
///
/// Explosion combinatoire bornée par [maxVariants] : dès qu'on dépasse,
/// la génération est tronquée et un warning est produit côté appelant.
/// C'est intentionnel — un token très ambigu ne devrait pas être corrigé
/// automatiquement, il devrait remonter en zone à risque.
class AmbiguityResolver {
  const AmbiguityResolver({
    this.substitutions = AmbiguitySubstitutions.defaults,
    this.maxVariants = 64,
  }) : assert(maxVariants > 0);

  final AmbiguitySubstitutions substitutions;

  /// Limite dure sur le nombre de variantes générées.
  final int maxVariants;

  /// Retourne l'ensemble des variantes plausibles de [noisy], incluant
  /// [noisy] lui-même en tête.
  ///
  /// Les variantes sont générées en appliquant récursivement les
  /// substitutions unitaires puis les substitutions par digrammes,
  /// **sans jamais appliquer deux substitutions à la même position**
  /// dans la même variante (évite les cycles).
  Set<String> variantsOf(String noisy) {
    if (noisy.isEmpty) return {noisy};

    final visited = <String>{noisy};
    final queue = <String>[noisy];

    while (queue.isNotEmpty && visited.length < maxVariants) {
      final current = queue.removeAt(0);
      _expandSingles(current, visited, queue);
      if (visited.length >= maxVariants) break;
      _expandDigrams(current, visited, queue);
    }

    return visited;
  }

  void _expandSingles(
    String current,
    Set<String> visited,
    List<String> queue,
  ) {
    for (var i = 0; i < current.length; i++) {
      final ch = current[i];
      final subs = substitutions.singles[ch];
      if (subs == null) continue;
      for (final replacement in subs) {
        final variant =
            current.substring(0, i) + replacement + current.substring(i + 1);
        if (visited.add(variant)) {
          queue.add(variant);
          if (visited.length >= maxVariants) return;
        }
      }
    }
  }

  void _expandDigrams(
    String current,
    Set<String> visited,
    List<String> queue,
  ) {
    for (var i = 0; i < current.length - 1; i++) {
      final digram = current.substring(i, i + 2);
      final subs = substitutions.digrams[digram];
      if (subs == null) continue;
      for (final replacement in subs) {
        final variant =
            current.substring(0, i) + replacement + current.substring(i + 2);
        if (visited.add(variant)) {
          queue.add(variant);
          if (visited.length >= maxVariants) return;
        }
      }
    }
  }

  /// Renvoie le diff caractère par caractère entre [original] et
  /// [candidate], utile pour tracer une correction (audit).
  ///
  /// Exemple : diff("O123456", "0123456") = "O→0 @ 0".
  static List<CharDiff> diffChars(String original, String candidate) {
    final result = <CharDiff>[];
    final minLen =
        original.length < candidate.length ? original.length : candidate.length;
    for (var i = 0; i < minLen; i++) {
      if (original[i] != candidate[i]) {
        result.add(CharDiff(index: i, from: original[i], to: candidate[i]));
      }
    }
    return result;
  }
}

@immutable
class CharDiff {
  const CharDiff({required this.index, required this.from, required this.to});
  final int index;
  final String from;
  final String to;

  @override
  String toString() => '$from→$to @$index';
}
