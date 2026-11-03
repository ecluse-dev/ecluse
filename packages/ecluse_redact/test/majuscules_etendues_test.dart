import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Majuscules initiales et lettres hors du jeu français usuel dans un nom
/// (P2-33) : voyelles accentuées espagnoles et portugaises, ligature Œ, Å,
/// lettres polonaises, tchèques, turques et vietnamiennes. Avant ce correctif,
/// seule la partie du nom commençant par une majuscule du jeu restreint était
/// détectée : « François Œil » donnait `[NOM_1] Œil`, le patronyme restait en clair.
const _noms = <String>[
  'Mme Álvarez',
  'M. Óscar Núñez',
  'Mme Úrsula Ñandú',
  'Mme Íngrid Sánchez',
  'M. François Œil',
  'Mme Zoë Ångström',
  'M. Łukasz Kowalski',
  'Mme Nguyễn Thị Hoa',
  'M. İbrahim Şahin',
  'Mme Žofie Černá',
  'M. Bjørn Æsøy',
];

void main() {
  for (final personne in _noms) {
    test(personne, () async {
      final t = 'Rendez-vous avec $personne demain.';
      final r = await Ecluse.redact(t);
      expect(r.maskedText,
          matches(RegExp(r'^Rendez-vous avec (Mme |M\. )?\[NOM_1\] demain\.$')),
          reason: 'nom non masqué en entier : "${r.maskedText}"');
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });
  }

  test('un mot capitalisé hors civilité ne devient pas un nom à lui seul',
      () async {
    const t = 'Le mot Œuvre et le mot Ångström désignent des choses.';
    final r = await Ecluse.redact(t);
    expect(r.maskedText, t);
    expect(r.mapping, isEmpty);
  });
}
