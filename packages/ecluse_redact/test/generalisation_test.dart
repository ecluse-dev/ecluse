import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Application explicite des suggestions de généralisation (P2-92, option B
/// de `agent/specs/P2-03.md`). Le moteur ne généralise jamais seul ; quand
/// l'appelant applique, le changement est irréversible, les jetons et la
/// table ne bougent pas, et tout ce qui est douteux est refusé en bloc.
const _texte = 'Mme Sophie Verdier, 74 ans, habite à Thionville. Le Dr Martin, '
    'pneumologue, la suit.';

void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  test('généralisation répétée : pas de bouclage à 104 ans', () async {
    // Mesure P2-93 (#262) : « 104 ans » devenait « 100-104 ans », relu
    // « 104 ans », puis « 100-100-104 ans », etc. Corrigé par P2-102.
    const texte = 'Mme Odile Marchetti, 104 ans, vit à Thionville.';
    var r = await Ecluse.redact(texte, riskReference: ref);
    var tours = 0;
    while (r.risque!.suggestions.isNotEmpty && tours < 10) {
      final retenue = r.risque!.suggestions.first;
      r = appliquerGeneralisations(r, [retenue], reference: ref);
      tours++;
    }
    expect(tours, lessThan(10), reason: r.maskedText);
    expect(r.maskedText, isNot(matches(RegExp(r'\d+-\d+-\d+'))));
  });

  test('sans rapport de risque : refus explicite', () async {
    final r = await Ecluse.redact(_texte);
    expect(() => appliquerGeneralisations(r, const [], reference: ref),
        throwsA(isA<GeneralisationException>()));
  });

  test('aucune suggestion choisie : résultat inchangé', () async {
    final r = await Ecluse.redact(_texte, riskReference: ref);
    final g = appliquerGeneralisations(r, const [], reference: ref);
    expect(g.maskedText, r.maskedText);
    expect(g.mapping, r.mapping);
  });

  test('la suggestion retenue remplace chaque occurrence du QI', () async {
    final r = await Ecluse.redact(_texte, riskReference: ref);
    final retenue = r.risque!.suggestions.first;
    final g = appliquerGeneralisations(r, [retenue], reference: ref);
    expect(g.maskedText, isNot(r.maskedText));
    expect(g.maskedText, contains(qiValueLabel(ref, retenue.candidat.to!)));
    expect(retenue.positions, isNotEmpty);
    expect(g.risque, isNotNull, reason: 'rapport recalculé');
  });

  test('jetons et table intacts : la restauration reste exacte', () async {
    final r = await Ecluse.redact(_texte, riskReference: ref);
    final retenue = r.risque!.suggestions.first;
    final g = appliquerGeneralisations(r, [retenue], reference: ref);
    expect(g.mapping, r.mapping);
    for (final jeton in r.mapping.keys) {
      expect(g.maskedText, contains(jeton));
    }
    final restaure = Ecluse.restore(g.maskedText, g.mapping);
    expect(restaure, contains('Sophie Verdier'));
    expect(restaure, contains('Dr Martin'));
  });

  test('suggestion d\'un autre résultat : refus', () async {
    final a = await Ecluse.redact(_texte, riskReference: ref);
    final b = await Ecluse.redact(_texte, riskReference: ref);
    final etrangere = a.risque!.suggestions.first;
    expect(() => appliquerGeneralisations(b, [etrangere], reference: ref),
        throwsA(isA<GeneralisationException>()));
  });

  test('texte masqué modifié depuis le rapport : refus', () async {
    final r = await Ecluse.redact(_texte, riskReference: ref);
    final modifie = RedactResult(
      maskedText: 'Note. ${r.maskedText}',
      mapping: r.mapping,
      entities: r.entities,
      risque: r.risque,
    );
    final retenue = r.risque!.suggestions.first;
    expect(() => appliquerGeneralisations(modifie, [retenue], reference: ref),
        throwsA(isA<GeneralisationException>()));
  });
}
