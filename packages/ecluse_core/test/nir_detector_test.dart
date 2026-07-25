import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

void main() {
  const detector = NirDetector();

  group('NirDetector — NIR valides', () {
    test('détecte un NIR compact à clé valide', () {
      final entities = detector.detect(
        'Le patient 185057800608491 est arrivé ce matin.',
      );
      expect(entities, hasLength(1));
      expect(entities.single.type, EntityType.nir);
      expect(entities.single.value, '185057800608491');
      expect(entities.single.confidence, 1.0);
    });

    test('détecte un NIR avec espaces (format courant)', () {
      final entities = detector.detect('NIR : 1 85 05 78 006 084 91');
      expect(entities, hasLength(1));
      expect(entities.single.value, '1 85 05 78 006 084 91');
    });

    test('détecte un NIR avec espaces multiples et une tabulation', () {
      // Espacement irrégulier typique d'un document recopié à la main ou
      // d'un export PDF/tableau — un séparateur simple par groupe ne
      // suffit pas, il faut neutraliser toute la séquence d'espaces.
      const text = 'NIR : 1  85 05\t78   006 084 91.';
      final entities = detector.detect(text);
      expect(entities, hasLength(1));
      // La valeur masquée préserve l'espacement d'origine (nécessaire pour
      // que `Ecluse.restore` reproduise le texte exactement).
      expect(entities.single.value, '1  85 05\t78   006 084 91');
      expect(
        text.substring(entities.single.start, entities.single.end),
        entities.single.value,
      );
    });

    test('détecte un NIR avec espaces insécables (export bureautique)', () {
      const nbsp = '\u00A0';
      final text =
          '1$nbsp' '85$nbsp' '05$nbsp' '78$nbsp' '006$nbsp' '084$nbsp' '91';
      final entities = detector.detect(text);
      expect(entities, hasLength(1));
      expect(entities.single.value, text);
    });

    test('détecte un NIR avec points', () {
      final entities = detector.detect('Sécu 2.94.02.75.017.412.42 ok');
      expect(entities, hasLength(1));
    });

    test('détecte un NIR avec tirets', () {
      final entities = detector.detect('1-63-01-25-001-234-14');
      expect(entities, hasLength(1));
    });

    test('détecte un NIR corse 2A', () {
      final entities = detector.detect('Née à Ajaccio : 1 95 07 2A 001 023 79');
      expect(entities, hasLength(1));
      expect(entities.single.confidence, 1.0);
    });

    test('détecte un NIR corse 2B', () {
      final entities = detector.detect('Dossier 2 87 11 2B 112 045 70 clos.');
      expect(entities, hasLength(1));
    });

    test('détecte un NIR corse en minuscules (2a)', () {
      final entities = detector.detect('1 95 07 2a 001 023 79');
      expect(entities, hasLength(1));
    });

    test('détecte plusieurs NIR dans le même texte', () {
      final entities = detector.detect(
        'Transfert de 185057800608491 vers 294027501741242 validé.',
      );
      expect(entities, hasLength(2));
    });

    test('les positions start/end correspondent au texte source', () {
      const text = 'ID = 185057800608491.';
      final e = detector.detect(text).single;
      expect(text.substring(e.start, e.end), e.value);
    });
  });

  group('NirDetector — rejets', () {
    test('rejette un NIR à clé de contrôle invalide', () {
      // Même corps que 185057800608491, clé décalée de 1.
      expect(detector.detect('185057800608492'), isEmpty);
    });

    test('rejette un mois de naissance impossible (13)', () {
      expect(detector.detect('1 85 13 78 006 084 91'), isEmpty);
    });

    test('rejette un numéro d\'ordre 000', () {
      expect(detector.detect('1 85 05 78 006 000 91'), isEmpty);
    });

    test('ne matche pas à l\'intérieur d\'une séquence plus longue', () {
      // 17 chiffres : le NIR valide est enchâssé, il ne doit pas sortir.
      expect(detector.detect('9918505780060849177'), isEmpty);
    });

    test('ignore un texte sans NIR', () {
      expect(
        detector.detect('Réunion de service à 14h, salle 203.'),
        isEmpty,
      );
    });

    test('ignore un numéro de téléphone français', () {
      expect(detector.detect('Appelez le 06 12 34 56 78.'), isEmpty);
    });

    test(
        'rejette "1 48 03 69 256 042 88" quel que soit l\'espacement '
        '(clé de contrôle invalide, pas un défaut de normalisation)', () {
      // Corps 1480369256042 : la clé attendue est 89, pas 88. La
      // normalisation des espaces (voir tests ci-dessus) ne doit jamais
      // faire passer un NIR dont la clé est structurellement fausse — sinon
      // le taux de faux positifs qui justifie la confiance 1.0 s'effondre.
      expect(detector.detect('1 48 03 69 256 042 88'), isEmpty);
      expect(detector.detect('1  48   03 69\t256 042 88'), isEmpty);
    });

    test('texte vide', () {
      expect(detector.detect(''), isEmpty);
    });
  });
}
