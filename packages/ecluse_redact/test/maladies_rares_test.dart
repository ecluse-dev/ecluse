import 'package:ecluse_core/ecluse_core.dart' show EntityType;
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// Masquage des maladies rares (P2-143, décision du mainteneur du 7
/// novembre) : une maladie rare rattachée à une personne est masquée et
/// restaurable ; une pathologie fréquente reste en clair (signalée par le
/// rapport de risque) ; une mention niée ou générale n'est pas masquée.
void main() {
  late RareDiseaseCatalog catalogue;

  setUpAll(() async {
    final ref =
        EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.rareDiseases.load();
    catalogue = ref.rareDiseases;
  });

  const texte = 'Mme Odile Verdier, 74 ans, habite à Thionville. Elle est '
      'atteinte de la maladie de Huntington et suivie pour diabète de type 2.';

  test('maladie rare rattachée : masquée et restaurée', () async {
    final r = await Ecluse.redact(texte, maladiesRares: catalogue);
    expect(r.maskedText, isNot(contains('Huntington')));
    expect(r.maskedText, contains('[MALADIE_RARE_1]'));
    expect(r.maskedText, contains('diabète de type 2'));
    expect(r.mapping['[MALADIE_RARE_1]'], 'maladie de Huntington');
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('sans catalogue : sortie identique à avant', () async {
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, contains('maladie de Huntington'));
  });

  test('catalogue non chargé : refus explicite', () async {
    final vide =
        EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'))
            .rareDiseases;
    expect(() => Ecluse.redact(texte, maladiesRares: vide),
        throwsA(isA<StateError>()));
  });

  test('mention niée ou générale : en clair', () async {
    for (final t in [
      'M. Paul Girard, pas de maladie de Huntington connue dans la famille.',
      'La maladie de Huntington est une affection neurologique héréditaire.',
    ]) {
      final r = await Ecluse.redact(t, maladiesRares: catalogue);
      expect(r.maskedText, contains('maladie de Huntington'), reason: t);
    }
  });

  test('même maladie citée deux fois : même jeton', () async {
    const t = 'Mme Lucie Bernard, atteinte de syndrome de Rett. Elle est '
        'suivie pour syndrome de Rett depuis 2019.';
    final r = await Ecluse.redact(t, maladiesRares: catalogue);
    expect('[MALADIE_RARE_1]'.allMatches(r.maskedText).length, 2,
        reason: r.maskedText);
    expect(r.maskedText, isNot(contains('[MALADIE_RARE_2]')));
  });

  test('detect rend la même entité, sans effet de bord', () async {
    final e = await Ecluse.detect(texte, maladiesRares: catalogue);
    final m = e.where((x) => x.type == EntityType.maladieRare).toList();
    expect([for (final x in m) x.value], ['maladie de Huntington']);
  });

  test('table maison : rare si Orphanet la connaît ou si un éponyme suit',
      () async {
    final cas = {
      'M. Paul Girard, atteint de mucoviscidose.': true,
      'Mme Claire Benali, suivie pour drépanocytose.': true,
      'M. Rémi Perrin, atteint de myopathie de Duchenne.': true,
      'M. Rémi Perrin, suivi pour tuberculose.': false,
      'Mme Odile Verdier, suivie pour diabète de type 2.': false,
      'M. Paul Girard, atteint de la maladie de Parkinson.': false,
    };
    for (final MapEntry(key: t, value: rare) in cas.entries) {
      final r = await Ecluse.redact(t, maladiesRares: catalogue);
      expect(r.maskedText.contains('[MALADIE_RARE_1]'), rare,
          reason: r.maskedText);
    }
  });

  test('non rattachée mais personne nommée : masquée', () async {
    const t = 'Mme Odile Verdier, 52 ans. Diagnostic : maladie de Wilson.';
    final r = await Ecluse.redact(t, maladiesRares: catalogue);
    expect(r.maskedText, contains('[MALADIE_RARE_1]'), reason: r.maskedText);
    expect(Ecluse.restore(r.maskedText, r.mapping), t);
  });
}
