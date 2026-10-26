import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Civilités abrégées avec point (P2-35). « Mme. » et « Mlle. » ne
/// déclenchaient pas la règle de civilité (seuls « Mme » et « Mlle » sans
/// point étaient reconnus) : le patronyme d'un prénom inconnu ou composé de
/// plusieurs mots restait en clair.
void main() {
  const cas = {
    'Contact : Mme. Sophie Mac Donald': 'Mac Donald',
    'Contact : Mme. Zorglub Quenelle': 'Quenelle',
    'Contact : Mlle. Zorglub Quenelle': 'Quenelle',
    'Contact : Mme Zorglub Quenelle': 'Quenelle',
    'Contact : Mlle Zorglub Quenelle': 'Quenelle',
  };
  for (final MapEntry(key: texte, value: reste) in cas.entries) {
    test('« $texte » : aucun reste de nom en clair', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste.split(' ').last)),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
