import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Valeur « vide » d'un champ étiqueté (P2-84) : « Prénom : Non renseigné »
/// masquait « Non » et laissait « renseigné ». Liste fermée, comparée au mot
/// entier ; un vrai nom derrière la même étiquette reste masqué.
void main() {
  const vides = [
    'Nom : Non renseigné\nPrénom : Non renseigné',
    'Prénom : Inconnu',
    'Prénom : Néant',
    'Prénom : Sans objet',
    "Nom d'usage : Néant",
    'Nom de naissance : Identique',
    'Nom de naissance : Idem',
    'Nom du patient : Confidentiel',
    'Nom du patient : Anonymisé',
    'Nom du demandeur : Non précisé',
    'Nom du salarié : A compléter',
    'Nom du salarié : À compléter',
    'Prénom : Anonyme',
    'Prénom : Exemple',
    'Prénom : TEST',
  ];
  for (final texte in vides) {
    test('aucun nom : ${texte.replaceAll('\n', ' ⏎ ')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }

  const noms = {
    'Nom : Zxqvlorn\nPrénom : Marie': 'Zxqvlorn',
    'Prénom : Marie': 'Marie',
    'Prénom : Annabelle Sans': 'Annabelle',
    'Nom du patient : Zxqvlorn': 'Zxqvlorn',
    'Prénom : Nonna': 'Nonna',
    'Prénom : Idemar': 'Idemar',
    'Nom de naissance : Testard': 'Testard',
    'Prénom : Test-Marc': 'Test-Marc',
  };
  for (final MapEntry(key: texte, value: nom) in noms.entries) {
    test('masqué : ${texte.replaceAll('\n', ' ⏎ ')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(nom)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
