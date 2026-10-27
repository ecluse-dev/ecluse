import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Types de voie et abréviations absents de la liste (P2-49) : « 25 R. de la
/// Paix, 75002 Paris » ne masquait que « 75002 Paris » et laissait le numéro et
/// le nom de rue en clair. Le code postal + commune reste obligatoire en fin de
/// motif, ce qui limite les faux positifs sur les abréviations courtes.
void main() {
  const masques = [
    '25 R. de la Paix, 75002 Paris',
    '25 R de la Paix 75002 Paris',
    '3 pl. de la Bastille, 75004 Paris',
    '3 pl de la Bastille 75004 Paris',
    '14 sentier des Roses, 44000 Nantes',
    '8 ruelle du Four, 21000 Dijon',
    '8 traverse des Écoles, 13006 Marseille',
    '8 venelle du Puits, 35000 Rennes',
    '2 parvis de la Gare, 59000 Lille',
    '2 promenade des Anglais, 06000 Nice',
    '2 montée des Capucins, 69001 Lyon',
    '2 clos des Vignes, 21200 Beaune',
    '6 ch. des Vignes, 84000 Avignon',
    '6 imp. des Fleurs, 33000 Bordeaux',
    '6 all. des Tilleuls, 44000 Nantes',
    '6 sq. Montholon, 75009 Paris',
    '6 crs Gambetta, 33000 Bordeaux',
  ];
  for (final texte in masques) {
    test('adresse en entier : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, '[ADRESSE_1]', reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'Le 25 R de la table',
    'Chapitre 3 pl. de la liste',
    'Il a fait 6 clos de la saison',
    'Il y a 14 sentiers',
    'Page 6 ch. 3',
  ];
  for (final texte in intacts) {
    test('aucune adresse : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }
}
