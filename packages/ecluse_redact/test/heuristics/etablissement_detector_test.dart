import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = EtablissementDetector();

  group('EtablissementDetector', () {
    test('mot-clé + nom propre simple', () {
      final entities = detector.detect('Le Foyer Les Tilleuls accueille.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Foyer Les Tilleuls');
    });

    test('acronyme + nom propre', () {
      final entities = detector.detect('L\'IME Beauséjour organise une '
          'réunion.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'IME Beauséjour');
    });

    test('mot-clé avec connecteur', () {
      final entities =
          detector.detect('La Résidence du Parc accueille des visiteurs.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Résidence du Parc');
    });

    test('mot-clé en minuscule -> non détecté (évite le sens commun)', () {
      final entities = detector.detect('Le centre de la ville est proche.');
      expect(entities, isEmpty);
    });

    group('span ne traverse jamais un saut de ligne — bug corrigé', () {
      // Reproduction : "ESAT" en fin de titre, suivi d'une ligne blanche
      // puis d'un mot capitalisé sans rapport ("Établissement :" en tête
      // de ligne suivante) -- ne doit jamais fusionner en une seule
      // entité.
      test(
          'mot-clé en fin de ligne + mot capitalisé sur une autre ligne '
          '-> pas de fusion', () {
        final entities = detector.detect(
          'COMPTE RENDU — ESAT\n\nÉtablissement : ESAT Les Ateliers.',
        );
        expect(
          entities.map((e) => e.value),
          isNot(contains(contains('\n'))),
        );
      });

      test(
          'mot-clé + nom propre sur la même ligne reste détecté (non-'
          'régression)', () {
        final entities = detector.detect('Le Foyer Les Tilleuls accueille.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Foyer Les Tilleuls');
      });
    });
  });
}
