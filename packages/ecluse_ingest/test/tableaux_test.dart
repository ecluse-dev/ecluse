import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

/// Tableaux Word et ODT (P2-65). Les cellules étaient aplaties en un paragraphe
/// chacune : « Nom⏎Quenelle⏎Prénom⏎Zorglub », sans lien entre l'étiquette et sa
/// valeur, ni entre l'en-tête d'un tableau et ses colonnes. Les noms d'un tableau
/// restaient en clair. Maintenant : cellules d'une ligne séparées par une
/// tabulation, lignes par un saut de ligne.
String _p(String t) => '<w:p><w:r><w:t>$t</w:t></w:r></w:p>';
String _tc(String contenu, {int span = 1}) =>
    '<w:tc>${span > 1 ? '<w:tcPr><w:gridSpan w:val="$span"/></w:tcPr>' : ''}$contenu</w:tc>';
String _tr(List<String> cellules) => '<w:tr>${cellules.join()}</w:tr>';
String _docx(String corps) =>
    '<?xml version="1.0"?><w:document><w:body>$corps</w:body></w:document>';

String _op(String t) => '<text:p>$t</text:p>';
String _oc(String contenu) => '<table:table-cell>$contenu</table:table-cell>';
String _or(List<String> cellules) =>
    '<table:table-row>${cellules.join()}</table:table-row>';
String _odt(String corps) =>
    '<office:document-content><office:body><office:text>$corps'
    '</office:text></office:body></office:document-content>';

String _extraitDocx(String corps) {
  final r = ingestFile(buildStoredZip({'word/document.xml': _docx(corps)}),
      filename: 'f.docx');
  return (r as IngestedText).text;
}

String _extraitOdt(String corps) {
  final r = ingestFile(
      buildStoredZip({
        'mimetype': 'application/vnd.oasis.opendocument.text',
        'content.xml': _odt(corps),
      }),
      filename: 'f.odt');
  return (r as IngestedText).text;
}

