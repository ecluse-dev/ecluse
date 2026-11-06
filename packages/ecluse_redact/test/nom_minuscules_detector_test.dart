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
    test('casse ordinaire : rien, NameDetector s\'en charge', () {
      expect(_noms('Rdv avec M. Julien Chevrier'), isEmpty);
    });

    test('casse de phrase (P2-138) : comme un texte en minuscules', () {
      expect(_noms('Rdv avec m. julien chevrier'), ['m. julien chevrier']);
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

  group('faux amis prénoms (P2-124)', () {
    test('prénom-mot courant suivi d\'un adjectif : rien', () {
      for (final texte in [
        'la plaie est rose pâle ce matin',
        'nuit blanche agitée dans le couloir',
        'infusion de violette proposée au goûter',
        'parle de la victoire finale de son équipe',
        'chambre blanche repeinte avant son retour',
      ]) {
        expect(_noms(texte), isEmpty, reason: texte);
      }
    });

    test('autre prénom suivi d\'un adjectif : le prénom seul', () {
      expect(_noms('julien agité ce matin au réveil'), ['julien']);
    });

    test('patronyme en -eux : toujours un nom', () {
      expect(_noms('appeler camille mérieux demain'), ['camille mérieux']);
    });

    test('faux ami avec civilité : toujours un nom', () {
      expect(_noms('vu mme rose vasseur hier'), ['mme rose vasseur']);
    });
  });

  group('formes de noms (P2-139)', () {
    test('initiale et patronyme après un champ ou un indice', () {
      expect(_noms('présent : t. lefèvre, excusé'), ['t. lefèvre']);
      expect(_noms('dossier suivi par j. martin'), ['j. martin']);
    });

    test('énumération en tête de ligne : pas un nom', () {
      expect(_noms('à faire :\na. vérifier le dossier\nb. appeler la cpam'),
          isEmpty);
    });

    test('ordre « nom prénom » après un indice', () {
      expect(_noms('dossier suivi par perrot olivier depuis mai'),
          ['perrot olivier']);
    });

    test('ordre « nom prénom » avec un faux ami : rien', () {
      expect(_noms('transmission : humeur claire et stable'), isEmpty);
    });

    test('particules après le prénom', () {
      expect(_noms('excusé : monsieur jean de la fontaine, retenu'),
          ['monsieur jean de la fontaine']);
      expect(
          _noms('vu monsieur jean de la part du service'), ['monsieur jean']);
    });
  });

  group('texte en capitales (P2-123)', () {
    test('civilité + prénom + nom, valeur relue dans l\'original', () {
      const texte = 'RDV AVEC M. JULIEN CHEVRIER AU SSIAD DE GRAY';
      final e = const NomMinusculesDetector().detect(texte).single;
      expect(texte.substring(e.start, e.end), 'M. JULIEN CHEVRIER');
      expect(e.value, 'M. JULIEN CHEVRIER');
    });

    test('mots outils et sigle de soin : rien', () {
      expect(_noms('MADAME LA DIRECTRICE A VALIDÉ'), isEmpty);
      expect(_noms('SCORE EVA INCHANGÉ DEPUIS HIER'), isEmpty);
    });
  });

  test('Ecluse.redact masque le nom d\'un texte en minuscules', () async {
    final r = await Ecluse.redact('rdv avec m. julien chevrier demain matin');
    expect(r.maskedText, isNot(contains('chevrier')));
    expect(r.mapping.values, contains('m. julien chevrier'));
  });
}
