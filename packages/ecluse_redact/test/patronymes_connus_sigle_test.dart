import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-253 : un prénom ou un nom écrit avec une majuscule initiale (« Eva ») que
/// sa forme en capitales rend sigle exclu (« EVA », échelle visuelle analogique)
/// n'est plus refusé par `PatronymesConnus`, et le refus d'une entrée ne vaut
/// plus pour toute la liste d'une application qui a une patiente prénommée Eva.
/// Seule la forme **tout en capitales** reste refusée. Noms synthétiques.
void main() {
  test('« Eva » est accepté, « EVA » seul reste refusé (motif sigleExclu)', () {
    expect(PatronymesConnus(const ['Eva', 'Verdier']).length, 2);
    expect(
        () => PatronymesConnus(const ['EVA']),
        throwsA(isA<PatronymesRefusesException>().having((e) => e.parMotif,
            'parMotif', {MotifPatronymeRefuse.sigleExclu: 1})));
    // La liste d'un dossier contenant « Eva » n'est plus refusée en bloc.
    expect(() => PatronymesConnus(const ['Eva', 'HTA']),
        throwsA(isA<PatronymesRefusesException>()));
  });

  test('autres sigles exclus : majuscule initiale acceptée, capitales refusées',
      () {
    for (final nom in ['Hta', 'Irm', 'Asd']) {
      expect(PatronymesConnus([nom]).length, 1, reason: nom);
    }
    for (final sigle in ['HTA', 'IRM', 'ASD']) {
      expect(() => PatronymesConnus([sigle]),
          throwsA(isA<PatronymesRefusesException>()),
          reason: sigle);
    }
  });

  test('« Eva Martin est venue » : « Eva Martin » masqué dès la première pièce',
      () async {
    final d = Dossier(patronymesConnus: PatronymesConnus(const ['Eva']));
    final r = await Ecluse.redact('Eva Martin est venue.', dossier: d);
    expect(r.maskedText, isNot(contains('Eva')));
    expect(r.maskedText, isNot(contains('Martin')));
    expect(Ecluse.restore(r.maskedText, r.mapping), 'Eva Martin est venue.');
  });

  test('« Eva » seule en début de phrase est masquée (sur-masquage assumé)',
      () async {
    final d = Dossier(patronymesConnus: PatronymesConnus(const ['Eva']));
    final r =
        await Ecluse.redact('Le dossier de Eva est transmis.', dossier: d);
    expect(r.maskedText, isNot(contains('Eva')));
  });

  test('« EVA 6/10 » n\'est jamais masqué à cause de la liste', () async {
    final d = Dossier(patronymesConnus: PatronymesConnus(const ['Eva']));
    for (final texte in [
      'EVA 6/10 à l\'arrivée.',
      'Douleur évaluée : EVA 3/10.',
      'EVA : 7 sur 10 ce matin.',
    ]) {
      final r = await Ecluse.redact(texte, dossier: d);
      expect(r.maskedText, texte, reason: texte);
    }
  });

  test('même sortie qu\'un dossier sans liste sur un texte sans « Eva »',
      () async {
    const texte = 'Rendez-vous demain. EVA 4/10, tension stable.';
    final sans = await Ecluse.redact(texte, dossier: Dossier());
    final avec = await Ecluse.redact(texte,
        dossier: Dossier(patronymesConnus: PatronymesConnus(const ['Eva'])));
    expect(avec.maskedText, sans.maskedText);
  });
}
