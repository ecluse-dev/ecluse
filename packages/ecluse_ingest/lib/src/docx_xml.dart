/// Micro-extracteur de texte pour `word/document.xml` (format OOXML des
/// fichiers `.docx`).
///
/// Volontairement étroit plutôt que générique : l'OOXML produit par Word ou
/// LibreOffice est du XML machine-généré, bien formé, avec un tout petit
/// sous-ensemble de balises pertinentes pour du texte brut. Un scanner
/// ciblé sur ce sous-ensemble évite une dépendance XML générique tout en
/// restant fiable sur le cas réel.
///
/// Balises traitées :
/// - `<w:t>...</w:t>` : le texte d'une occurrence (« run »), seul contenu
///   copié tel quel (entités XML décodées).
/// - `<w:tab/>` : tabulation -> `\t`.
/// - `<w:br/>` / `<w:cr/>` : saut de ligne -> `\n`.
/// - `</w:p>` : fin de paragraphe -> `\n`.
///
/// - Tableaux (P2-65) : `</w:tc>` -> tabulation entre cellules, `</w:tr>` -> `\n` ;
///   dans une cellule, paragraphes, tabulations et sauts de ligne deviennent des
///   espaces ; `<w:gridSpan w:val="N"/>` ajoute N-1 champs vides pour garder le
///   même nombre de colonnes ; un tableau imbriqué reste dans la cellule parente.
///
/// Tout le reste (mise en forme `w:pPr`/`w:rPr`, styles) est ignoré : ces
/// balises n'entourent jamais de texte hors `<w:t>` dans un document Word
/// standard.
library;

final RegExp _tagPattern = RegExp('<[^>]*>');
final RegExp _entityPattern =
    RegExp('&(#x[0-9A-Fa-f]+|#[0-9]+|amp|lt|gt|quot|apos);');

String extractDocxPlainText(String documentXml) {
  final buffer = StringBuffer();
  // Contenu de la cellule de tableau courante (P2-65) : les paragraphes, tabulations
  // et sauts de ligne d'une cellule deviennent des espaces, pour que la rangée
  // tienne sur une ligne (cellules séparées par une tabulation).
  final cellule = StringBuffer();
  var cursor = 0;
  var inTextRun = false;
  var celluleDepth = 0;
  var span = 1;
  var tabsEnAttente = 0;

  for (final match in _tagPattern.allMatches(documentXml)) {
    if (inTextRun) {
      (celluleDepth > 0 ? cellule : buffer).write(
        _decodeXmlEntities(documentXml.substring(cursor, match.start)),
      );
    }

    final tag = match.group(0)!;
    if (_isOpeningTag(tag, 'w:t')) {
      inTextRun = true;
    } else if (_isClosingTag(tag, 'w:t')) {
      inTextRun = false;
    } else if (_isStandaloneTag(tag, 'w:tab')) {
      (celluleDepth > 0 ? cellule : buffer)
          .write(celluleDepth > 0 ? ' ' : '\t');
    } else if (_isStandaloneTag(tag, 'w:br') || _isStandaloneTag(tag, 'w:cr')) {
      (celluleDepth > 0 ? cellule : buffer)
          .write(celluleDepth > 0 ? ' ' : '\n');
    } else if (_isClosingTag(tag, 'w:p')) {
      (celluleDepth > 0 ? cellule : buffer)
          .write(celluleDepth > 0 ? ' ' : '\n');
    } else if (_tagName(tag) == 'w:tc' && !tag.startsWith('</')) {
      final vide = tag.endsWith('/>');
      if (celluleDepth == 0) {
        buffer.write('\t' * tabsEnAttente);
        tabsEnAttente = 0;
        cellule.clear();
        span = 1;
      }
      if (vide) {
        if (celluleDepth == 0) tabsEnAttente = 1;
      } else {
        celluleDepth++;
      }
    } else if (celluleDepth == 1 && _isStandaloneTag(tag, 'w:gridSpan')) {
      final n =
          int.tryParse(RegExp(r'w:val="(\d+)"').firstMatch(tag)?[1] ?? '');
      if (n != null && n > 1) span = n > 64 ? 64 : n;
    } else if (_isClosingTag(tag, 'w:tc') && celluleDepth > 0) {
      if (celluleDepth == 1) {
        buffer.write(cellule.toString().replaceAll(_blancs, ' ').trim());
        tabsEnAttente = span;
      } else {
        cellule.write(' ');
      }
      celluleDepth--;
    } else if (_isClosingTag(tag, 'w:tr')) {
      if (celluleDepth > 0) {
        cellule.write(' ');
      } else {
        buffer.write('\t' * (tabsEnAttente > 0 ? tabsEnAttente - 1 : 0));
        buffer.write('\n');
        tabsEnAttente = 0;
      }
    }

    cursor = match.end;
  }

  return buffer.toString();
}

/// Blancs d'ASCII seuls (pas l'espace insécable : une cellule garde les siennes).
final RegExp _blancs = RegExp(r'[ \t\r\n]+');

bool _isOpeningTag(String tag, String name) =>
    !tag.startsWith('</') && !tag.endsWith('/>') && _tagName(tag) == name;

bool _isClosingTag(String tag, String name) =>
    tag.startsWith('</') && _tagName(tag) == name;

/// Balise vide (`<w:tab/>`, éventuellement avec attributs), jamais une
/// balise fermante.
bool _isStandaloneTag(String tag, String name) =>
    !tag.startsWith('</') && _tagName(tag) == name;

String _tagName(String tag) {
  var s = tag.startsWith('</') ? tag.substring(2) : tag.substring(1);
  if (s.endsWith('/>')) {
    s = s.substring(0, s.length - 2);
  } else if (s.endsWith('>')) {
    s = s.substring(0, s.length - 1);
  }
  final boundary = s.indexOf(RegExp(r'[\s/]'));
  return (boundary == -1 ? s : s.substring(0, boundary)).trim();
}

String _decodeXmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(_entityPattern, (match) {
    final token = match.group(1)!;
    switch (token) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
    }
    if (token.startsWith('#x') || token.startsWith('#X')) {
      return String.fromCharCode(int.parse(token.substring(2), radix: 16));
    }
    return String.fromCharCode(int.parse(token.substring(1)));
  });
}
