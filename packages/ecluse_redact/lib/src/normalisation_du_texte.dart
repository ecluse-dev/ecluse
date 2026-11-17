part of 'ecluse.dart';

/// Caractères sans largeur ou de contrôle bidirectionnel qu'un copier-coller
/// glisse dans un identifiant (U+200B espace sans chasse, U+200C/D, U+2060,
/// U+FEFF, trait d'union conditionnel, marques de direction).
final RegExp _invisibles = RegExp(
    '[\u00AD\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF'
    '\u0300-\u036F\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]');

bool _estInvisible(int c) =>
    c == 0x00AD ||
    c == 0x180E ||
    (c >= 0x200B && c <= 0x200F) ||
    (c >= 0x202A && c <= 0x202E) ||
    (c >= 0x2060 && c <= 0x2064) ||
    (c >= 0x2066 && c <= 0x2069) ||
    c == 0xFEFF ||
    _estCombinant(c);

/// Diacritique combinant (accent d'un nom écrit en forme décomposée, NFD) : retiré
/// de la vue des détecteurs, mais rattaché à la lettre qui le porte quand une
/// entité est ramenée au texte d'origine (P2-32).
bool _estCombinant(int c) =>
    (c >= 0x0300 && c <= 0x036F) ||
    (c >= 0x1DC0 && c <= 0x1DFF) ||
    (c >= 0x20D0 && c <= 0x20FF) ||
    (c >= 0xFE20 && c <= 0xFE2F);

/// Espaces Unicode autres que U+0020 et U+00A0 (déjà acceptés par les
/// détecteurs).
final RegExp _espacesUnicode =
    RegExp('[\u1680\u2000-\u200A\u202F\u205F\u3000]');

/// Tirets typographiques que le traitement de texte substitue au trait d'union.
final RegExp _tiretsUnicode = RegExp('[\u2010-\u2013\u2212\uFE63\uFF0D]');

/// Formes pleine chasse (U+FF01 à U+FF5E), chiffres arabes orientaux, barres de
/// fraction et de division : équivalents ASCII d'un chiffre, d'une lettre ou d'un
/// signe d'identifiant.
final RegExp _autresFormes =
    RegExp('[\\uFF01-\\uFF5E\\u0660-\\u0669\\u06F0-\\u06F9\\u2044\\u2215]');

/// Équivalent ASCII de [c] (même longueur : une unité UTF-16 pour une unité).
int _versAscii(int c) {
  if (c >= 0xFF01 && c <= 0xFF5E) return c - 0xFEE0;
  if (c >= 0x0660 && c <= 0x0669) return 0x30 + (c - 0x0660);
  if (c >= 0x06F0 && c <= 0x06F9) return 0x30 + (c - 0x06F0);
  if (c == 0x2044 || c == 0x2215) return 0x2F; // '/'
  return c;
}

