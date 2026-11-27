import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-318 (reprise de P2-316) : l'avertissement des homonymes écartés ne doit
/// pas faire de bruit là où le mot n'est visiblement pas un nom, **sans rendre
/// un homonyme silencieux** (principe du 26 novembre, point 0).
///
/// 1. Un prénom connu écrit en minuscules qui est aussi un nom commun (« iris »,
///    « rose », « claire »…, liste `_fauxAmis` de `NomMinusculesDetector`) n'est
///    pas lu comme un prénom : le mot qui suit n'est pas signalé.
/// 2. Un mot qui suit un nom déjà masqué (« chloé martin est ») n'est pas
///    signalé : le nom est couvert, « est » est un verbe.
void main() {
  final motif = RegExp(r'mot pris pour un nom commun.*non masqué : à vérifier');

  Future<List<String>> avertis(String texte) async =>
      (await Ecluse.redact(texte)).warnings.where(motif.hasMatch).toList();

  group('faux ami de prénom en minuscules : pas de signal', () {
    for (final texte in [
      'iris sans particularité, examen normal.',
      'rose sans douleur ce matin.',
      'claire sans fièvre depuis hier.',
      'marguerite sans plainte.',
    ]) {
      test(texte, () async => expect(await avertis(texte), isEmpty));
    }
  });

  group('prénom ordinaire en minuscules : le signal reste', () {
    test('sophie sans', () async {
      expect(await avertis('sophie sans a rappelé le service.'), hasLength(1));
    });
    test('sophie porte (verbe conjugué)', () async {
      expect(await avertis('sophie porte a rappelé le service.'), hasLength(1));
    });
  });

  group('derrière un nom déjà masqué : pas de signal', () {
    for (final texte in [
      'rappel chloé martin est attendu en consultation.',
      'note transmise à vincent gauthier pour suite à donner.',
      'contacter ibrahim gauthier au +33 4 65 71 01 25',
    ]) {
      test(texte, () async => expect(await avertis(texte), isEmpty));
    }
  });

  // Troisième règle, hors fiche (voir la PR) : un article derrière « le dossier
  // de », « à la demande de », « l'entretien avec », suivi d'un mot à majuscule
  // (« à la demande de la Préfecture »), ouvre un groupe nominal, pas un nom de
  // personne. Sans cela, les neuf listes donnent 51 avertissements sur 400 du
  // témoin « tournures sans nom » (« la » et « le » sont aussi des patronymes).
  group('article devant un mot à majuscule : pas de signal', () {
    for (final texte in [
      "Suite à l'entretien avec la Commission, le suivi est maintenu.",
      'Reporté à la demande de la Préfecture ; une nouvelle date suivra.',
      'Note de service : le dossier de le Service est transmis.',
    ]) {
      test(texte, () async => expect(await avertis(texte), isEmpty));
    }
  });

  group('article seul ou suivi d\'un mot en minuscules : le signal reste', () {
    test('le dossier de la a été transmis', () async {
      expect(
          await avertis('Le dossier de la a été transmis hier.'), hasLength(1));
    });
    test('en minuscules, mot suivant en minuscules', () async {
      expect(
          await avertis('le dossier de la a été transmis hier.'), hasLength(1));
    });
  });
}
