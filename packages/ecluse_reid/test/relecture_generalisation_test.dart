import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Un texte généralisé doit se relire au palier qui l'a produit (P2-102).
///
/// La mesure P2-93 (#262) a montré l'inverse : « 104 ans » était relu dans
/// « 100-104 ans » comme un âge exact, et « médecin (toute spécialité) »
/// n'était plus une profession. F pouvait alors baisser après une
/// généralisation censée le faire monter, l'évaluation devenir impossible, et
/// une généralisation répétée boucler (« 100-100-104 ans »).
void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  group('âge', () {
    test('« 100-104 ans » : une tranche, pas l\'âge exact 104', () {
      const tranche = Qi(QiType.age, '100-104', level: 1);
      expect(extractAge('patiente de 100-104 ans.'), [tranche]);
    });

    test('le palier suit la largeur de la tranche', () {
      const cinq = Qi(QiType.age, '70-74', level: 1);
      const dix = Qi(QiType.age, '70-79', level: 2);
      const senior = Qi(QiType.age, '65-130', level: 3);
      expect(extractAge('70-74 ans'), [cinq]);
      expect(extractAge('70-79 ans'), [dix]);
      expect(extractAge('65-130 ans'), [senior]);
    });

    test('âge exact et tranche : dans l\'ordre du texte', () {
      const exact = Qi(QiType.age, '18');
      const tranche = Qi(QiType.age, '70-74', level: 1);
      expect(extractAge('lui 18 ans, elle 70-74 ans.'), [exact, tranche]);
    });

    test('tranche incohérente : rien n\'est relu', () {
      expect(extractAge('80-20 ans'), isEmpty);
    });

    test('extraction positionnée : un seul span sur la tranche', () {
      const texte = 'patiente de 100-104 ans.';
      final spans = extractQiSpans(ref, texte).spans;
      expect(spans, hasLength(1));
      expect(spans.single.text, '100-104 ans');
      expect(spans.single.qi, const Qi(QiType.age, '100-104', level: 1));
    });
  });

  group('profession', () {
    const toute = Qi(QiType.profession, professionToutesSpecialites, level: 1);
    const sante = Qi(QiType.profession, professionnelDeSante, level: 2);

    test('« médecin (toute spécialité) » relu au palier 1', () {
      const texte = 'suivie par un médecin (toute spécialité).';
      expect(extractProfession(ref, texte), contains(toute));
      expect(extractQiSpans(ref, texte).spans.single.qi, toute);
    });

    test('« professionnel de santé (toute profession) » au palier 2', () {
      const texte = 'un professionnel de santé (toute profession)';
      expect(extractQiSpans(ref, texte).spans.single.qi, sante);
    });
  });

  test('chaque palier d\'âge ou de profession se relit tel quel', () {
    const departs = [
      Qi(QiType.age, '103'),
      Qi(QiType.age, '42'),
      Qi(QiType.profession, professionToutesSpecialites, level: 1),
    ];
    for (final depart in departs) {
      var qi = nextRung(ref, depart);
      while (qi != null && qi.value != qiRetraitValue) {
        final libelle = qiValueLabel(ref, qi);
        final relus = extractQiSpans(ref, libelle).spans;
        expect([for (final s in relus) s.qi], [qi], reason: libelle);
        qi = nextRung(ref, qi);
      }
    }
  });
}
