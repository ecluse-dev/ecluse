import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Suggestions de généralisation positionnées dans le rapport de risque
/// (P2-91). Elles sont proposées, jamais appliquées : le texte masqué reste
/// celui d'avant, et chaque position désigne bien le QI dans ce texte.
const _texte = 'Mme Sophie Verdier, 74 ans, habite à Thionville. Le Dr Martin, '
    'pneumologue, la suit.';

void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  test('le texte masqué ne change pas avec les suggestions', () async {
    final sans = await Ecluse.redact(_texte);
    final avec = await Ecluse.redact(_texte, riskReference: ref);
    expect(avec.maskedText, sans.maskedText);
    expect(avec.mapping, sans.mapping);
  });

  test('profession, lieu et âge : au moins une suggestion, la retenue en tête',
      () async {
    final r = await Ecluse.redact(_texte, riskReference: ref);
    final rapport = r.risque!;
    expect(rapport.evaluation.statut, EvaluationStatut.evalue);
    expect(rapport.suggestions, isNotEmpty);
    expect(rapport.suggestions.first.candidat.retenu, isTrue);
    expect(rapport.suggestions.where((s) => s.candidat.retenu), hasLength(1));
  });

  test('chaque suggestion fait remonter F et désigne son QI', () async {
    final r = await Ecluse.redact(_texte, riskReference: ref);
    for (final s in r.risque!.suggestions) {
      final c = s.candidat;
      expect(c.to, isNotNull);
      expect(c.fAfter, greaterThan(c.fBefore));
      expect(s.positions, isNotEmpty, reason: '${c.from}');
      for (final p in s.positions) {
        expect(p.qi, c.from);
        expect(r.maskedText.substring(p.start, p.end), p.text);
      }
    }
  });

  test('aucun quasi-identifiant : aucune suggestion', () async {
    final r = await Ecluse.redact('Réunion de service demain matin.',
        riskReference: ref);
    expect(r.risque!.evaluation.statut, EvaluationStatut.aucunQi);
    expect(r.risque!.suggestions, isEmpty);
  });

  test('sans référence : pas de rapport, donc pas de suggestion', () async {
    final r = await Ecluse.redact(_texte);
    expect(r.risque, isNull);
  });
}
