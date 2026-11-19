import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Organismes nationaux et services publics ou associatifs derrière une
/// tournure de personne (P2-229). Depuis P2-220, « le dossier de France
/// Travail » ou « à la demande de Emmaüs » devenaient `[NOM_1]` (témoin de
/// P2-226 : 83 phrases sur 96). Un organisme nommé ne désigne pas une personne :
/// il reste en clair. La liste est fermée et écrite d'après le secteur du soin
/// et du social, pas d'après le témoin ; les marques commerciales n'en font pas
/// partie.
void main() {
  const gabarits = <String>[
    'Note : le dossier de %s est transmis.',
    'Rendez-vous reporté à la demande de %s ; date à proposer.',
    'Suite à l\'entretien avec %s, le suivi est maintenu.',
    'Compte rendu : %s a confirmé la réception des pièces.',
  ];
  const organismes = <String>[
    'France Travail',
    'Pôle emploi',
    'Assurance Maladie',
    'Sécurité sociale',
    'Croix-Rouge',
    'Emmaüs',
    'Secours populaire',
    'Secours catholique',
    'Mutualité française',
    'Restos du Cœur',
    'Banque alimentaire',
    'Protection judiciaire de la jeunesse',
    'Aide sociale à l\'enfance',
    'Ameli',
    'CAF',
    'CPAM',
    'URSSAF',
    'MSA',
  ];
  for (final organisme in organismes) {
    for (final gabarit in gabarits) {
      final texte = gabarit.replaceFirst('%s', organisme);
      test('organisme en clair : $texte', () async {
        final r = await Ecluse.redact(texte);
        expect(r.entities, isEmpty, reason: r.maskedText);
        expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      });
    }
  }

  // Un organisme suivi d'un nom : on ne laisse pas fuir le nom.
  for (final texte in [
    'Note : le dossier de Emmaüs Quenelle est transmis.',
    'Suite à l\'entretien avec Croix-Rouge Brisemotte, le suivi continue.',
  ]) {
    test('organisme puis nom : le nom reste masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Quenelle')), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('Brisemotte')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Les patronymes proches d'un mot d'organisme restent masqués.
  for (final texte in [
    'Note : le dossier de Quenelle est transmis.',
    'Note : le dossier de Caf est transmis.',
    'Compte rendu : Berger a confirmé la réception des pièces.',
    'Suite à l\'entretien avec Travail Quenelle, le suivi est maintenu.',
  ]) {
    test('patronyme toujours masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.entities, isNotEmpty, reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