void main() {
  group('extraction docx', () {
    test('étiquette et valeur : une ligne par rangée, cellules par tabulation',
        () {
      final t = _extraitDocx('<w:tbl>'
          '${_tr([_tc(_p('Nom')), _tc(_p('Quenelle'))])}'
          '${_tr([_tc(_p('Prénom')), _tc(_p('Zorglub'))])}'
          '</w:tbl>');
      expect(t, 'Nom\tQuenelle\nPrénom\tZorglub\n');
    });

    test('texte avant et après le tableau', () {
      final t = _extraitDocx('${_p('Avant')}<w:tbl>'
          '${_tr([_tc(_p('A')), _tc(_p('B'))])}</w:tbl>${_p('Après')}');
      expect(t, 'Avant\nA\tB\nAprès\n');
    });

    test('cellule vide, plusieurs paragraphes, tabulation et saut de ligne',
        () {
      final t = _extraitDocx('<w:tbl>${_tr([
            _tc(_p('Un') + _p('Deux')),
            _tc('<w:p/>'),
            _tc('<w:p><w:r><w:t>a</w:t></w:r><w:r><w:tab/></w:r>'
                '<w:r><w:t>b</w:t></w:r><w:r><w:br/></w:r>'
                '<w:r><w:t>c</w:t></w:r></w:p>'),
          ])}</w:tbl>');
      expect(t, 'Un Deux\t\ta b c\n');
    });

    test('cellule fusionnée : les colonnes sautées restent des champs vides',
        () {
      final t = _extraitDocx('<w:tbl>'
          '${_tr([_tc(_p('Titre'), span: 3)])}'
          '${_tr([_tc(_p('A')), _tc(_p('B')), _tc(_p('C'))])}'
          '</w:tbl>');
      expect(t, 'Titre\t\t\nA\tB\tC\n');
    });

    test('tableau imbriqué : son contenu reste dans la cellule parente', () {
      final interieur = '<w:tbl>${_tr([_tc(_p('x')), _tc(_p('y'))])}</w:tbl>';
      final t = _extraitDocx('<w:tbl>'
          '${_tr([_tc(_p('Nom') + interieur), _tc(_p('Quenelle'))])}'
          '</w:tbl>');
      expect(t.split('\n').where((l) => l.isNotEmpty).length, 1);
      expect(t, startsWith('Nom'));
      expect(t, endsWith('\tQuenelle\n'));
    });

    test('hors tableau : inchangé', () {
      expect(_extraitDocx(_p('Un') + _p('Deux')), 'Un\nDeux\n');
    });
  });

  group('extraction odt', () {
    test('étiquette et valeur', () {
      final t = _extraitOdt('<table:table>'
          '${_or([_oc(_op('Nom')), _oc(_op('Quenelle'))])}'
          '${_or([_oc(_op('Prénom')), _oc(_op('Zorglub'))])}'
          '</table:table>');
      expect(t, 'Nom\tQuenelle\nPrénom\tZorglub\n');
    });

    test('cellule fusionnée (couverte) et cellule vide', () {
      final t = _extraitOdt('<table:table>${_or([
            '<table:table-cell table:number-columns-spanned="2">'
                '${_op('Titre')}</table:table-cell>',
            '<table:covered-table-cell/>',
            _oc('<text:p/>'),
          ])}${_or([
            _oc(_op('A')),
            _oc(_op('B')),
            _oc(_op('C')),
          ])}</table:table>');
      expect(t, 'Titre\t\t\nA\tB\tC\n');
    });

    test('hors tableau : inchangé', () {
      expect(_extraitOdt(_op('Un') + _op('Deux')), 'Un\nDeux\n');
    });
  });

  group('masquage de bout en bout', () {
    Future<String> masque(String texte) async {
      final r = await Ecluse.redact(texte);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      return r.maskedText;
    }

    final etiquettes = [
      ['Nom', 'Quenelle'],
      ['Prénom', 'Zorglub'],
      ['Date de naissance', '12/03/1950'],
      ['Téléphone', '06 12 34 56 78'],
    ];

    test('docx : tableau étiquette / valeur', () async {
      final m = await masque(_extraitDocx('<w:tbl>'
          '${etiquettes.map((e) => _tr([_tc(_p(e[0])), _tc(_p(e[1]))])).join()}'
          '</w:tbl>'));
      for (final v in ['Quenelle', 'Zorglub', '12/03/1950', '06 12']) {
        expect(m, isNot(contains(v)), reason: m);
      }
    });

    test('odt : tableau étiquette / valeur', () async {
      final m = await masque(_extraitOdt('<table:table>'
          '${etiquettes.map((e) => _or([
                    _oc(_op(e[0])),
                    _oc(_op(e[1]))
                  ])).join()}'
          '</table:table>'));
      for (final v in ['Quenelle', 'Zorglub', '12/03/1950', '06 12']) {
        expect(m, isNot(contains(v)), reason: m);
      }
    });

    test('docx : tableau à en-tête (colonnes Nom, Prénom)', () async {
      final m = await masque(_extraitDocx('<w:tbl>'
          '${_tr([_tc(_p('Nom')), _tc(_p('Prénom')), _tc(_p('Service'))])}'
          '${_tr([_tc(_p('Quenelle')), _tc(_p('Zorglub')), _tc(_p('Cardio'))])}'
          '${_tr([_tc(_p('Dupont')), _tc(_p('Hector')), _tc(_p('Pneumo'))])}'
          '</w:tbl>'));
      for (final v in ['Quenelle', 'Zorglub', 'Dupont', 'Hector']) {
        expect(m, isNot(contains(v)), reason: m);
      }
      expect(m, contains('Cardio'));
      expect(m, contains('Service'));
    });

    test('odt : tableau à en-tête', () async {
      final m = await masque(_extraitOdt('<table:table>'
          '${_or([_oc(_op('Nom')), _oc(_op('Prénom'))])}'
          '${_or([_oc(_op('Quenelle')), _oc(_op('Zorglub'))])}'
          '</table:table>'));
      expect(m, isNot(contains('Quenelle')), reason: m);
      expect(m, isNot(contains('Zorglub')), reason: m);
    });

    test('tableau sans colonne de personne : rien n\'est masqué à tort',
        () async {
      final m = await masque(_extraitDocx('<w:tbl>'
          '${_tr([_tc(_p('Médicament')), _tc(_p('Dose'))])}'
          '${_tr([_tc(_p('Aspirine')), _tc(_p('100 mg'))])}'
          '</w:tbl>'));
      expect(m, contains('Aspirine'));
    });

    test('étiquette « Nom » seule dans un tableau : pas de nom inventé',
        () async {
      final m = await masque(_extraitDocx('<w:tbl>'
          '${_tr([_tc(_p('Nom')), _tc(_p('Aspirine'))])}</w:tbl>'));
      expect(m, contains('Aspirine'));
    });
  });
}
