import 'package:ecluse_ingest/src/odt_xml.dart';
import 'package:test/test.dart';

void main() {
  group('extractOdtPlainText', () {
    test('extrait le texte d\'un paragraphe simple', () {
      const xml = '<text:p>Bonjour le monde</text:p>';
      expect(extractOdtPlainText(xml), 'Bonjour le monde\n');
    });

    test('deux paragraphes -> une nouvelle ligne entre eux', () {
      const xml = '<text:p>Ligne un</text:p><text:p>Ligne deux</text:p>';
      expect(extractOdtPlainText(xml), 'Ligne un\nLigne deux\n');
    });

    test('texte réparti entre des balises de mise en forme inline', () {
      const xml = '<text:p>Bonjour <text:span text:style-name="T1">'
          'le monde</text:span>, ravi.</text:p>';
      expect(extractOdtPlainText(xml), 'Bonjour le monde, ravi.\n');
    });

    test('<text:h> est traité comme un paragraphe (titre)', () {
      const xml = '<text:h text:outline-level="1">Titre</text:h>'
          '<text:p>Corps du texte.</text:p>';
      expect(extractOdtPlainText(xml), 'Titre\nCorps du texte.\n');
    });

    test(
        '<text:list-item> contenant un <text:p> ne double pas la ligne '
        'vide', () {
      const xml = '<text:list><text:list-item><text:p>Item un</text:p>'
          '</text:list-item><text:list-item><text:p>Item deux</text:p>'
          '</text:list-item></text:list>';
      expect(extractOdtPlainText(xml), 'Item un\nItem deux\n');
    });

    test(
        '<text:tab/> devient une tabulation, <text:line-break/> un saut '
        'de ligne', () {
      const xml = '<text:p>a<text:tab/>b<text:line-break/>c</text:p>';
      expect(extractOdtPlainText(xml), 'a\tb\nc\n');
    });

    test('décode les entités XML nommées et numériques', () {
      const xml = '<text:p>Dupont &amp; Fils, ren&#233; caf&#x00e9;'
          '</text:p>';
      expect(extractOdtPlainText(xml), 'Dupont & Fils, rené café\n');
    });

    test('ignore le contenu hors paragraphe (styles, métadonnées)', () {
      const xml = '<office:automatic-styles><style:style '
          'style:name="P1">ignoré</style:style></office:automatic-styles>'
          '<office:text><text:p>Texte visible</text:p></office:text>';
      expect(extractOdtPlainText(xml), 'Texte visible\n');
    });

    test(
        '<text:p/> auto-fermant (paragraphe vide) produit une ligne '
        'vide', () {
      const xml = '<text:p>Avant</text:p><text:p/><text:p>Après</text:p>';
      expect(extractOdtPlainText(xml), 'Avant\n\nAprès\n');
    });
  });
}
