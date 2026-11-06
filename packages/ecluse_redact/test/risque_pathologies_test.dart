import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// Pathologies dans le rapport de risque (P2-127) : information seulement.
void main() {
  EcluseReference nouvelle() =>
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));

  const texte = 'Mme Odile Verdier, 74 ans, habite à Thionville. Elle est '
      'atteinte de la maladie de Huntington et suivie pour diabète de type 2.';

  test('maladie rare et pathologie fréquente signalées, texte inchangé',
      () async {
    final ref = nouvelle();
    await ref.preload();
    await ref.rareDiseases.load();
    final sans = await Ecluse.redact(texte);
    final r = await Ecluse.redact(texte, riskReference: ref);
    expect(r.maskedText, sans.maskedText);
    final p = r.risque!.pathologies;
    expect([for (final m in p) m.text],
        ['maladie de Huntington', 'diabète de type 2']);
    for (final m in p) {
      expect(r.maskedText.substring(m.start, m.end), m.text);
    }
    expect(r.risque!.limites.last, contains('2 pathologies rattachées'));
    expect(r.risque!.limites.last, contains('maladie de Huntington'));
  });

  test('catalogue Orphanet non chargé : seulement la table maison', () async {
    final ref = nouvelle();
    await ref.preload();
    final r = await Ecluse.redact(texte, riskReference: ref);
    expect(
        [for (final m in r.risque!.pathologies) m.text], ['diabète de type 2']);
  });

  test('pathologie niée ou non rattachée : rien, et limites inchangées',
      () async {
    final ref = nouvelle();
    await ref.preload();
    final r = await Ecluse.redact(
        'Réunion du réseau diabète. Pas de BPCO connue chez Mme Verdier.',
        riskReference: ref);
    expect(r.risque!.pathologies, isEmpty);
    expect(r.risque!.limites, limitesSansNer);
  });

  group('généralisation de pathologie (P2-135)', () {
    late EcluseReference ref;
    setUpAll(() async {
      ref = nouvelle();
      await ref.preload();
      await ref.rareDiseases.load();
    });

    test('paliers proposés : catégorie puis générique, sans rien appliquer',
        () async {
      final r = await Ecluse.redact(texte, riskReference: ref);
      final s = r.risque!.suggestionsPathologie;
      expect([
        for (final x in s) (x.mention.text, x.palier, x.libelle)
      ], [
        ('maladie de Huntington', 1, 'maladie neurologique rare'),
        ('maladie de Huntington', 2, 'maladie rare'),
        ('diabète de type 2', 1, 'maladie métabolique'),
        ('diabète de type 2', 2, 'maladie chronique'),
      ]);
      expect(r.maskedText, contains('maladie de Huntington'));
    });

    test('appliquer : irréversible, jetons et table intacts', () async {
      final r = await Ecluse.redact(texte, riskReference: ref);
      final s = r.risque!.suggestionsPathologie;
      final g =
          appliquerGeneralisationsPathologie(r, [s[0], s[3]], reference: ref);
      expect(
          g.maskedText, contains('atteinte de la maladie neurologique rare'));
      expect(g.maskedText, contains('suivie pour maladie chronique'));
      expect(g.maskedText, isNot(contains('Huntington')));
      expect(g.mapping, r.mapping);
      expect(
          Ecluse.restore(g.maskedText, g.mapping), contains('Odile Verdier'));
      expect(g.risque!.pathologies, isEmpty, reason: 'rapport recalculé');
    });

    test('deux paliers sur la même mention : refus', () async {
      final r = await Ecluse.redact(texte, riskReference: ref);
      final s = r.risque!.suggestionsPathologie;
      expect(
          () => appliquerGeneralisationsPathologie(r, [s[0], s[1]],
              reference: ref),
          throwsA(isA<GeneralisationException>()));
    });

    test('suggestion d\'un autre résultat : refus', () async {
      final a = await Ecluse.redact(texte, riskReference: ref);
      final b = await Ecluse.redact(texte, riskReference: ref);
      expect(
          () => appliquerGeneralisationsPathologie(
              b, [a.risque!.suggestionsPathologie.first],
              reference: ref),
          throwsA(isA<GeneralisationException>()));
    });

    test('forme adjectivale ou niée : aucune suggestion', () async {
      final r = await Ecluse.redact(
          'Mme Odile Verdier, diabétique, 74 ans. Pas de BPCO connue.',
          riskReference: ref);
      expect(r.risque!.pathologies, hasLength(1));
      expect(r.risque!.suggestionsPathologie, isEmpty);
    });
  });
}
