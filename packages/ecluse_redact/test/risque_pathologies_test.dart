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
}
