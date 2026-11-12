import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// P2-159 : âge écrit en lettres suivi de « ans » (les 15 cas non couverts du
/// corpus QI adversarial, `agent/specs/P2-154.md` § 2) et tranche « de 80 à
/// 85 ans » (seule la borne 85 sortait). Textes synthétiques.
void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  const lettres = {
    'trente et un ans': '31',
    'soixante-douze ans': '72',
    'quatre-vingt-quatorze ans': '94',
    'quarante-sept ans': '47',
    'cinquante-huit ans': '58',
    'soixante et onze ans': '71',
    'soixante-dix ans': '70',
    'soixante-dix-sept ans': '77',
    'quatre-vingts ans': '80',
    'quatre-vingt-un ans': '81',
    'quatre-vingt-dix ans': '90',
    'quatre vingt dix-neuf ans': '99',
    'vingt et un ans': '21',
    'vingt-deux ans': '22',
    'dix-sept ans': '17',
    'douze ans': '12',
    'cent ans': '100',
    'cent un ans': '101',
    'cent vingt ans': '120',
    'QUARANTE-SEPT ANS': '47',
    'soixante douze ans': '72',
  };
  for (final MapEntry(key: mots, value: age) in lettres.entries) {
    test('lu : « $mots »', () {
      expect(extractAge('Mme Chevrier, $mots, vit à Rennes.'), [
        Qi(QiType.age, age),
      ]);
      final spans = extractQiSpans(ref, 'Mme Chevrier, $mots, vit à Rennes.')
          .spans
          .where((s) => s.type == QiType.age)
          .toList();
      expect(spans, hasLength(1));
      expect(spans.single.text, mots);
      expect(spans.single.qi, Qi(QiType.age, age));
    });
  }

  const durees = [
    'Suivi depuis trente ans.',
    'Il y a vingt ans, elle a déménagé.',
    'Contrat signé pour dix ans.',
    'Retour dans trois ans.',
    'Elle travaille ici depuis plus de vingt ans.',
    'Tous les deux ans, un bilan.',
  ];
  for (final texte in durees) {
    test('durée, pas un âge : $texte', () {
      expect(extractAge(texte), isEmpty);
    });
  }

  const nonLus = [
    'la soixantaine',
    'octogénaire',
    'Elle a trente jours de congé.',
    'soixante personnes',
    'quarante-quatre-vingt ans',
    'dix et vingt ans',
    'vingt-et ans',
    'un ans',
    'trente',
  ];
  for (final texte in nonLus) {
    test('non lu : $texte', () {
      expect(extractAge(texte), isEmpty);
    });
  }

  group('tranche « de N à M ans »', () {
    const tranches = {
      'de 80 à 85 ans': Qi(QiType.age, '80-85', level: 2),
      'entre 60 et 65 ans': Qi(QiType.age, '60-65', level: 2),
      'entre 60 et 64 ans': Qi(QiType.age, '60-64', level: 1),
      'De 70 à 79 ans': Qi(QiType.age, '70-79', level: 2),
      'âgée de 80 à 95 ans': Qi(QiType.age, '80-95', level: 3),
      'de 80 à 85 ans': Qi(QiType.age, '80-85', level: 2),
      '80-85 ans': Qi(QiType.age, '80-85', level: 2),
    };
    for (final MapEntry(key: texte, value: qi) in tranches.entries) {
      test('lue : $texte', () {
        expect(extractAge('Patiente $texte, suivie.'), [qi]);
      });
    }

    test('le span commence au premier nombre', () {
      const texte = 'Patiente de 80 à 85 ans, suivie.';
      final age = extractQiSpans(ref, texte)
          .spans
          .where((s) => s.type == QiType.age)
          .single;
      expect(age.text, '80 à 85 ans');
      expect(texte.substring(age.start, age.end), age.text);
    });

    const durees = [
      'Un suivi de 2 à 3 ans de traitement.',
      'Expérience de 2 à 3 ans d’ancienneté.',
      'Il y a entre 5 et 7 ans, déménagement.',
      'Pour entre 2 et 3 ans de suite.',
    ];
    for (final texte in durees) {
      test('durée, pas un âge : $texte', () {
        expect(extractAge(texte), isEmpty);
      });
    }

    test('une borne sans « de » ou « entre » reste un âge isolé', () {
      expect(extractAge('Patiente 80 à 85 ans.'), [const Qi(QiType.age, '85')]);
    });

    test('tranche incohérente : aucun âge fabriqué', () {
      expect(extractAge('de 90 à 85 ans'), isEmpty);
    });
  });
}
