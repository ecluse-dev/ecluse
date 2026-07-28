import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('ReidLoop.explain (fileAssets, sans device)', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
    });

    test('liste vide -> succès (F == totalPopulation >= seuil)', () {
      final trace = ReidLoop(ref).explain(const []);
      expect(trace.outcome, TraceOutcome.succes);
      expect(trace.suggestion, isNull);
      expect(trace.candidats, isEmpty);
    });

    test('Aboncourt 89 ans, seuil standard -> suggestion (généralise lieu)',
        () {
      final qis = const [Qi(QiType.age, '89'), Qi(QiType.lieu, '57001')];
      final trace = ReidLoop(ref).explain(qis);
      expect(trace.outcome, TraceOutcome.suggestion);
      expect(trace.suggestion!.fAfter, closeTo(3519.56, 1));
      expect(trace.bandeFinale, RiskBand.faible);
    });

    test('Aboncourt 89 ans, seuil artificiellement inatteignable -> épuisement',
        () {
      final qis = const [Qi(QiType.age, '89'), Qi(QiType.lieu, '57001')];
      final trace = ReidLoop(ref, threshold: 1000000).explain(qis);
      expect(trace.outcome, TraceOutcome.epuisement);
      expect(trace.suggestion, isNotNull); // meilleure tentative quand même
      expect(trace.qisBloquants, isNotEmpty);
    });

    test('lieu France seul, aucun candidat -> épuisement sans suggestion', () {
      final qis = const [Qi(QiType.lieu, lieuFrance, level: 4)];
      final trace = ReidLoop(ref, threshold: 1000000000).explain(qis);
      expect(trace.outcome, TraceOutcome.epuisement);
      expect(trace.suggestion, isNull);
    });

    test("explainNarrative et toAuditMap contiennent le contrat d'honnêteté",
        () {
      final qis = const [Qi(QiType.age, '89'), Qi(QiType.lieu, '57001')];
      final trace = ReidLoop(ref).explain(qis);
      expect(trace.explainNarrative(ref), contains(honestyContract));
      expect(trace.toAuditMap()['notes'], contains(honestyContract));
    });
  });
}
