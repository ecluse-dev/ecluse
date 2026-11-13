import 'package:ecluse_reid/src/qi_extraction.dart';
import 'package:test/test.dart';

/// P2-165 : une durée n'est pas un âge. Sonde du 13 novembre (relecture de
/// P2-159) : « deux ans plus tard », « au bout de cinq ans », « un contrat de
/// trois ans » sortaient comme des âges, en lettres comme en chiffres ; corpus
/// témoin de durées : 400 extractions à tort sur 400 documents. Un âge à tort
/// grossit le risque calculé et propose une généralisation sans objet.
void main() {
  const durees = [
    'Le dossier a été rouvert deux ans plus tard.',
    'Le dossier a été rouvert 2 ans plus tard.',
    'La panne s’était produite dix ans auparavant.',
    'Elle était revenue 3 ans plus tôt.',
    'Au bout de cinq ans, la convention a été dénoncée.',
    'Au bout de 5 ans, la convention a été dénoncée.',
    'Voilà dix ans que la procédure est en place.',
    'Cela fait 20 ans que le logiciel existe.',
    'Ça fait trois ans.',
    'Un contrat de trois ans a été proposé.',
    'Un bail de 9 ans a été signé.',
    'Un mandat de cinq ans.',
    'Le poste exige trois ans d’ancienneté.',
    'Le poste exige 5 ans d\'expérience.',
    'Condamné à trois ans de prison.',
    'Après dix ans de suivi.',
    'D’ici deux ans, le service déménage.',
  ];
  for (final texte in durees) {
    test('durée, pas un âge : $texte', () {
      expect(extractAge(texte), isEmpty);
    });
  }

  // Un vrai âge reste lu : ne jamais perdre un âge pour écarter une durée
  // (un âge manqué sous-estime le risque).
  const ages = {
    'Enfant âgé de deux ans.': '2',
    'Patiente de quatre-vingts ans.': '80',
    'M. Martin, 72 ans, retraité.': '72',
    'Suivi depuis ses deux ans.': '2',
    'Homme de 72 ans de sexe masculin.': '72',
    'Femme de 68 ans d’origine bretonne.': '68',
    'Opérée à 72 ans après une chute.': '72',
    'Il a eu 40 ans avant son départ.': '40',
    'Mme Durand a soixante-douze ans.': '72',
    'Pour les 80 ans de Mme Martin.': '80',
    'Un patient de trois ans.': '3',
  };
  for (final MapEntry(key: texte, value: age) in ages.entries) {
    test('âge lu : $texte', () {
      expect(extractAge(texte).map((q) => q.value), [age]);
    });
  }
}