/// Texte sur lequel tournent les détecteurs (P2-29) : espaces Unicode ramenés à
/// U+0020 et tirets typographiques à `-` (même longueur), caractères invisibles
/// retirés. Renvoie aussi, si des caractères ont été retirés, la position
/// d'origine de chaque caractère conservé. Sans caractère concerné, le texte
/// d'origine lui-même (`identical`) : la détection est alors celle d'avant.
(String, List<int>?) _vueDeDetection(String text) {
  var vue = text;
  if (_espacesUnicode.hasMatch(vue)) {
    vue = vue.replaceAll(_espacesUnicode, ' ');
  }
  if (_tiretsUnicode.hasMatch(vue)) {
    vue = vue.replaceAll(_tiretsUnicode, '-');
  }
  if (_autresFormes.hasMatch(vue)) {
    vue = String.fromCharCodes([for (final c in vue.codeUnits) _versAscii(c)]);
  }
  final coupures = _coupuresDeLigne.allMatches(vue).toList();
  // Fins de ligne à l'intérieur d'un nom d'établissement ou de commune
  // (P2-173) : une espace à la place, dans la vue seulement.
  final nomsCoupes = coupuresDeNom(vue);
  final cles = _cleNommee.allMatches(vue).toList();
  final decorations = _decorations.allMatches(vue).toList();
  final balises = vue.contains('<') || vue.contains('&nbsp;')
      ? _balisesStructure.allMatches(vue).toList()
      : <RegExpMatch>[];
  if (coupures.isEmpty &&
      nomsCoupes.isEmpty &&
      cles.isEmpty &&
      decorations.isEmpty &&
      balises.isEmpty &&
      !_invisibles.hasMatch(vue)) {
    return (vue, null);
  }
  // Les caractères d'une coupure sont retirés comme les invisibles, sauf un
  // espace conservé quand la coupure suit un chiffre.
  final retires = <int>{};
  final unites = vue.codeUnits.toList();
  for (final m in coupures) {
    // Après un séparateur (`12-` / `34`), la coupure disparaît ; après un
    // chiffre, elle devient une espace.
    // Une majuscule de groupe (P2-152) compte comme un chiffre.
    final avant = vue.codeUnitAt(m.start - 1);
    final apresChiffre =
        (avant >= 0x30 && avant <= 0x39) || (avant >= 0x41 && avant <= 0x5A);
    var debut = m.start;
    if (apresChiffre) {
      unites[m.start] = 0x20;
      debut++;
    }
    for (var i = debut; i < m.end; i++) {
      retires.add(i);
    }
  }
  // Nom coupé (P2-173) : la fin de ligne et ses blancs deviennent une seule
  // espace. Une coupure d'identifiant au même endroit prime (les deux listes
  // sont dans l'ordre du texte : un seul parcours).
  var k = 0;
  for (final (debut, fin) in nomsCoupes) {
    while (k < coupures.length && coupures[k].end <= debut) {
      k++;
    }
    if (k < coupures.length && coupures[k].start < fin) continue;
    unites[debut] = 0x20;
    for (var i = debut + 1; i < fin; i++) {
      retires.add(i);
    }
  }
  // « 2550814168025 clé 38 » (P2-42) : le mot et ses marques disparaissent,
  // une espace subsiste entre le numéro et la clé.
  for (final m in cles) {
    unites[m.start] = 0x20;
    for (var i = m.start + 1; i < m.end; i++) {
      retires.add(i);
    }
  }
  // Marques de gras, d'italique et de code (P2-51) : retirées de la vue.
  for (final m in decorations) {
    for (var i = m.start; i < m.end; i++) {
      retires.add(i);
    }
  }
  // Balises de tableau et de bloc HTML (P2-63) : retirées, un séparateur subsiste.
  // Entre deux cellules : U+001F (séparateur d'unités), lu comme `:` par les
  // étiquettes et comme séparateur de colonnes par le CSV ; U+001E entre deux
  // cellules d'en-tête (`<th>`), séparateur de colonnes seulement, pour qu'un
  // en-tête « Nom, Prénom, Service » ne se lise jamais « Prénom : Service ».
  // Saut de ligne entre deux blocs, espace pour `&nbsp;`. Des balises de bloc
  // consécutives ne donnent qu'un saut de ligne.
  var finPrecedente = -1;
  var precedenteLigne = false;
  for (final m in balises) {
    final balise = m.group(0)!.toLowerCase();
    int separateur;
    if (balise == '&nbsp;') {
      separateur = 0x20;
    } else if (m.group(1) != null) {
      separateur = _finitParDeuxPoints(vue, m.start)
          ? 0x20
          : (balise == '</th>' && m.group(1) == 'th' ? 0x1E : 0x1F);
    } else if (balise.startsWith('</t') && balise.length == 5) {
      separateur = 0x20; // dernière cellule d'une ligne
    } else if (RegExp(r'^<t[dh][\s>]').hasMatch(balise)) {
      for (var i = m.start; i < m.end; i++) {
        retires.add(i);
      }
      continue; // ouverture de cellule : disparaît
    } else {
      separateur = 0x0A; // bloc, ligne de tableau, saut de ligne
    }
    final contigu = finPrecedente == m.start;
    if (separateur == 0x0A &&
        ((precedenteLigne && contigu) ||
            _saut(vue, m.start - 1, -1) ||
            _saut(vue, m.end, 1))) {
      for (var i = m.start; i < m.end; i++) {
        retires.add(i);
      }
    } else {
      unites[m.start] = separateur;
      for (var i = m.start + 1; i < m.end; i++) {
        retires.add(i);
      }
    }
    finPrecedente = m.end;
    precedenteLigne = separateur == 0x0A;
  }
  final sb = StringBuffer();
  final positions = <int>[];
  for (var i = 0; i < unites.length; i++) {
    final c = unites[i];
    if (retires.contains(i) || _estInvisible(c)) continue;
    sb.writeCharCode(c);
    positions.add(i);
  }
  return (sb.toString(), positions);
}

/// Balises HTML de structure (P2-63) : cellules et lignes de tableau, blocs,
/// listes, titres, sauts de ligne, et `&nbsp;`. Seules les balises sans attribut,
/// ou dont les attributs sont de pure mise en forme (`class`, `style`, `colspan`,
/// `width`…), sont concernées : un attribut libre (`title`, `href`, `alt`) peut
/// porter une donnée personnelle et rester visible aux détecteurs. Le premier
/// groupe capture la cellule qui suit une fin de cellule (`</td>` puis `<td>`).
final RegExp _balisesStructure = RegExp(
  r'</t[dh]>(?=[ \t\r\n]*<(t[dh])[\s>])'
  r'|</?(?:t[dh]|tr|table|thead|tbody|tfoot|p|div|li|ul|ol|h[1-6])'
  r'(?:\s+(?:class|style|colspan|rowspan|width|height|align|valign|bgcolor|id|'
  r'border)\s*=\s*(?:"[^"<>]*"|\u0027[^\u0027<>]*\u0027|[^\s<>"\u0027]*))*\s*/?>'
  r'|<br\s*/?>'
  r'|&nbsp;',
  caseSensitive: false,
);

