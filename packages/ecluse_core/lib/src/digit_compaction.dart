/// Neutralise, avant détection, les espaces **internes à une séquence de
/// chiffres** (RIB affiché en tableau, NIR recopié à la main, export PDF
/// aux espacements irréguliers…), tout en gardant la correspondance exacte
/// vers les positions du texte d'origine.
///
/// Les motifs de `NirDetector` et `IbanFrDetector` tolèrent déjà **un**
/// séparateur simple (espace, point, tiret) entre chaque groupe — c'est ce
/// qui couvre le format usuel `1 85 05 78 006 084 91`. Mais un document
/// réel peut aussi contenir des espaces multiples, un espace insécable
/// (`\u00A0`, fréquent dans les exports bureautiques) ou une tabulation,
/// qui font échouer ce motif à séparateur unique. `DigitCompaction` retire
/// entièrement ces espaces quand ils sont encadrés par un chiffre avant et
/// un chiffre après, ramenant le cas au format « collé » déjà couvert par
/// les motifs existants.
///
/// Un espace n'est retiré que si, en le traversant, on retrouve un chiffre
/// à au plus **une lettre majuscule** de distance de chaque côté — ce qui
/// couvre la lettre de compte d'un IBAN ou le `2A`/`2B` corse d'un NIR sans
/// pour autant neutraliser un espace de mot ordinaire précédé d'un mot en
/// majuscules (ex. « IBAN 1234 » ne doit jamais devenir « IBAN1234 »,
/// sans quoi le motif du détecteur ne reconnaît plus son propre début).
final class DigitCompaction {
  const DigitCompaction._(this.compact, this._originalIndex);

  /// Texte compacté, à utiliser pour la détection (`RegExp.allMatches`).
  final String compact;

  /// `_originalIndex[i]` est la position, dans le texte d'origine, du
  /// caractère `compact[i]`.
  final List<int> _originalIndex;

  static const _whitespace = {' ', '\t', '\u00A0', '\u202F'};

  factory DigitCompaction(String original) {
    final compactUnits = <int>[];
    final originalIndex = <int>[];

    var i = 0;
    while (i < original.length) {
      final char = original[i];
      if (!_whitespace.contains(char)) {
        compactUnits.add(original.codeUnitAt(i));
        originalIndex.add(i);
        i++;
        continue;
      }

      var runEnd = i + 1;
      while (
          runEnd < original.length && _whitespace.contains(original[runEnd])) {
        runEnd++;
      }

      final precededByDigit = _digitBehind(compactUnits);
      final followedByDigit = _digitAhead(original, runEnd);

      if (precededByDigit && followedByDigit) {
        // Espace(s) interne(s) à une séquence de chiffres : neutralisés,
        // rien n'est ajouté au texte compacté.
        i = runEnd;
        continue;
      }

      // Séparateur de mots ordinaire : conservé tel quel.
      for (var j = i; j < runEnd; j++) {
        compactUnits.add(original.codeUnitAt(j));
        originalIndex.add(j);
      }
      i = runEnd;
    }

    return DigitCompaction._(String.fromCharCodes(compactUnits), originalIndex);
  }

  /// Y a-t-il un chiffre en fin de [units], quitte à traverser une unique
  /// lettre majuscule (`...9W` : le `9` est trouvé derrière le `W`) ?
  static bool _digitBehind(List<int> units) {
    if (units.isEmpty) return false;
    final last = units.last;
    if (_isDigitUnit(last)) return true;
    if (!_isUpperUnit(last) || units.length < 2) return false;
    return _isDigitUnit(units[units.length - 2]);
  }

  /// Y a-t-il un chiffre à partir de [index] dans [text], quitte à
  /// traverser une unique lettre majuscule (`W789...` : le `7` est trouvé
  /// derrière le `W`) ?
  static bool _digitAhead(String text, int index) {
    if (index >= text.length) return false;
    final first = text.codeUnitAt(index);
    if (_isDigitUnit(first)) return true;
    if (!_isUpperUnit(first) || index + 1 >= text.length) return false;
    return _isDigitUnit(text.codeUnitAt(index + 1));
  }

  static bool _isDigitUnit(int unit) => unit >= 0x30 && unit <= 0x39;

  static bool _isUpperUnit(int unit) => unit >= 0x41 && unit <= 0x5A;

  /// Position, dans le texte d'origine, du début d'un match `[compactStart,
  /// compactEnd)` obtenu sur [compact].
  int originalStart(int compactStart) => _originalIndex[compactStart];

  /// Position, dans le texte d'origine, de la fin (exclue) d'un match
  /// `[compactStart, compactEnd)` obtenu sur [compact]. N'inclut jamais les
  /// espaces neutralisés qui suivraient le dernier caractère du match.
  int originalEnd(int compactEnd) => _originalIndex[compactEnd - 1] + 1;
}
