/// Micro-extracteur de texte pour `content.xml` (format OpenDocument des
/// fichiers `.odt`).
///
/// Volontairement étroit plutôt que générique, comme `docx_xml.dart` :
/// contrairement à l'OOXML, où le texte est toujours dans une balise
/// feuille (`<w:t>`), l'OpenDocument place le texte directement entre les
/// balises de bloc (`<text:p>du texte <text:span>stylé</text:span> encore
/// du texte</text:p>`), sans balise de run intermédiaire. L'extraction
/// utilise donc un compteur de profondeur plutôt qu'une bascule sur une
/// seule balise : tout texte rencontré alors qu'on est descendu dans un
/// `<text:p>`, `<text:h>` ou `<text:list-item>` est capturé, quelles que
/// soient les balises de mise en forme (`text:span`, `text:a`, …)
/// traversées entre-temps.
///
/// Balises traitées :
/// - `<text:p>`, `<text:h>`, `<text:list-item>` : zone de capture de texte
///   (profondeur += 1 à l'ouverture, -= 1 à la fermeture).
/// - `</text:p>` / `</text:h>` : fin de paragraphe/titre -> `\n`.
///   `</text:list-item>` ne réémet pas de `\n` : le `<text:p>` qu'il
///   contient l'a déjà fait, l'émettre aussi doublerait la ligne vide.
/// - `<text:tab/>` : tabulation -> `\t`.
/// - `<text:line-break/>` : saut de ligne -> `\n`.
///
/// - Tableaux (P2-65) : `</table:table-cell>` -> tabulation entre cellules,
///   `</table:table-row>` -> `\n` ; dans une cellule, paragraphes, tabulations et
///   sauts de ligne deviennent des espaces ; une cellule couverte
///   (`table:covered-table-cell`) ou répétée (`table:number-columns-repeated`) garde
///   le même nombre de champs ; un tableau imbriqué reste dans la cellule parente.
///
/// Tout le reste (styles `<style:*>`, métadonnées `<office:meta>`,
/// balises de mise en forme inline) est ignoré : hors d'une zone de
/// capture, aucun texte n'est copié.
library;

final RegExp _tagPattern = RegExp('<[^<>]*>');
final RegExp _entityPattern =
    RegExp('&(#x[0-9A-Fa-f]+|#[0-9]+|amp|lt|gt|quot|apos);');

const _captureTags = {'text:p', 'text:h', 'text:list-item'};
const _paragraphEndTags = {'text:p', 'text:h'};

String extractOdtPlainText(String contentXml) {
  final buffer = StringBuffer();
  // Contenu de la cellule de tableau courante (P2-65), comme pour le docx : la
  // rangée tient sur une ligne, cellules séparées par une tabulation.
  final cellule = StringBuffer();
  var cursor = 0;
  var captureDepth = 0;
  var celluleDepth = 0;
  var repetition = 1;
  var tabsEnAttente = 0;

  for (final match in _tagPattern.allMatches(contentXml)) {
    if (captureDepth > 0) {
      (celluleDepth > 0 ? cellule : buffer).write(
        _decodeXmlEntities(contentXml.substring(cursor, match.start)),
      );
    }

    final tag = match.group(0)!;
    final name = _tagName(tag);
    final saut = celluleDepth > 0 ? ' ' : '\n';
    if (_captureTags.contains(name)) {
      if (_isOpeningTag(tag)) {
        captureDepth++;
      } else if (_isClosingTag(tag)) {
        if (captureDepth > 0) captureDepth--;
        if (_paragraphEndTags.contains(name)) {
          (celluleDepth > 0 ? cellule : buffer).write(saut);
        }
      } else if (_paragraphEndTags.contains(name)) {
        // Paragraphe/titre auto-fermant (`<text:p/>`) : cas réel d'un
        // paragraphe vide généré par LibreOffice — ouverture et fermeture
        // atomiques, la ligne vide compte comme séparateur au même titre
        // qu'un `<text:p></text:p>`.
        (celluleDepth > 0 ? cellule : buffer).write(saut);
      }
    } else if (name == 'table:table-cell' ||
        name == 'table:covered-table-cell') {
      if (!tag.startsWith('</')) {
        final vide = tag.endsWith('/>');
        if (celluleDepth == 0) {
          buffer.write('\t' * tabsEnAttente);
          tabsEnAttente = 0;
          cellule.clear();
          final n = int.tryParse(
              RegExp(r'table:number-columns-repeated="(\d+)"')
                      .firstMatch(tag)?[1] ??
                  '');
          repetition = n != null && n > 1 ? (n > 64 ? 64 : n) : 1;
        }
        if (vide || name == 'table:covered-table-cell' && vide) {
          if (celluleDepth == 0) tabsEnAttente = repetition;
        } else {
          celluleDepth++;
        }
      } else if (celluleDepth > 0) {
        if (celluleDepth == 1) {
          buffer.write(cellule.toString().replaceAll(_blancs, ' ').trim());
          tabsEnAttente = repetition;
        } else {
          cellule.write(' ');
        }
        celluleDepth--;
      }
    } else if (name == 'table:table-row' && tag.startsWith('</')) {
      if (celluleDepth > 0) {
        cellule.write(' ');
      } else {
        buffer.write('\t' * (tabsEnAttente > 0 ? tabsEnAttente - 1 : 0));
        buffer.write('\n');
        tabsEnAttente = 0;
      }
    } else if (captureDepth > 0) {
      if (_isStandaloneTag(tag, 'text:tab')) {
        (celluleDepth > 0 ? cellule : buffer)
            .write(celluleDepth > 0 ? ' ' : '\t');
      } else if (_isStandaloneTag(tag, 'text:line-break')) {
        (celluleDepth > 0 ? cellule : buffer).write(saut);
      }
    }

    cursor = match.end;
  }

  return buffer.toString();
}

/// Blancs d'ASCII seuls (pas l'espace insécable : une cellule garde les siennes).
final RegExp _blancs = RegExp(r'[ \t\r\n]+');

bool _isOpeningTag(String tag) => !tag.startsWith('</') && !tag.endsWith('/>');

bool _isClosingTag(String tag) => tag.startsWith('</');

/// Balise vide (`<text:tab/>`, éventuellement avec attributs), jamais une
/// balise fermante.
bool _isStandaloneTag(String tag, String name) =>
    !tag.startsWith('</') && tag.endsWith('/>') && _tagName(tag) == name;

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
