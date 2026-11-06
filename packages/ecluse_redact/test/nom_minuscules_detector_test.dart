import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Noms dans un texte sans aucune majuscule (P2-119). Mesure P2-117 : 100 %
/// de fuite des noms sur un texte en minuscules avant ce détecteur.
List<String> _noms(String texte) => [
      for (final e in const NomMinusculesDetector().detect(texte))
        texte.substring(e.start, e.end),
    ];

void main() {
  group('détectés', () {
    test('civilité + prénom + nom, avec la civilité', () {
      expect(_noms('rdv avec m. julien chevrier au ssiad de gray'),
          ['m. julien chevrier']);
    });

    test('civilité + patronyme seul', () {
      expect(_noms('vu ce jour par le dr lefèvre'), ['dr lefèvre']);
      expect(_noms('appeler madame vasseur demain'), ['madame vasseur']);
    });

    test('prénom connu + nom, sans civilité', () {
      expect(_noms('julien chevrier a appelé'), ['julien chevrier']);
    });

    test('prénom accentué et composé', () {
      expect(_noms('hélène martin est arrivée'), ['hélène martin']);
      expect(_noms('anne-sophie roux rappellera'), ['anne-sophie roux']);
    });

    test('positions exactes', () {
      const texte = 'note : mme karine vasseur, admise';
      final e = const NomMinusculesDetector().detect(texte).single;
      expect(texte.substring(e.start, e.end), 'mme karine vasseur');
      expect(e.type, EntityType.nom);
      expect(e.value, 'mme karine vasseur');
    });
  });

  group('rejetés', () {
    test('texte avec une majuscule : rien, NameDetector s\'en charge', () {
      expect(_noms('Rdv avec m. julien chevrier'), isEmpty);
    });

    test('civilité suivie d\'un mot outil', () {
      expect(_noms('madame la directrice a validé'), isEmpty);
      expect(_noms('monsieur est arrivé en retard'), isEmpty);
    });

    test('« me » est le pronom, pas maître', () {
      expect(_noms('il me dit que tout va bien'), isEmpty);
    });

    test('« eva » est l\'échelle, pas le prénom', () {
      expect(_noms('score eva inchangé depuis hier'), isEmpty);
    });

    test('pas de nom à travers une ponctuation', () {
      expect(_noms('vu par julien. chevrier passera'), isEmpty);
    });
  });

  test('Ecluse.redact masque le nom d\'un texte en minuscules', () async {
    final r = await Ecluse.redact('rdv avec m. julien chevrier demain matin');
    expect(r.maskedText, isNot(contains('chevrier')));
    expect(r.mapping.values, contains('m. julien chevrier'));
  });
}
