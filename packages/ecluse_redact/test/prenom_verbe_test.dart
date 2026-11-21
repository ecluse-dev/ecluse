import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_redact/src/heuristics/verbes_conjugues.dart';
import 'package:test/test.dart';

/// « Prénom + verbe conjugué » (P2-235, P2-240) : sans casse, « Sophie
/// rappelle. » était rendu en un seul nom de deux mots ; le verbe était masqué,
/// puis retenu comme patronyme établi et masqué ailleurs. Exigence du mainteneur
/// (20 novembre) : aucun verbe n'est masqué. Données synthétiques.
void main() {
  const detecteur = NomMinusculesDetector();

  group('détecteur : le prénom seul', () {
    for (final (texte, fin) in [
      ('Sophie rappelle.', 6),
      ('Marc arrive.', 4),
      ('Nathalie travaille.', 8),
      ('Laurent demande.', 7),
    ]) {
      test(texte, () {
        final e = detecteur.detect(texte);
        expect(e, hasLength(1));
        expect(e.single.start, 0);
        expect(e.single.end, fin);
        expect(e.single.value, texte.substring(0, fin));
      });
    }

    test('terminaison d\'imparfait ou de conditionnel : verbe', () {
      final e = detecteur.detect('Sophie viendrait demain.');
      expect(e.single.value, 'Sophie');
      final f = detecteur.detect('Marc appelaient souvent.');
      expect(f.single.value, 'Marc');
    });

    test('faux ami + verbe : le prénom est masqué (sujet du verbe)', () {
      final e = detecteur.detect('Rose rappelle.');
      expect(e.single.value, 'Rose');
    });
  });

  group('inchangé : un mot qui n\'est pas un verbe courant', () {
    test('civilité', () {
      final e = detecteur.detect('mme odile verdier ce matin.');
      // Civilité de genre laissée hors de la mention (P2-145).
      expect(e.single.value, 'odile verdier');
    });

    test('prénom + patronyme (non verbe) en minuscules', () {
      final e = detecteur.detect('rdv avec marc loyer ce matin.');
      expect(e.single.value, 'marc loyer');
    });

    test('patronyme qui finit en « -ent » : pas un verbe', () {
      expect(estVerbeConjugue('vincent'), isFalse);
      expect(estVerbeConjugue('laurent'), isFalse);
      expect(estVerbeConjugue('clément'), isFalse);
      final e = detecteur.detect('rdv avec julien vincent ce matin.');
      expect(e.single.value, 'julien vincent');
    });

    test('verbe absent de la liste fermée : reste avec le prénom (limite)', () {
      // Limite connue (LIMITES.md) : la liste est fermée.
      expect(estVerbeConjugue('sollicite'), isFalse);
      final e = detecteur.detect('Sophie sollicite.');
      expect(e.single.value, 'Sophie sollicite');
    });
  });

  group('patronymeEtabli : le verbe n\'est pas un patronyme', () {
    test('couple prénom + verbe', () {
      expect(NomMinusculesDetector.patronymeEtabli('sophie rappelle', 0.5),
          isNull);
    });

    test('couple prénom + patronyme : établi', () {
      expect(NomMinusculesDetector.patronymeEtabli('marc loyer', 0.5), 'loyer');
    });
  });

  group('Ecluse.redact : le verbe reste lisible', () {
    test('même texte, trois reprises', () async {
      final r = await Ecluse.redact(
          'Sophie rappelle. Elle rappelle demain et il rappelle lundi.');
      expect(r.maskedText, contains('rappelle. Elle rappelle demain'));
      expect('rappelle'.allMatches(r.maskedText), hasLength(3),
          reason: r.maskedText);
    });

    test('dossier : le verbe du document suivant n\'est pas masqué', () async {
      final d = Dossier();
      await Ecluse.redact('Sophie rappelle.', dossier: d);
      final r = await Ecluse.redact('Le médecin rappelle lundi.', dossier: d);
      expect(r.maskedText, 'Le médecin rappelle lundi.');
    });

    test('le prénom reste masqué (aucune fuite)', () async {
      final r = await Ecluse.redact('Sophie rappelle.');
      expect(r.maskedText, isNot(contains('Sophie')), reason: r.maskedText);
      expect(r.maskedText, contains('rappelle'));
    });

    test('la liste est en minuscules (le détecteur lit un texte en minuscules)',
        () {
      expect(
          verbesConjuguesCourants.every((v) => v == v.toLowerCase()), isTrue);
    });
  });

  group('liste étendue (P2-242)', () {
    for (final (texte, fin) in [
      ('Sophie documente.', 6),
      ('Marc soulage.', 4),
      ('Nathalie transporte.', 8),
      ('Julien justifie.', 6),
      ('Isabelle mentionne.', 8),
    ]) {
      test(texte, () {
        final e = detecteur.detect(texte);
        expect(e, hasLength(1));
        expect(e.single.end, fin);
      });
    }

    test('formes dérivées d\'un verbe de la liste : pluriel et futur', () {
      for (final v in [
        'rappellent',
        'transportent',
        'rappellera',
        'respectera'
      ]) {
        expect(estVerbeConjugue(v), isTrue, reason: v);
      }
      for (final v in ['arrivent', 'suivent', 'finissent', 'planifiera']) {
        expect(estVerbeConjugue(v), isTrue, reason: v);
      }
    });

    test('la forme dérivée exige une base de la liste', () {
      // Aucun mot en « -ent » ou en « -ra » n'est pris pour un verbe par sa
      // seule forme : prénoms et patronymes réels.
      for (final v in [
        'laurent',
        'vincent',
        'clément',
        'parent',
        'sandra',
        'herrera',
        'louise',
        'denise',
        'barrère',
        'cabrera',
      ]) {
        expect(estVerbeConjugue(v), isFalse, reason: v);
      }
    });

    test('un patronyme derrière un prénom reste masqué', () {
      for (final texte in [
        'rdv avec marc parent ce matin.',
        'rdv avec julien herrera ce matin.',
        'rdv avec sophie louise ce matin.',
      ]) {
        final e = detecteur.detect(texte);
        expect(e.single.value, texte.substring(9, texte.length - 10),
            reason: texte);
      }
    });

    test('l\'effet en chaîne : le verbe étendu reste lisible', () async {
      final r =
          await Ecluse.redact('Sophie documente. Le médecin documente aussi.');
      expect(r.maskedText, isNot(contains('Sophie')));
      expect('documente'.allMatches(r.maskedText), hasLength(2),
          reason: r.maskedText);
    });
  });
}
