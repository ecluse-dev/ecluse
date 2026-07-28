import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Test doré du Jalon 3 (voir `docs/Ecluse-Jalon3-reid-spec.md`, §9) : le
/// trajet « 89 ans à Aboncourt → quasi unique → généralise au département →
/// risque faible » (Cas B) et « pneumologue en Moselle → borne haute 51 →
/// médecin toute spécialité → professionnel de santé » (Cas A), sur données
/// publiques réelles. Si ces chiffres dérivent un jour, l'estimateur a
/// changé de comportement.
void main() {
  late EcluseReference ref;

  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  group('Cas B — 89 ans à Aboncourt (57001, 320 hab.)', () {
    const qis = [Qi(QiType.age, '89'), Qi(QiType.lieu, '57001')];
    late ReidLoop loop;
    setUp(() => loop = ReidLoop(ref));

    test('assess : F ≈ 1,07, bande ÉLEVÉ', () {
      final e = loop.assess(qis);
      expect(e.f, closeTo(1.0713, 0.01), reason: '320 hab. × part-âge-89');
      expect(e.band, RiskBand.eleve);
      expect(e.dominant, QiType.lieu);
      expect(e.notes, contains(honestyContract));
    });

    test(
        'suggest : généralise lieu commune -> département, F ≈ 3520, '
        'bande FAIBLE', () {
      // Le spec (§3, §9) illustre fAfter ≈ 1 760 pour cette généralisation,
      // en supposant implicitement un facteur sexe ×0,5 — mais le sexe est
      // explicitement hors périmètre des types de QI ce jalon (§1). La
      // valeur réelle sans ce facteur, vérifiée sur les données commitées
      // (population Moselle 1 051 309 × part-âge-89), est ≈ 3 520. La bande
      // reste FAIBLE dans les deux cas (seuil F≥50 inchangé) — décision
      // documentée dans le plan d'implémentation du Jalon 3.
      final g = loop.suggest(qis);
      expect(g, isNotNull);
      expect(g!.from.type, QiType.lieu);
      expect(g.to.level, 1);
      expect(g.fAfter, closeTo(3519.56, 1));
      expect(g.bandAfter, RiskBand.faible);
    });
  });

  group('Cas A — pneumologue ("11") en Moselle (dep "57")', () {
    const qis = [Qi(QiType.profession, '11'), Qi(QiType.lieu, '57', level: 1)];
    late ReidLoop loop;
    setUp(() => loop = ReidLoop(ref));

    test('assess : F == 51, upperBound', () {
      final e = loop.assess(qis);
      expect(e.f, 51, reason: 'medecinsCount("57","11")');
      expect(e.upperBound, isTrue);
      expect(e.notes, contains(honestyUpperBoundAddendum));
    });

    test(
        'suggest (1er appel) : médecin toute spécialité en Moselle, '
        'F == 2894, puis (2e appel manuel) professionnel de santé, F == 5107',
        () {
      final g = loop.suggest(qis)!;
      expect(g.to.value, professionToutesSpecialites);
      expect(g.fAfter, 2894);

      // Un seul palier par appel de suggest() — l'humain décide de
      // poursuivre (spec §4/§5 : pas de boucle multi-crans automatique).
      final qisNiveau1 = [g.to, qis[1]];
      final g2 = loop.suggest(qisNiveau1)!;
      expect(g2.to.value, professionnelDeSante);
      expect(g2.fAfter, 5107);
    });
  });

  test("contrat d'honnêteté (§6) présent dans assess/suggest/explain", () {
    const qis = [Qi(QiType.age, '89'), Qi(QiType.lieu, '57001')];
    final loop = ReidLoop(ref);
    expect(loop.assess(qis).notes, contains(honestyContract));
    expect(loop.explain(qis).notes, contains(honestyContract));
    expect(loop.explain(qis).suggestion, isNotNull);
  });
}
