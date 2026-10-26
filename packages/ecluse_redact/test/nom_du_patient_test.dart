import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Étiquettes « Nom du patient », « Nom de l'assuré »… (P2-41). Elles
/// désignent sans ambiguïté une personne, comme « Nom de naissance » (P2-36) :
/// le nom qui suit est masqué même sans « Prénom » à proximité.
void main() {
  const masques = [
    'Nom du patient : Quenelle',
    'Nom de la patiente : Quenelle',
    "Nom de l'assuré : Quenelle",
    "Nom de l'assurée : Quenelle Hector",
    'Nom du bénéficiaire : Quenelle',
    'Nom du demandeur : Quenelle',
    'Nom du salarié : Quenelle',
    "Nom de l'employé : Quenelle",
    'Nom du résident : Quenelle',
    'NOM DU PATIENT : QUENELLE',
  ];
  for (final texte in masques) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(RegExp('Quenelle|QUENELLE'))),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Nom du médicament : Aspirine': 'Aspirine',
    'Nom du fichier : Rapport': 'Rapport',
    'Nom du patient : inconnu': 'inconnu',
    'Nom du patient :': 'patient',
    'Nom du projet : Phoenix': 'Phoenix',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
    });
  }
}
