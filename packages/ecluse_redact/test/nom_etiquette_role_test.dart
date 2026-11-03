import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Nom derrière une étiquette de rôle sans ambiguïté (P2-55) : « Patient : »,
/// « Résident : », « Bénéficiaire : », « Usager : », « Personne de confiance : »,
/// « Personne à prévenir : », « Médecin traitant : ». Un prénom hors gazetteer
/// y échappait. Deux mots au moins en majuscule initiale : une valeur d'un
/// seul mot (« Patient : Oui ») est trop souvent un état, non un nom.
void main() {
  const masques = {
    'Patient : Zorglub Quenelle, 82 ans': 'Quenelle',
    'Patient: Zorglub Quenelle': 'Quenelle',
    'Patiente : Zorglub Quenelle': 'Quenelle',
    'Patient(e) : Zorglub Quenelle': 'Quenelle',
    'Résident : Zorglub Quenelle': 'Quenelle',
    'Bénéficiaire : Zorglub Quenelle': 'Quenelle',
    'Usager : Quenelle Zorglub': 'Quenelle',
    'Usagère : Zorglub Quenelle': 'Quenelle',
    'Personne accompagnée : Zorglub Quenelle': 'Quenelle',
    'Personne de confiance : Zorglub Quenelle': 'Quenelle',
    'Personne à prévenir : Zorglub Quenelle (fille)': 'Quenelle',
    'Médecin traitant : Zorglub Quenelle': 'Quenelle',
    'PATIENT : QUENELLE ZORGLUB': 'QUENELLE',
    'Résident : Zorglub de la Quenelle': 'Quenelle',
    'Dossier\nPatient : Zorglub Quenelle\nÂge : 82': 'Quenelle',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('Zorglub')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Patient : Oui': 'Oui',
    'Patient : Non renseigné': 'Non renseigné',
    'Patient : Aucun suivi': 'Aucun suivi',
    'Patient : en attente': 'en attente',
    'Patient : Voir dossier': 'Voir dossier',
    'Bénéficiaire : Association Tutélaire': 'Association',
    'Médecin traitant : Cabinet Médical': 'Cabinet',
    'Médecin traitant : Service Gériatrie': 'Service',
    'Le patient : Diabétique de type 2': 'Diabétique',
    'Patient Zorglub': 'Patient',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Un établissement reste un établissement : jamais un nom de personne.
  const etablissements = [
    'Résident : Foyer Les Lilas',
    'Usager : Centre Hospitalier',
    'Patient : EHPAD Les Lilas',
  ];
  for (final texte in etablissements) {
    test('établissement, pas un nom : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('[NOM')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
