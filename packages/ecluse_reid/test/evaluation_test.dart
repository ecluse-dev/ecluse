import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('evaluateText / evaluateQis (fileAssets, sans device)', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
    });

    Evaluation evalue(String texte) => evaluateText(ref, texte);

    void contratPresent(Evaluation e) {
      expect(e.notes.first, honestyContract);
    }

    test('lieu + âge : évalué, avec estimation et contrat d\'honnêteté', () {
      final e = evalue('Mme X, 66 ans, habite à Thionville.');
      expect(e.statut, EvaluationStatut.evalue);
      expect(e.estimate, isNotNull);
      expect(e.estimate!.f, greaterThan(0));
      expect(e.motifs, isEmpty);
      expect(e.spans.map((s) => s.type).toSet(), {QiType.lieu, QiType.age});
      contratPresent(e);
    });

    test('profession + lieu (Cas A) : évalué, borne haute', () {
      final e = evalue('Le Dr X, pneumologue à Thionville.');
      expect(e.statut, EvaluationStatut.evalue);
      expect(e.estimate!.upperBound, isTrue);
      expect(e.notes, contains(honestyUpperBoundAddendum));
    });

    test('aucun QI : statut explicite, jamais un risque faible', () {
      final e = evalue('Le contrat porte sur la réunion de service.');
      expect(e.statut, EvaluationStatut.aucunQi);
      expect(e.estimate, isNull);
      contratPresent(e);
      expect(e.notes.join(' '), contains('pas un risque faible'));
    });

    test('texte vide : aucun QI, pas d\'exception', () {
      final e = evalue('');
      expect(e.statut, EvaluationStatut.aucunQi);
      contratPresent(e);
    });

    test('deux lieux : non évaluable, motif lisible', () {
      final e = evalue('Elle habite à Dole et travaille à Belfort.');
      expect(e.statut, EvaluationStatut.nonEvaluable);
      expect(e.estimate, isNull);
      expect(e.motifs.single, contains('plusieurs lieux'));
      expect(e.motifs.single, contains('Dole'));
      expect(e.motifs.single, contains('Belfort'));
      contratPresent(e);
    });

    test('deux âges : non évaluable', () {
      final e = evalue('Mme X, 80 ans, vit avec sa fille de 50 ans à Dole.');
      expect(e.statut, EvaluationStatut.nonEvaluable);
      expect(e.motifs.join(' '), contains('plusieurs âges'));
    });

    test('profession sans lieu : non évaluable', () {
      final e = evalue('Le Dr X est pneumologue depuis longtemps.');
      expect(e.statut, EvaluationStatut.nonEvaluable);
      expect(e.motifs.single, contains('profession'));
      expect(e.motifs.single, contains('lieu'));
    });

    test('Paris sans profession : non évaluable, motif qui nomme le lieu', () {
      final e = evalue('Mme X, 70 ans, habite à Paris.');
      expect(e.statut, EvaluationStatut.nonEvaluable);
      expect(e.motifs.single, contains('Paris'));
      expect(e.motifs.single, contains('population'));
      contratPresent(e);
    });

    test(
        'profession + Paris : évalué (comme l\'estimateur), avec '
        'avertissement sur le plafond ignoré', () {
      final e = evalue('Le Dr X, pneumologue à Paris.');
      expect(e.statut, EvaluationStatut.evalue);
      expect(e.estimate!.upperBound, isTrue);
      expect(e.avertissements.single, contains('Paris'));
      expect(e.avertissements.single, contains('plafonné'));
    });

    test('Lyon, Marseille et Mayotte : non évaluables', () {
      for (final lieu in ['Lyon', 'Marseille', 'Mamoudzou']) {
        final e = evalue('Mme X, 70 ans, habite à $lieu.');
        expect(e.statut, EvaluationStatut.nonEvaluable, reason: lieu);
        expect(e.motifs.single, contains(lieu));
      }
    });

    test('population légale nulle : non évaluable (F non défini)', () {
      final e = evalue('Mme X serait née à Bezonvaux.');
      expect(e.statut, EvaluationStatut.nonEvaluable);
      expect(e.motifs.single, contains('nulle'));
    });

    test('effectif estimé nul (âge hors des données) : non évaluable', () {
      final e = evalue('M. X, 110 ans, est hébergé à Dole.');
      expect(e.statut, EvaluationStatut.nonEvaluable);
      expect(e.motifs.single, contains('nul'));
    });

    test(
        'commune ambiguë : évalué avec avertissement, jamais faible par '
        'défaut de lecture', () {
      final e = evalue('Mme X, 80 ans, habite à Aboncourt.');
      expect(e.statut, EvaluationStatut.evalue);
      expect(e.avertissements.single, contains('Aboncourt'));
      // La plus petite commune est retenue : F est celui du cas prudent.
      final espere = estimate(ref, e.qis).f;
      expect(e.estimate!.f, espere);
    });

    test('la même commune citée deux fois n\'est pas un doublon', () {
      final e = evalue('Mme X habite à Dole, 80 ans. Elle est née à Dole.');
      expect(e.statut, EvaluationStatut.evalue);
      expect(e.qis.where((q) => q.type == QiType.lieu), hasLength(1));
    });

    test('plusieurs mots-clés de la même profession : pas de doublon', () {
      final e = evalue('Mme X est chirurgien-dentiste à Dole, 50 ans.');
      expect(e.statut, EvaluationStatut.evalue);
    });

    test(
        'surnom de commune : un patronyme égal à une commune reste un lieu '
        'détecté (limite documentée), jamais une exception', () {
      final e = evalue('Mme Chevrier habite à Nantes.');
      expect(e.statut,
          anyOf(EvaluationStatut.evalue, EvaluationStatut.nonEvaluable));
    });

    test('evaluateQis : QI structurés, mêmes règles, sans position', () {
      final e = evaluateQis(ref, const [
        Qi(QiType.profession, '11'),
        Qi(QiType.lieu, '57', level: 1),
      ]);
      expect(e.statut, EvaluationStatut.evalue);
      expect(e.estimate!.f, 51);
      expect(e.spans, isEmpty);
      contratPresent(e);
    });

    test(
        'evaluateQis : doublon, profession sans lieu, niveau de lieu '
        'incalculable -> non évaluable, jamais d\'exception', () {
      final doublon = evaluateQis(ref, const [
        Qi(QiType.lieu, '57672'),
        Qi(QiType.lieu, '70550'),
      ]);
      expect(doublon.statut, EvaluationStatut.nonEvaluable);
      final sansLieu = evaluateQis(ref, const [Qi(QiType.profession, '11')]);
      expect(sansLieu.statut, EvaluationStatut.nonEvaluable);
      final region = evaluateQis(ref, const [Qi(QiType.lieu, '44', level: 2)]);
      expect(region.statut, EvaluationStatut.nonEvaluable);
      final inconnu = evaluateQis(ref, const [
        Qi(QiType.profession, 'zzz'),
        Qi(QiType.lieu, '57', level: 1)
      ]);
      expect(inconnu.statut, EvaluationStatut.nonEvaluable);
      for (final e in [doublon, sansLieu, region, inconnu]) {
        expect(e.motifs, isNotEmpty);
        contratPresent(e);
      }
    });

    test('evaluateQis sans QI : aucun QI', () {
      expect(evaluateQis(ref, const []).statut, EvaluationStatut.aucunQi);
    });

    test('jamais d\'exception sur des entrées dégradées', () async {
      final entrees = <String>[
        '',
        '\n',
        'ÉÉÉ',
        'Paris Lyon Marseille Mamoudzou',
        'pneumologue pneumologue pneumologue',
        '999 ans 0 ans 120 ans 121 ans',
        'Saint-Denis ' * 100,
        '😀 Dole 😀',
      ];
      for (final t in entrees) {
        expect(() => evaluateText(ref, t), returnsNormally, reason: t);
      }
    });

    test('les fonctions existantes gardent leur comportement (ArgumentError)',
        () {
      expect(() => estimate(ref, const [Qi(QiType.profession, '11')]),
          throwsArgumentError);
      expect(
          () => estimate(ref, const [
                Qi(QiType.lieu, '57672'),
                Qi(QiType.lieu, '70550'),
              ]),
          throwsArgumentError);
    });
  });
}
