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
/// Tout le reste (mise en forme `w:pPr`/`w:rPr`, tableaux, styles) est
/// ignoré : ces balises n'entourent jamais de texte hors `<w:t>` dans un
/// document Word standard.
library;

final RegExp _tagPattern = RegExp('<[^>]*>');
final RegExp _entityPattern =
    RegExp('&(#x[0-9A-Fa-f]+|#[0-9]+|amp|lt|gt|quot|apos);');

String extractDocxPlainText(String documentXml) {
  final buffer = StringBuffer();
  var cursor = 0;
  var inTextRun = false;

  for (final match in _tagPattern.allMatches(documentXml)) {
    if (inTextRun) {
      buffer.write(
        _decodeXmlEntities(documentXml.substring(cursor, match.start)),
      );
    }

    final tag = match.group(0)!;
    if (_isOpeningTag(tag, 'w:t')) {
      inTextRun = true;
    } else if (_isClosingTag(tag, 'w:t')) {
      inTextRun = false;
    } else if (_isStandaloneTag(tag, 'w:tab')) {
      buffer.write('\t');
    } else if (_isStandaloneTag(tag, 'w:br') || _isStandaloneTag(tag, 'w:cr')) {
      buffer.write('\n');
    } else if (_isClosingTag(tag, 'w:p')) {
      buffer.write('\n');
    }

    cursor = match.end;
  }

  return buffer.toString();
}

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
