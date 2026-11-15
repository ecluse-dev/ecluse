import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Sonde du 15 novembre sur `main` (P2-190) : `Ecluse.restore` ne signale
/// jamais qu'un jeton attendu n'a pas pu être restauré. Quatre déformations
/// possibles d'une réponse de LLM, dont trois laissent un jeton « de forme
/// connue » dans le texte final sans qu'aucun appelant ne puisse s'en
/// apercevoir — risque de fuite résiduelle silencieuse si ce texte est
/// affiché tel quel. `restoreAvecRapport` rend, en plus du texte restauré,
/// la liste de ces jetons non restaurés (type et numéro seulement, jamais
/// de valeur — voir la doc de [JetonNonRestaure]).
void main() {
  late TableDeCorrespondance carte;
  setUp(() async {
    final r = await Ecluse.redact('M. Jean Dupont a appelé le 01 99 00 12 34.');
    carte = r.mapping;
  });

  group('restoreAvecRapport : les quatre cas sondés le 15 novembre', () {
    test('jeton sans crochets (le LLM les a retirés) : signalé', () {
      final (texte, jetons) =
          Ecluse.restoreAvecRapport('NOM_1 a appelé.', carte);
      // Non restauré par conception : un jeton sans crochets est
      // indiscernable d'un mot ordinaire pour restore(), donc le texte
      // reste tel quel ; seul le rapport change.
      expect(texte, 'NOM_1 a appelé.');
      expect(jetons, [const JetonNonRestaure('NOM', '1')]);
    });

    test('jeton à numéro inventé, jamais émis par redact() : signalé', () {
      final (texte, jetons) =
          Ecluse.restoreAvecRapport('[NOM_3] a appelé.', carte);
      expect(texte, '[NOM_3] a appelé.');
      expect(jetons, [const JetonNonRestaure('NOM', '3')]);
    });

    test('libellé traduit par le LLM (NAME au lieu de NOM) : signalé', () {
      final (texte, jetons) =
          Ecluse.restoreAvecRapport('[NAME_1] a appelé.', carte);
      expect(texte, '[NAME_1] a appelé.');
      expect(jetons, [const JetonNonRestaure('NAME', '1')]);
    });

    test(
        'échappement Markdown incomplet (\\[NOM_1]) : restauré normalement, '
        'rien à signaler (P2-72, non-régression)', () {
      final (texte, jetons) = Ecluse.restoreAvecRapport(r'a\[NOM_1] b', carte);
      expect(texte, r'a\Jean Dupont b');
      expect(jetons, isEmpty);
    });
  });

  test('aucun faux positif sur un texte sans jeton résiduel', () {
    final (texte, jetons) =
        Ecluse.restoreAvecRapport('[NOM_1] a appelé le [TELEPHONE_1].', carte);
    expect(texte, 'Jean Dupont a appelé le 01 99 00 12 34.');
    expect(jetons, isEmpty);
  });

  test('plusieurs jetons non restaurés dans le même texte : tous signalés', () {
    final (texte, jetons) = Ecluse.restoreAvecRapport(
      '[NOM_1] (en fait [NOM_9]) a appelé NOM_2.',
      carte,
    );
    expect(texte, 'Jean Dupont (en fait [NOM_9]) a appelé NOM_2.');
    expect(jetons, [
      const JetonNonRestaure('NOM', '9'),
      const JetonNonRestaure('NOM', '2'),
    ]);
  });

  test(
      'libellé inconnu sans crochets (NAME_2) : pas de forme connue, non signalé',
      () {
    // Sans crochets, un libellé non reconnu par entityTypeLabel est
    // indiscernable d'un mot ordinaire contenant un chiffre : seuls les
    // libellés qu'Écluse émet réellement sont cherchés hors crochets.
    final (texte, jetons) =
        Ecluse.restoreAvecRapport('NAME_2 a appelé.', carte);
    expect(texte, 'NAME_2 a appelé.');
    expect(jetons, isEmpty);
  });

  test('ne restaure jamais par approximation ([NOM_1] ne matche pas [NOM_10])',
      () async {
    final r = await Ecluse.redact('M. Jean Dupont.');
    final (texte, jetons) = Ecluse.restoreAvecRapport('[NOM_10]', r.mapping);
    expect(texte, '[NOM_10]');
    expect(jetons, [const JetonNonRestaure('NOM', '10')]);
  });

  test('restore() seul (sans rapport) est inchangé par cette tâche', () {
    expect(Ecluse.restore('NOM_1 [NOM_3] [NAME_1]', carte),
        'NOM_1 [NOM_3] [NAME_1]');
  });

  group('JetonNonRestaure', () {
    test('égalité par valeur, jamais de champ valeur', () {
      const a = JetonNonRestaure('NOM', '3');
      const b = JetonNonRestaure('NOM', '3');
      expect(a, equals(b));
      expect(a.toString(), 'NOM_3');
    });
  });
}