/// Vrai si, en partant de [i] et en allant dans le sens [pas], le premier
/// caractère qui n'est ni une espace ni une tabulation est un saut de ligne réel :
/// une balise de bloc voisine d'un vrai saut de ligne n'en ajoute pas un second
/// (une ligne vide mettrait fin à un tableau).
bool _saut(String vue, int i, int pas) {
  while (i >= 0 && i < vue.length && (vue[i] == ' ' || vue[i] == '\t')) {
    i += pas;
  }
  return i >= 0 && i < vue.length && (vue[i] == '\n' || vue[i] == '\r');
}

bool _finitParDeuxPoints(String vue, int fin) {
  var i = fin - 1;
  while (i >= 0 && (vue[i] == ' ' || vue[i] == '\t')) {
    i--;
  }
  return i >= 0 && vue[i] == ':';
}

/// Fin de ligne entre deux groupes d'un identifiant (P2-38) : après un chiffre
/// ou l'un de `/ . -`, avant un chiffre, avec les blancs de part et d'autre.
/// Volontairement étroite : un saut de ligne ordinaire (texte, nom, adresse)
/// n'est pas touché, donc aucun span de texte ne traverse une ligne.
///
/// P2-152 : la coupure est aussi admise après **une** majuscule précédée d'un
/// chiffre (lettre de compte d'un IBAN « 461K⏎4056 », « 2A⏎073 » d'un NIR
/// corse), même tolérance que `DigitCompaction`, et les blancs autour de la
/// fin de ligne comprennent les espaces insécables et typographiques (un
/// export bureautique coupe « 7460⏎\u00A08432 »). Ce qui suit doit être un
/// chiffre, ou (P2-158) **une** majuscule suivie d'un chiffre : un groupe de
/// compte d'IBAN peut commencer par une lettre (« …0270⏎D932… »). Les
/// contre-exemples (« Salle 4⏎A2 fermée », « Vol 12⏎B7 porte ») ne sont pas
/// détectés après neutralisation : la validation de l'identifiant (clé,
/// forme) reste le garde-fou contre la fusion de deux lignes sans rapport.
final RegExp _coupuresDeLigne = RegExp(r'(?<=[0-9/.\-]|[0-9][A-Z])'
    '[$_blancsDeLigne]*\\r?\\n[$_blancsDeLigne]*'
    r'(?=[0-9]|[A-Z][0-9])');

/// Blancs horizontaux admis autour d'une fin de ligne d'identifiant : ceux de
/// `DigitCompaction` (jamais le saut de ligne lui-même).
const String _blancsDeLigne = r' \t\u00A0\u2000-\u200A\u202F\u3000';

/// Marques de mise en forme Markdown ou HTML autour d'une étiquette (P2-51) :
/// `**Nom :** Quenelle`, `*Nom* : Quenelle`, `` `Nom` : …``, `<b>Nom :</b>`.
/// Une suite de marques (`*`, `_`, `` ` ``, p. ex. `**` ou `__`) d'ouverture n'est
/// retirée que devant un mot et hors d'un mot ; une suite de fermeture seulement
/// après un mot ou une ponctuation et hors d'un mot. Un soulignement ou une étoile
/// **à l'intérieur** d'un mot (`jean_dupont`, `[NOM_1]`) et une opération
/// (`3 * 4`) ne sont jamais touchés. Classe de caractères plutôt que des
/// alternatives `\*\*|\*` répétées : ces dernières se recouvrent et donnaient un
/// retour arrière exponentiel (50 000 étoiles : 51 s).
final RegExp _decorations = RegExp(r'(?<![\wÀ-ÿ*_`])[*_`]+(?=[\wÀ-ÿ])'
    r'|(?<=[\wÀ-ÿ.,;:!?)\]])[*_`]+(?![\wÀ-ÿ*_`])'
    r'|</?(?:b|i|u|em|strong)>');

/// Clé de contrôle nommée à part (P2-42) : après un chiffre, « clé », « cle » ou
/// « clef » (avec `(` et `:` facultatifs) puis deux chiffres. Neutralisée dans la
/// vue de détection seulement : le NIR n'est reconnu que si la clé est juste.
final RegExp _cleNommee = RegExp(
    r'(?<=[0-9])[ \t]*(?:\([ \t]*)?(?:[Cc]l[ée]f?|CL[ÉE]F?)[ \t]*(?::[ \t]*)?'
    r'(?=[0-9]{2}(?![0-9]))');
