import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = AdresseDetector();

  group('AdresseDetector', () {
    test('numéro + voie + code postal + commune', () {
      final entities =
          detector.detect('Il habite 12 rue des Lilas, 75015 Paris.');
      expect(entities, hasLength(1));
      expect(entities.single.value, contains('75015 Paris'));
      expect(entities.single.value, contains('rue des Lilas'));
    });

    test('sans code postal -> non détecté', () {
      final entities = detector.detect('Il habite rue des Lilas à Paris.');
      expect(entities, isEmpty);
    });

    test('commune composée', () {
      final entities = detector
          .detect('14 avenue Foch, 54000 Nancy-Saint-Nicolas est proche.');
      expect(entities, hasLength(1));
    });

    test('code postal + commune seul, sans numéro ni type de voie', () {
      final entities = detector.detect('70160 Saint Rémy en Comté');
      expect(entities, hasLength(1));
      expect(entities.single.value, '70160 Saint Rémy en Comté');
      expect(entities.single.confidence, 0.55);
    });

    test('code postal isolé, sans commune qui suit -> non détecté', () {
      final entities = detector.detect('Il habite dans le 70160.');
      expect(entities, isEmpty);
    });

    test(
        'adresse complète + adresse code postal/commune seule sur une '
        'autre ligne -> deux entités distinctes', () {
      final entities = detector.detect(
        '8 rue Robert Roy 70170 Port sur Saône\n'
        '70160 Saint Rémy en Comté',
      );
      expect(entities, hasLength(2));
      expect(entities[0].value, '8 rue Robert Roy 70170 Port sur Saône');
      expect(entities[0].confidence, 0.7);
      expect(entities[1].value, '70160 Saint Rémy en Comté');
      expect(entities[1].confidence, 0.55);
    });

    group('dosage (nombre + unité de mesure) — bug corrigé', () {
      // "10000 UI" a la même forme syntaxique qu'un "code postal seul" :
      // 5 chiffres + mot capitalisé. Une unité de mesure ne doit jamais
      // être avalée comme s'il s'agissait d'une commune : effacer une
      // donnée clinique (posologie) est plus grave qu'un faux négatif.
      test('"innohep 10000 UI" -> aucune adresse détectée', () {
        final entities =
            detector.detect('Prescription : innohep 10000 UI en injection.');
        expect(entities, isEmpty);
      });

      test(
          'autres unités courantes après un nombre à 5 chiffres -> aucune '
          'adresse détectée', () {
        const dosages = [
          'Perfusion de 10000 ML sur 24 heures.',
          'Dose de 20000 UI administrée ce matin.',
          'Poids du colis : 12000 KG.',
        ];
        for (final sentence in dosages) {
          expect(
            detector.detect(sentence),
            isEmpty,
            reason: 'faux positif sur : $sentence',
          );
        }
      });

      test(
          'une vraie commune tout en majuscules reste détectée (non-'
          'régression)', () {
        // Convention administrative française réelle (bloc adresse en
        // majuscules) : ne doit pas être écartée par le filtre anti-unité.
        final entities = detector.detect('Adresse : 44000 NANTES.');
        expect(entities, hasLength(1));
        expect(entities.single.value, '44000 NANTES');
      });
    });

    group('span ne traverse jamais un saut de ligne — bug corrigé', () {
      // Reproduction exacte du bug : une fenêtre de 5 chiffres à
      // l'intérieur d'un plus long numéro (RPPS invalide, donc non masqué
      // par ailleurs) était captée comme "code postal", avalant ensuite le
      // saut de ligne suivant et le début de la ligne suivante.
      test(
          'fenêtre de 5 chiffres enchâssée dans un numéro plus long -> '
          'aucune adresse, aucun caractère avalé', () {
        const text = 'RPPS 10100458923\n\nM. ALBERT Francois '
            '(Pédicure-Podologue)';
        final entities = detector.detect(text);
        expect(entities, isEmpty, reason: 'faux positif sur : $text');
      });

      test(
          'code postal et commune sur deux lignes séparées -> non '
          'détecté (contrairement à la même ligne)', () {
        final entities = detector.detect('70160\nSaint Rémy en Comté');
        expect(entities, isEmpty);
      });

      test(
          'code postal + commune sur la même ligne reste détecté '
          '(non-régression)', () {
        final entities = detector.detect('70160 Saint Rémy en Comté');
        expect(entities, hasLength(1));
      });

      test(
          'adresse complète encadrée par du texte multi-ligne -> span '
          'exact, rien avalé', () {
        const text = 'Ligne précédente.\n'
            '12 rue des Lilas, 75015 Paris\n'
            'Ligne suivante.';
        final entities = detector.detect(text);
        expect(entities, hasLength(1));
        expect(entities.single.value, '12 rue des Lilas, 75015 Paris');
      });
    });
  });
}
