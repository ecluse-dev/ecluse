import 'package:ecluse_ingest/src/docx_xml.dart';
import 'package:test/test.dart';

void main() {
  group('extractDocxPlainText', () {
    test('extrait le texte de plusieurs runs dans un paragraphe', () {
      const xml = '<w:p><w:r><w:t>Bonjour </w:t></w:r>'
          '<w:r><w:t>le monde</w:t></w:r></w:p>';
      expect(extractDocxPlainText(xml), 'Bonjour le monde\n');
    });

    test('deux paragraphes -> une nouvelle ligne entre eux', () {
      const xml = '<w:p><w:r><w:t>Ligne un</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>Ligne deux</w:t></w:r></w:p>';
      expect(extractDocxPlainText(xml), 'Ligne un\nLigne deux\n');
    });

    test('<w:tab/> devient une tabulation, <w:br/> un saut de ligne', () {
      const xml = '<w:p><w:r><w:t>a</w:t></w:r><w:r><w:tab/></w:r>'
          '<w:r><w:t>b</w:t></w:r><w:r><w:br/></w:r>'
          '<w:r><w:t>c</w:t></w:r></w:p>';
      expect(extractDocxPlainText(xml), 'a\tb\nc\n');
    });

    test('décode les entités XML nommées et numériques', () {
      const xml = '<w:p><w:r><w:t>Dupont &amp; Fils, ren&#233; '
          'caf&#x00e9;</w:t></w:r></w:p>';
      expect(
        extractDocxPlainText(xml),
        'Dupont & Fils, rené café\n',
      );
    });

    test('ignore le contenu hors <w:t> (mise en forme, styles)', () {
      const xml = '<w:p><w:pPr><w:rPr><w:b/></w:rPr></w:pPr>'
          '<w:r><w:t>Texte visible</w:t></w:r></w:p>';
      expect(extractDocxPlainText(xml), 'Texte visible\n');
    });

    test('<w:t/> auto-fermant ne produit aucun texte', () {
      const xml = '<w:p><w:r><w:t/></w:r><w:r><w:t>Suite</w:t></w:r></w:p>';
      expect(extractDocxPlainText(xml), 'Suite\n');
    });

    test('préserve les attributs sur <w:t xml:space="preserve">', () {
      const xml = '<w:p><w:r><w:t xml:space="preserve">  espaces  '
          '</w:t></w:r></w:p>';
      expect(extractDocxPlainText(xml), '  espaces  \n');
    });
  });
}
