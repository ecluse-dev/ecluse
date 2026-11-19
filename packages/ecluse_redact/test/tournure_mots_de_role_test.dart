import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Mots de rôle et de parenté derrière une tournure de personne (P2-227).
/// Depuis P2-220, tout mot à majuscule derrière « le dossier de », « à la
/// demande de », « l'entretien avec » ou devant « a confirmé » était pris pour
/// un patronyme : « Madame a confirmé », « l'entretien avec Mère » devenaient
/// `[NOM_1]` (témoin de P2-226 : 96 phrases sur 96). Ces mots désignent une
/// personne sans la nommer : ils restent en clair.
///
/// Les cas mêlent des mots de la liste et des mots que seule la terminaison de
/// métier reconnaît (« Orthophoniste », « Ergothérapeute »), plus des formes
/// que le témoin de P2-226 ne contient pas (« Famille », « Maman », « Kiné »).
void main() {
  const intacts = <String, String>{
    'Compte rendu : Madame a confirmé la réception des pièces.': 'Madame',
    'Compte rendu : Monsieur a confirmé la réception.': 'Monsieur',
    'Suite à l\'entretien avec Mère, le suivi est maintenu.': 'Mère',
    'Suite à l\'entretien avec Famille, le suivi est maintenu.': 'Famille',
    'Rendez-vous reporté à la demande de Fils ; date à proposer.': 'Fils',
    'Rendez-vous reporté à la demande de Maman ; date à proposer.': 'Maman',
    'Note : le dossier de Tuteur est transmis.': 'Tuteur',
    'Compte rendu : Infirmière a confirmé la réception.': 'Infirmière',
    'Suite à l\'entretien avec Kiné, le suivi est maintenu.': 'Kiné',
    'Suite à l\'entretien avec Grand-mère, le suivi est maintenu.':
        'Grand-mère',
    'Compte rendu : Belle-sœur a confirmé la réception.': 'Belle-sœur',
    // Sans accent ni œ, et en capitales.
    'Suite à l\'entretien avec Soeur, le suivi est maintenu.': 'Soeur',
    'Compte rendu : MERE a confirmé la réception.': 'MERE',
    // Terminaison de métier, hors de la liste.
    'Suite à l\'entretien avec Orthophoniste, le suivi est maintenu.':
        'Orthophoniste',
    'Compte rendu : Ergothérapeute a confirmé la réception.': 'Ergothérapeute',
    'Le dossier de Psychiatre est transmis.': 'Psychiatre',
  };
  for (final MapEntry(key: texte, value: mot) in intacts.entries) {
    test('mot de rôle en clair : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(mot), reason: r.maskedText);
      expect(r.entities, isEmpty, reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Mot de rôle suivi d'un nom : le nom reste masqué, le rôle reste lisible.
  const nomApresRole = <String, (String, String)>{
    'Suite à l\'entretien avec Tante Quenelle, le suivi est maintenu.': (
      'Tante',
      'Quenelle'
    ),
    'Le dossier de Tuteur Brisemotte est transmis.': ('Tuteur', 'Brisemotte'),
  };
  for (final MapEntry(key: texte, value: (role, nom)) in nomApresRole.entries) {
    test('rôle en clair, nom masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(role), reason: r.maskedText);
      expect(r.maskedText, isNot(contains(nom)), reason: r.maskedText);
      final masque = r.entities.single;
      expect(texte.substring(masque.start, masque.end), nom);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Les patronymes, y compris ceux qui ressemblent à un nom commun, restent
  // masqués (familles de patronymes du témoin de P2-226).
  const toujoursMasques = <String, String>{
    'Compte rendu : Berger a confirmé la réception.': 'Berger',
    'Suite à l\'entretien avec Boulanger, le suivi est maintenu.': 'Boulanger',
    'Le dossier de Quenelle est transmis.': 'Quenelle',
    'Compte rendu : Laval a confirmé la réception.': 'Laval',
  };
  for (final MapEntry(key: texte, value: nom) in toujoursMasques.entries) {
    test('patronyme toujours masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(nom)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
