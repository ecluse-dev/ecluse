import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Non-fuite hors du trajet du texte (P2-170, voies F1, F3, F4 et « hors
/// décompte » de `agent/specs/P2-169.md`).
///
/// Une application qui appelle `ecluse_reid` directement peut interpoler un
/// de ces objets dans un journal, ou envoyer une exception à son outil de
/// suivi d'erreurs. Ni un `toString` ni un message d'exception ne doit donc
/// porter une valeur tirée du texte : commune, âge, date de naissance,
/// profession, pathologie. Toutes les valeurs ci-dessous sont synthétiques.
void main() {
  group('F1 : Qi.toString ne rend pas la valeur', () {
    for (final (type, valeur) in const [
      (QiType.lieu, 'Vesoul-synth'),
      (QiType.age, '47'),
      (QiType.age, '45-49'),
      (QiType.profession, 'pharmacien-synth'),
    ]) {
      test('${type.name} de ${valeur.length} caractères', () {
        final texte = Qi(type, valeur).toString();
        expect(texte, isNot(contains(valeur)));
        // Ce qui reste utile au débogage : type, niveau, longueur.
        expect(texte, contains(type.name));
        expect(texte, contains('niveau 0'));
        expect(texte, contains('${valeur.length} car.'));
      });
    }

    test('le niveau reste lisible', () {
      expect(
        const Qi(QiType.lieu, '70', level: 1).toString(),
        contains('niveau 1'),
      );
    });
  });

  group('hors décompte : BirthDate', () {
    test('toString ne rend ni l\'année, ni le mois, ni le jour', () {
      final texte = BirthDate(1951, 3, 14).toString();
      expect(texte, isNot(contains('1951')));
      expect(texte, isNot(contains('14')));
      expect(texte, isNot(contains('3')));
    });

    test('une date inexistante est refusée sans citer la composante reçue', () {
      for (final (a, m, j, recu) in const [
        (1951, 4, 31, '31'),
        (1951, 13, 14, '13'),
        (-1951, 4, 14, '1951'),
      ]) {
        expect(
          () => BirthDate(a, m, j),
          throwsA(isA<ArgumentError>()
              .having((e) => e.toString(), 'texte', isNot(contains(recu)))),
        );
      }
    });
  });

  group('hors décompte : Generalization.toString', () {
    test('ne rend la valeur ni avant ni après la généralisation', () {
      const g = Generalization(
        Qi(QiType.lieu, 'Vesoul-synth'),
        Qi(QiType.lieu, 'dep-synth', level: 1),
        12,
        3400,
        RiskBand.eleve,
        RiskBand.faible,
      );
      final texte = g.toString();
      expect(texte, isNot(contains('Vesoul-synth')));
      expect(texte, isNot(contains('dep-synth')));
      expect(texte, contains('niveau 0'));
      expect(texte, contains('niveau 1'));
    });
  });

  group('F3 : PathologieMention.toString ne rend ni le texte ni la catégorie',
      () {
    late RareDiseaseCatalog catalogue;
    setUpAll(() async {
      catalogue = RareDiseaseCatalog(
          fileAssets(assetsDir: '../ecluse_reference/assets'));
      await catalogue.load();
    });

    test('table maison (reproduction du rapport P2-169)', () {
      final m = extrairePathologies('Madame X a une mucoviscidose.',
              catalogue: catalogue)
          .single;
      final texte = m.toString();
      expect(texte, isNot(contains('mucoviscidose')));
      expect(texte, isNot(contains(m.categorie)));
      expect(texte, isNot(contains(m.systeme)));
      expect(texte, contains('${m.start}-${m.end}'));
      expect(texte, contains(m.source));
    });

    test('maladie rare (Orphanet)', () {
      final m = extrairePathologies(
              'Madame X est atteinte de sclérose latérale amyotrophique.',
              catalogue: catalogue)
          .firstWhere((m) => m.source == 'orphanet');
      final texte = m.toString().toLowerCase();
      expect(texte, isNot(contains('amyotrophique')));
      expect(texte, isNot(contains(m.categorie.toLowerCase())));
    });
  });

  group('F4 : les ArgumentError de l\'estimateur ont un motif fixe', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
    });

    // (nom du cas, QI, valeur qui ne doit pas sortir)
    final cas = <(String, List<Qi>, String)>[
      (
        'âge illisible',
        const [Qi(QiType.age, '47 ans synth')],
        '47',
      ),
      (
        'âge exact hors bornes',
        const [Qi(QiType.age, '999')],
        '999',
      ),
      (
        'tranche d\'âge invalide',
        const [Qi(QiType.age, '97-93', level: 1)],
        '97',
      ),
      (
        'tranche d\'âge illisible',
        const [Qi(QiType.age, 'tranche-synth', level: 2)],
        'tranche-synth',
      ),
      (
        'code de profession inconnu',
        const [
          Qi(QiType.profession, 'metier-synth'),
          Qi(QiType.lieu, '57', level: 1),
        ],
        'metier-synth',
      ),
      (
        'commune inconnue, population',
        const [Qi(QiType.lieu, 'commune-synth')],
        'commune-synth',
      ),
      (
        'commune inconnue, département de la profession',
        const [
          Qi(QiType.profession, '11'),
          Qi(QiType.lieu, 'commune-synth'),
        ],
        'commune-synth',
      ),
      (
        'département inconnu (F5, par l\'estimateur)',
        const [Qi(QiType.lieu, 'ZZ', level: 1)],
        'ZZ',
      ),
      (
        'département incomplet (F5, par l\'estimateur)',
        const [Qi(QiType.lieu, '976', level: 1)],
        '976',
      ),
    ];

    for (final (nom, qis, valeur) in cas) {
      test('$nom : estimate', () {
        expect(
          () => estimate(ref, qis),
          throwsA(isA<ArgumentError>()
              .having((e) => e.toString(), 'texte', isNot(contains(valeur)))),
        );
      });

      test('$nom : motif d\'evaluateQis', () {
        // Le filet d'`evaluateQis` recopie le message de l'erreur dans un
        // motif rendu à l'application : même exigence.
        final e = evaluateQis(ref, qis);
        expect(e.statut, EvaluationStatut.nonEvaluable);
        expect(e.motifs, isNotEmpty);
        expect(e.motifs.join('\n'), isNot(contains(valeur)));
      });
    }
  });
}
