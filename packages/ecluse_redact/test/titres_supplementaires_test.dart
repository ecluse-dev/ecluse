import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Titres et civilités absents de la règle de civilité (P2-46) : « Professeure »,
/// « Docteure », « Dre », « Ms », « Mgr », « Abbé ». Sans eux, un nom sans prénom
/// connu (« Zorglub Quenelle ») restait en clair.
void main() {
  const masques = [
    'Professeure Zorglub Quenelle',
    'La Professeure Quenelle',
    'Docteure Zorglub Quenelle',
    'Dre Zorglub Quenelle',
    'Dre. Quenelle',
    'Ms Zorglub Quenelle',
    'Ms. Quenelle',
    'Mgr Zorglub Quenelle',
    'Abbé Zorglub Quenelle',
    "L'abbé Quenelle",
  ];
  for (final texte in masques) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Quenelle')), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('Zorglub')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'Les msg arrivent',
    'Un abbé est venu',
    'Le mgr de la boîte',
    'La professeure est venue',
    'Une dre de bonne humeur',
  ];
  for (final texte in intacts) {
    test('aucun nom : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }
}
