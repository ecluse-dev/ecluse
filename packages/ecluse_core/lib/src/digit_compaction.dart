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
  DigitCompaction._(this.original, this.compact, this._originalIndex);

  /// Texte d'origine, tel que reçu.
  final String original;

  /// Texte compacté, à utiliser pour la détection (`RegExp.allMatches`).
  final String compact;

  /// `_originalIndex[i]` est la position, dans le texte d'origine, du
  /// caractère `compact[i]`.
  final List<int> _originalIndex;

  /// Blancs neutralisés entre deux chiffres : espace, tabulation, espace
  /// insécable, espaces typographiques U+2000 à U+200A (dont l'espace fine
  /// U+2009 des exports de traitement de texte), espace fine insécable U+202F
  /// et espace idéographique U+3000. Jamais le saut de ligne.
  static const _whitespace = {
    ' ',
    '\t',
    '\u00A0',
    '\u2000',
    '\u2001',
    '\u2002',
    '\u2003',
    '\u2004',
    '\u2005',
    '\u2006',
    '\u2007',
    '\u2008',
    '\u2009',
    '\u200A',
    '\u202F',
    '\u3000',
  };

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

    return DigitCompaction._(
        original, String.fromCharCodes(compactUnits), originalIndex);
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

  /// Candidats de [pattern] trouvés sur le texte compacté **et** sur le texte
  /// d'origine, dédoublonnés, triés, avec des positions dans le texte
  /// d'origine.
  ///
  /// Pourquoi les deux : la compaction retire tout blanc entre deux chiffres,
  /// y compris entre un identifiant et un **nombre voisin** (`NIR … 91 12
  /// ans`). Les garde-fous de bord du motif (`(?<![0-9])`, `(?![0-9])`) voient
  /// alors un seul nombre trop long et rejettent le candidat : une fuite. Le
  /// passage sur le texte d'origine retrouve ces identifiants au format
  /// courant (un séparateur simple), le passage compacté garde les
  /// espacements irréguliers (espaces multiples, NBSP, tabulation).
  ///
  /// Troisième passage (P2-174), sur le texte **régularisé** : chaque suite de
  /// blancs entre deux chiffres y devient une seule espace au lieu de
  /// disparaître. Il couvre ce que les deux autres laissaient : un espacement
  /// irrégulier **et** un nombre voisin (`NIR 1  85  05 … 91 12 ans`), mesuré
  /// à 492 identifiants non détectés sur 2 400 par le témoin
  /// `bench/generate_corpus_identifiant_suivi.py`. Ce passage ne lit rien de
  /// plus qu'un document écrit avec des espaces simples : les garde-fous de
  /// chaque détecteur (clé, forme) s'appliquent tels quels.
  ///
  /// Enfin, un candidat qui **finit au milieu d'une date en chiffres**
  /// (`… 12/03/2024` : le candidat s'arrête après `12` ou `12/03`) est écarté :
  /// ses derniers chiffres sont le début de la date, pas la fin d'un
  /// identifiant (un RPPS suivi d'une date se lisait parfois comme un NIR, un
  /// FINESS suivi d'une date comme un RPPS).
  List<CompactCandidate> candidates(RegExp pattern) {
    final found = <CompactCandidate>[];
    final seen = <(int, int)>{};
    for (final m in pattern.allMatches(compact)) {
      final start = originalStart(m.start);
      final end = originalEnd(m.end);
      if (seen.add((start, end))) {
        found.add(CompactCandidate(start, end, m.group(0)!));
      }
    }
    for (final m in pattern.allMatches(original)) {
      if (seen.add((m.start, m.end))) {
        found.add(CompactCandidate(m.start, m.end, m.group(0)!));
      }
    }
    final regularise = _regularise;
    if (regularise != null) {
      final (texte, index) = regularise;
      for (final m in pattern.allMatches(texte)) {
        final start = index[m.start];
        final end = index[m.end - 1] + 1;
        if (seen.add((start, end))) {
          found.add(CompactCandidate(start, end, m.group(0)!));
        }
      }
    }
    found.removeWhere((c) => _finitDansUneDate(c.start, c.end));
    found.sort((a, b) => a.start - b.start);
    return found;
  }

  /// Texte régularisé et position d'origine de chacun de ses caractères, ou
  /// `null` si aucun blanc entre deux chiffres n'est irrégulier (le texte
  /// régularisé serait le texte d'origine, déjà parcouru). Calculé une fois.
  late final (String, List<int>)? _regularise = _construitRegularise();

  (String, List<int>)? _construitRegularise() {
    final unites = <int>[];
    final index = <int>[];
    var irregulier = false;
    var i = 0;
    while (i < original.length) {
      if (!_whitespace.contains(original[i])) {
        unites.add(original.codeUnitAt(i));
        index.add(i);
        i++;
        continue;
      }
      var fin = i + 1;
      while (fin < original.length && _whitespace.contains(original[fin])) {
        fin++;
      }
      if (_digitBehind(unites) && _digitAhead(original, fin)) {
        // Entre deux chiffres : une seule espace ordinaire.
        if (fin - i > 1 || original.codeUnitAt(i) != 0x20) irregulier = true;
        unites.add(0x20);
        index.add(i);
      } else {
        for (var j = i; j < fin; j++) {
          unites.add(original.codeUnitAt(j));
          index.add(j);
        }
      }
      i = fin;
    }
    return irregulier ? (String.fromCharCodes(unites), index) : null;
  }

  /// Date en chiffres à année sur quatre chiffres : `12/03/2024`,
  /// `1.3.1998`, `12-03-2024` (même séparateur des deux côtés).
  static final RegExp _dateEnChiffres =
      RegExp(r'[0-3]?[0-9]([/.\-])[01]?[0-9]\1(?:19|20)[0-9]{2}(?![0-9])');

  /// Le candidat `[start, end)` s'arrête-t-il au milieu d'une date en
  /// chiffres qui commence à son dernier groupe (le dernier morceau séparé
  /// du reste par un blanc) ?
  bool _finitDansUneDate(int start, int end) {
    var g = end;
    while (g > start && !_whitespace.contains(original[g - 1])) {
      g--;
    }
    if (g == start) return false; // d'un seul tenant : pas de groupe à part
    final date = _dateEnChiffres.matchAsPrefix(original, g);
    return date != null && date.end > end;
  }

  /// Position, dans le texte d'origine, du début d'un match `[compactStart,
  /// compactEnd)` obtenu sur [compact].
  int originalStart(int compactStart) => _originalIndex[compactStart];

  /// Position, dans le texte d'origine, de la fin (exclue) d'un match
  /// `[compactStart, compactEnd)` obtenu sur [compact]. N'inclut jamais les
  /// espaces neutralisés qui suivraient le dernier caractère du match.
  int originalEnd(int compactEnd) => _originalIndex[compactEnd - 1] + 1;
}

/// Un candidat d'un motif : positions dans le texte d'origine et texte
/// apparié (compacté ou d'origine selon le passage qui l'a trouvé).
final class CompactCandidate {
  const CompactCandidate(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;
}
