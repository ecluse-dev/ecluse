import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('extractQiSpans (fileAssets, sans device)', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
    });

    List<QiSpan> spansDe(String texte, [QiType? type]) => extractQiSpans(
          ref,
          texte,
        ).spans.where((s) => type == null || s.type == type).toList();

    test('positions exactes : texte[start, end) redonne le texte du span', () {
      const texte =
          'Le Dr Martin, pneumologue à Thionville, 54 ans, est en arrêt.';
      final spans = extractQiSpans(ref, texte).spans;
      expect(spans.map((s) => s.type),
          [QiType.profession, QiType.lieu, QiType.age]);
      for (final s in spans) {
        expect(texte.substring(s.start, s.end), s.text);
      }
      expect(spans[0].text, 'pneumologue');
      expect(spans[0].qi, const Qi(QiType.profession, '11'));
      expect(spans[1].text, 'Thionville');
      expect(spans[1].qi, const Qi(QiType.lieu, '57672'));
      expect(spans[2].text, '54 ans');
      expect(spans[2].qi, const Qi(QiType.age, '54'));
    });

    test('triés par position', () {
      const texte = 'À Dole, 40 ans, Mme X est cardiologue.';
      final starts = extractQiSpans(ref, texte).spans.map((s) => s.start);
      expect(starts.toList(), [...starts]..sort());
    });

    test(
        'chirurgien-dentiste : un seul span, pas « chirurgien » + « dentiste »',
        () {
      final p =
          spansDe('Elle est chirurgien-dentiste à Dole.', QiType.profession);
      expect(p, hasLength(1));
      expect(p.single.text, 'chirurgien-dentiste');
      expect(p.single.qi, const Qi(QiType.profession, 'chirurgien-dentiste'));
    });

    test('médecin généraliste : un seul span (le plus long)', () {
      final p = spansDe('Le médecin généraliste de Dole.', QiType.profession);
      expect(p, hasLength(1));
      expect(p.single.text, 'médecin généraliste');
      expect(p.single.qi, const Qi(QiType.profession, '01'));
    });

    test('pharmacienne : un seul span, valeur pharmacien', () {
      final p = spansDe('Mme Dupont est pharmacienne.', QiType.profession);
      expect(p, hasLength(1));
      expect(p.single.text, 'pharmacienne');
      expect(p.single.qi, const Qi(QiType.profession, 'pharmacien'));
    });

    test('« orl » dans Orléans n\'est pas une spécialité', () {
      final texte = 'Elle habite à Orléans.';
      expect(spansDe(texte, QiType.profession), isEmpty);
      final lieu = spansDe(texte, QiType.lieu);
      expect(lieu, hasLength(1));
      expect(lieu.single.text, 'Orléans');
    });

    test('ORL seul est une spécialité, sans tenir compte de la casse', () {
      final p = spansDe('Le Dr Martin est ORL à Dole.', QiType.profession);
      expect(p.single.text, 'ORL');
      expect(p.single.qi, const Qi(QiType.profession, '04'));
      expect(spansDe('Un CARDIOLOGUE.', QiType.profession).single.qi,
          const Qi(QiType.profession, '06'));
    });

    test('Le Mans : un seul lieu (le plus long), pas « Mans » en plus', () {
      final l = spansDe('Elle vit au Mans, et lui à Le Mans.', QiType.lieu);
      expect(l.map((s) => s.text), contains('Le Mans'));
      // Aucun chevauchement entre spans du même type.
      for (var i = 0; i < l.length; i++) {
        for (var j = i + 1; j < l.length; j++) {
          expect(l[i].end <= l[j].start || l[j].end <= l[i].start, isTrue);
        }
      }
    });

    test('lieu composé avec tirets et apostrophe : un seul span', () {
      final l = spansDe("Il demeure à L'Isle-sur-le-Doubs.", QiType.lieu);
      expect(l, hasLength(1));
      expect(l.single.text, "L'Isle-sur-le-Doubs");
    });

    test('un lieu ne traverse pas la ponctuation entre deux phrases', () {
      // « Dole. Belfort » ne doit pas devenir un candidat à trois mots.
      final l = spansDe('Elle vit à Dole. Belfort est loin.', QiType.lieu);
      expect(l.map((s) => s.text), ['Dole', 'Belfort']);
    });

    test('commune ambiguë : plus petite commune + avertissement + candidats',
        () {
      final r = extractQiSpans(ref, 'Elle habite à Aboncourt.');
      final l = r.spans.where((s) => s.type == QiType.lieu).single;
      expect(l.ambigu, isTrue);
      expect(l.candidats.length, greaterThan(1));
      final plusPetite = l.candidats
          .where((c) => c.pmun != null)
          .reduce((a, b) => a.pmun! <= b.pmun! ? a : b);
      expect(l.qi, Qi(QiType.lieu, plusPetite.code));
      expect(r.avertissements.single, contains('Aboncourt'));
      expect(r.avertissements.single, contains('ambigu'));
    });

    test('âge : espace insécable, bornes et valeurs hors plage', () {
      expect(spansDe('Il a 94 ans.', QiType.age).single.text, '94 ans');
      expect(spansDe('Il a 94 ans.', QiType.age).single.qi,
          const Qi(QiType.age, '94'));
      // Au-delà de 120 : ce n'est pas un âge (même règle que extractAge).
      expect(spansDe('Un contrat de 130 ans.', QiType.age), isEmpty);
    });

    test('texte sans quasi-identifiant : aucun span, aucune exception', () {
      final r = extractQiSpans(ref, 'Il fait beau aujourd\'hui.');
      expect(r.spans, isEmpty);
      expect(r.avertissements, isEmpty);
    });

    test('entrées dégradées : jamais d\'exception', () {
      final entrees = <String>[
        '',
        ' ',
        '\n\n',
        'A',
        'ÉÉÉÉÉ',
        '123456789 ans',
        '\u0000 ',
        'Saint-Denis ' * 200,
        List.filled(300, 'Le Mans').join(' '),
        '😀 pneumologue 😀 94 ans',
      ];
      for (final e in entrees) {
        expect(() => extractQiSpans(ref, e), returnsNormally, reason: e);
      }
    });

    test('ne modifie pas les extractions existantes (extractQis inchangée)',
        () {
      // Garde-fou de non-régression : l'ajout est strictement additif.
      expect(extractAge('Le patient a 89 ans.'), [const Qi(QiType.age, '89')]);
      expect(extractProfession(ref, 'Il est pneumologue.'),
          contains(const Qi(QiType.profession, '11')));
    });
  });
}
