import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Patronyme seul derrière un contexte de personne (P2-220). Sans civilité ni
/// prénom connu, « le dossier de Quenelle » restait en clair quand le nom
/// n'avait pas été établi par une pièce précédente (mesure P2-218 : 112
/// mentions sur 116 manquées, document par document). L'indice est la
/// tournure : « dossier de », « à la demande de », « entretien avec » devant
/// le mot, « a confirmé » derrière lui.
///
/// Noms inventés, absents du gazetteer des prénoms et du référentiel des
/// communes : seule la tournure peut les faire détecter.
void main() {
  const masques = <String, String>{
    'Note de service : le dossier de Quenelle est transmis à l\'équipe.':
        'Quenelle',
    'Pièces jointes au dossier de Brisemotte : attestation.': 'Brisemotte',
    'Rendez-vous reporté à la demande de Quenelle ; date à proposer.':
        'Quenelle',
    'Rendez-vous reporté à la demande de QUENELLE ; date à proposer.':
        'QUENELLE',
    'Suite à l\'entretien avec Brisemotte, le suivi est maintenu.':
        'Brisemotte',
    'Entretien avec Brisemotte le 3 mars.': 'Brisemotte',
    'Compte rendu : Quenelle a confirmé la réception des pièces.': 'Quenelle',
    'Quenelle a confirmé le rendez-vous.': 'Quenelle',
    // Nom composé et particule : toute l'unité de nom est masquée.
    'Le dossier de Le Gall est transmis.': 'Gall',
    'Le dossier de Quenelle-Brisemotte est transmis.': 'Quenelle',
    // Après la tournure, l'apostrophe typographique ou droite d'un nom.
    'À la demande de O’Quenelle, le dossier est clos.': 'Quenelle',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('un nom établi par la tournure est masqué aussi ailleurs dans le texte',
      () async {
    const texte = 'Le dossier de Quenelle est transmis.\n'
        'Le service rappelle que Quenelle est joignable le matin.';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, isNot(contains('Quenelle')), reason: r.maskedText);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  const intacts = <String, String>{
    // Mot commun en minuscules.
    'Note de service : le dossier de presse est transmis.': 'presse',
    'Suite à l\'entretien avec succès, le suivi est maintenu.': 'succès',
    // Nom de commune.
    'Rendez-vous reporté à la demande de Paris ; date à proposer.': 'Paris',
    'Le dossier de Besançon est transmis.': 'Besançon',
    // Organisme précédé de son article : le mot qui suit « de » est minuscule.
    'Le dossier de la Mairie est transmis.': 'Mairie',
    'Suite à l\'entretien avec le Département, le suivi est maintenu.':
        'Département',
    // Sujet qui est un organisme.
    'Compte rendu : La Mairie a confirmé la réception.': 'Mairie',
    'Compte rendu : Le Département a confirmé la réception.': 'Département',
    'Compte rendu : L\'Inspection a confirmé la réception.': 'Inspection',
    // Début de phrase : le mot n'est pas précédé de la tournure.
    'Dossier de suivi. Le service a confirmé.': 'suivi',
    // Un mot neutre n'est jamais un nom.
    'Rendez-vous à la demande de Tous ; date à proposer.': 'Tous',
    // Pronom sujet.
    'Il a confirmé le rendez-vous.': 'confirmé',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('aucune valeur du texte dans les avertissements', () async {
    final r = await Ecluse.redact('Le dossier de Quenelle est transmis.');
    for (final w in r.warnings) {
      expect(w, isNot(contains('Quenelle')));
    }
  });
}
