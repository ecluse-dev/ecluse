import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Prénom derrière une étiquette de champ, et fiche « Prénom » avant « Nom »
/// (P2-40). P2-36 masquait le patronyme d'un « Nom : … » suivi de « Prénom »,
/// mais un prénom absent du gazetteer (« Prénom : Zorglub ») restait en clair,
/// et « Nom » précédé de « Prénom » n'était pas reconnu comme fiche.
void main() {
  const masques = {
    'Prénom : Zorglub': ['Zorglub'],
    'Prénom : Zorglub\nNom : Quenelle': ['Zorglub', 'Quenelle'],
    'Nom : Quenelle\nPrénom : Zorglub': ['Zorglub', 'Quenelle'],
    'Nom : Quenelle ; Prénom : Zorglub': ['Zorglub', 'Quenelle'],
    'Prénom usuel : Zorglub': ['Zorglub'],
    'Prénoms : Zorglub Hector Anselme': ['Zorglub', 'Hector', 'Anselme'],
    'PRÉNOM : ZORGLUB': ['ZORGLUB'],
    'Prénom de naissance : Zorglub': ['Zorglub'],
  };
  for (final MapEntry(key: texte, value: restes) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      for (final reste in restes) {
        expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      }
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Prénom : \nNom : ': 'Nom',
    'Prénom : inconnu': 'inconnu',
    'Le prénom : voir ci-dessous': 'voir',
    'Prénom du chat : Zorglub': 'Zorglub',
    'Nom : Aspirine': 'Aspirine',
    'Nom : Aspirine\n\n\n\nPrénom : ': 'Aspirine',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
    });
  }
}
