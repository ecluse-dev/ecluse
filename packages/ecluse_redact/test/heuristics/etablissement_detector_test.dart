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

    // -------------------------------------------------------------------------
    // Corpus de mesure du 31/07 — rappel 40,8 %, fuite 36,5 %, précision
    // 68,2 %. Quatre défauts diagnostiqués sur `_pattern`, voir la discussion
    // en amont de cette PR. ÉTAT ATTENDU AVANT CORRECTIF : ces quatre
    // groupes sont ROUGES. Les groupes ci-dessus doivent rester VERTS.
    // -------------------------------------------------------------------------

    group(
        'défaut 1 — le connecteur ne s\'applique qu\'une fois (bug à '
        'corriger)', () {
      // Le connecteur ("de", "du"...) n'est tenté qu'immédiatement après le
      // mot-clé. Un connecteur plus loin dans le nom (après un premier mot
      // déjà capté par la continuation) n'est jamais reconnu : la
      // continuation exige un mot capitalisé, "de" est en minuscules, le
      // span s'arrête net et l'élément le plus identifiant (la ville) fuit.
      test('connecteur au milieu du nom -> pas de troncature', () {
        final entities = detector
            .detect('Le Centre Hospitalier de Dole a transféré le patient.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Centre Hospitalier de Dole');
      });
    });

    group(
        'défaut 2 — sigles et mots-clés absents de la liste (bug à '
        'corriger)', () {
      // Aucun problème de grammaire ici : ces mots-clés sont simplement
      // absents de `_keywords`, donc `_pattern` ne matche jamais -> zéro
      // détection, zéro fuite visible dans le span (mais fuite totale du
      // nom en clair).
      test('"CH" est reconnu comme mot-clé', () {
        final entities =
            detector.detect('Le CH de Vesoul a transféré le patient.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'CH de Vesoul');
      });

      test('"SSIAD" est reconnu comme mot-clé', () {
        final entities =
            detector.detect('Le SSIAD de Gray intervient à domicile.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'SSIAD de Gray');
      });

      test('"Clinique" est reconnu comme mot-clé', () {
        final entities =
            detector.detect('La Clinique Pasteur a confirmé le rendez-vous.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Clinique Pasteur');
      });

      test(
          '"Hôpital"/"Hopital" est reconnu comme mot-clé (accentué et non '
          'accentué)', () {
        const cas = {
          'L\'Hôpital Saint Jacques accueille les urgences.':
              'Hôpital Saint Jacques',
          'L\'Hopital Saint Jacques accueille les urgences.':
              'Hopital Saint Jacques',
        };
        cas.forEach((sentence, expected) {
          final entities = detector.detect(sentence);
          expect(entities, hasLength(1), reason: 'sur : $sentence');
          expect(entities.single.value, expected, reason: 'sur : $sentence');
        });
      });

      test(
          '"Lycée"/"Lycee" est reconnu comme mot-clé (accentué et non '
          'accentué)', () {
        const sentences = [
          'Le Lycée Jean Moulin organise la rentrée.',
          'Le Lycee Jean Moulin organise la rentrée.',
        ];
        for (final sentence in sentences) {
          final entities = detector.detect(sentence);
          expect(entities, hasLength(1), reason: 'sur : $sentence');
        }
      });
    });

    group(
        'défaut 3 — patronyme tronqué par le plafond numérique (bug à '
        'corriger)', () {
      // La continuation est bornée à 4 mots capitalisés au total (1
      // obligatoire + {0,3}), plafond purement syntaxique sans rapport avec
      // la frontière réelle du nom. Un nom légitime à 5 mots (mot-clé de
      // service + patronyme à deux mots) perd son dernier mot.
      test('nom d\'établissement à 5 mots -> aucun mot perdu', () {
        final entities = detector.detect(
          'Le Centre Hospitalier Universitaire Pédiatrique Robert Debré '
          'accueille les enfants.',
        );
        expect(entities, hasLength(1));
        expect(
          entities.single.value,
          'Centre Hospitalier Universitaire Pédiatrique Robert Debré',
        );
      });
    });

    group(
        'défaut 4 — garde-fou : connecteur non suivi d\'un mot valide '
        '(protège le correctif du défaut 1)', () {
      // Rendre le connecteur répétable (défaut 1) ouvre un risque nouveau :
      // absorber un connecteur qui ne mène à rien ("de garde", langage
      // courant, pas un nom propre). Ce n'est pas un bug préexistant — le
      // code actuel, faute de connecteur répétable, s'arrête déjà ici par
      // accident. C'est un garde-fou pour le correctif à venir : il doit
      // rester vert avant ET après, comme les garde-fous de l'adresse.
      test(
          'connecteur en bout de nom, non suivi d\'un mot en casse de '
          'titre -> non absorbé', () {
        final entities = detector.detect(
          'En cas d\'urgence, contactez le Centre Hospitalier de garde.',
        );
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Centre Hospitalier');
      });

      // Limite acceptée et documentée (voir LIMITES.md) : la règle de
      // frontière n'exclut pas un mot capitalisé isolé et sans rapport qui
      // suit directement, sans ponctuation ni mot minuscule intercalé — la
      // règle donnée n'a pas de clause pour ce cas, et l'utilisateur a
      // tranché : pas de liste d'exclusion de mots-outils pour le fermer.
      test(
          'mot capitalisé isolé sans rapport, adjacent sans ponctuation -> '
          'reste absorbé (limite connue, documentée)', () {
        final entities =
            detector.detect('L\'IME La Source À Vesoul accueille des jeunes.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'IME La Source À Vesoul');
      });
    });
  });
}
