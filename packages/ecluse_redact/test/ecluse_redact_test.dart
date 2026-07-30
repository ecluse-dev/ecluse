import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  group('Ecluse.redact / Ecluse.restore', () {
    test('aller-retour complet sur le contrat de travail', () async {
      final sample = contratTravailSample;
      final result = await Ecluse.redact(sample.text);

      expect(result.entities, isNotEmpty);
      expect(result.maskedText, isNot(contains('Chevalier')));
      expect(result.maskedText, isNot(contains('Bonnard')));
      expect(result.maskedText, isNot(contains('2 90 06 12 205 078 92')));
      expect(result.maskedText, isNot(contains('10200876547')));
      expect(result.maskedText, isNot(contains('FR51')));
      expect(result.maskedText, contains('[NOM_1]'));
      expect(result.maskedText, contains('[NIR_1]'));
      expect(result.maskedText, contains('[RPPS_1]'));
      expect(result.maskedText, contains('[IBAN_1]'));
      expect(result.maskedText, contains('[ETABLISSEMENT_1]'));

      final restored = Ecluse.restore(result.maskedText, result.mapping);
      expect(restored, equals(sample.text));
    });

    test('aller-retour complet sur le compte rendu de réunion', () async {
      final sample = compteRenduSample;
      final result = await Ecluse.redact(sample.text);

      expect(result.entities, isNotEmpty);
      expect(result.maskedText, isNot(contains('Belhadj')));
      expect(result.maskedText, isNot(contains('Rambert')));
      expect(result.maskedText, isNot(contains('Costa')));
      expect(result.maskedText, isNot(contains('1 85 03 44 123 045 28')));
      expect(result.maskedText, isNot(contains('10100987659')));
      expect(result.maskedText, isNot(contains('FR56')));
      // Posologie clinique, pas une adresse : ne doit jamais être avalée
      // par le détecteur d'adresse (bug corrigé — voir AdresseDetector).
      expect(result.maskedText, contains('innohep 10000 UI'));
      // Sigles métier : jamais masqués.
      expect(result.maskedText, contains('SSIAD'));
      expect(result.maskedText, contains('CARSAT'));
      expect(result.maskedText, contains('RCP'));
      expect(result.maskedText, contains('[NIR_1]'));
      expect(result.maskedText, contains('[RPPS_1]'));
      expect(result.maskedText, contains('[IBAN_1]'));

      final restored = Ecluse.restore(result.maskedText, result.mapping);
      expect(restored, equals(sample.text));
    });

    test('une même valeur détectée reçoit toujours le même jeton', () async {
      const text = 'Le Foyer Les Tilleuls accueille. Le Foyer Les Tilleuls '
          'organise une fête.';
      final result = await Ecluse.redact(text);

      final occurrences =
          RegExp(r'\[ETABLISSEMENT_1\]').allMatches(result.maskedText);
      expect(occurrences.length, 2);
      expect(result.mapping.length, 1);
    });

    test('jetons distincts pour des valeurs différentes du même type',
        () async {
      const text = 'M. Jean Dupont et Mme Alice Martin se rencontrent.';
      final result = await Ecluse.redact(text);

      expect(result.maskedText, contains('[NOM_1]'));
      expect(result.maskedText, contains('[NOM_2]'));
      expect(result.mapping['[NOM_1]'], 'Jean Dupont');
      expect(result.mapping['[NOM_2]'], 'Alice Martin');
      // La civilité est un indice de genre, pas un identifiant : elle reste
      // visible à côté du jeton plutôt que d'être masquée avec le nom.
      expect(result.maskedText, contains('M. [NOM_1]'));
      expect(result.maskedText, contains('Mme [NOM_2]'));
    });

    test('restore tolère une déformation raisonnable du jeton par le LLM',
        () async {
      final result = await Ecluse.redact('M. Jean Dupont est présent.');
      final deformed = result.maskedText.replaceFirst('[NOM_1]', '[ nom_1 ]');

      final restored = Ecluse.restore(deformed, result.mapping);
      expect(restored, 'M. Jean Dupont est présent.');
    });

    test('restore ne devine jamais un jeton trop déformé', () async {
      final result = await Ecluse.redact('M. Jean Dupont est présent.');
      const withUnknownToken = '[NOM_1_BIS] est présent.';

      final restored = Ecluse.restore(withUnknownToken, result.mapping);
      expect(restored, withUnknownToken);
    });

    test('aucun filtre de confiance : un prénom isolé est aussi masqué',
        () async {
      const text = 'Sophie rappelle que le dossier avance.';
      final result = await Ecluse.redact(text);

      expect(result.entities.single.confidence, 0.5);
      expect(result.maskedText, isNot(contains('Sophie')));
    });

    group('cohérence des pseudonymes intra-document — bug corrigé', () {
      // Même personne, ordre nom/prénom inversé d'une mention à l'autre :
      // un LLM qui voit deux jetons différents pour la même personne
      // conclut à tort qu'il s'agit de deux professionnels distincts.
      test('"Dubreuil Thomas" et "Thomas Dubreuil" reçoivent le même jeton',
          () async {
        const text = 'Dubreuil Thomas anime la réunion. Plus tard, Thomas '
            'Dubreuil confirme le compte rendu.';
        final result = await Ecluse.redact(text);

        expect(result.maskedText, contains('[NOM_1]'));
        expect(result.maskedText, isNot(contains('[NOM_2]')));
        expect(result.mapping.length, 1);
      });

      test('la casse seule ne crée pas non plus deux identités', () async {
        const text = 'DUBREUIL Thomas ouvre la séance. dubreuil thomas '
            'clôt la séance.';
        final result = await Ecluse.redact(text);

        expect(result.mapping.length, 1);
      });

      test(
          'deux personnes réellement différentes gardent deux jetons '
          'distincts (non-régression)', () async {
        const text = 'M. Jean Dupont et Mme Alice Martin se rencontrent.';
        final result = await Ecluse.redact(text);

        expect(result.mapping.length, 2);
      });

      // Conséquence assumée et documentée (voir LIMITES.md) : un même
      // jeton ne peut restituer qu'UNE seule graphie au moment de la
      // restauration (elle fonctionne par remplacement global du jeton
      // dans la réponse du LLM, pas par position dans le texte d'origine).
      // La cohérence d'identité pour le LLM est jugée plus importante que
      // la fidélité mot-à-mot de l'ordre nom/prénom d'une re-mention —
      // aucun caractère n'est perdu ni déplacé, seul l'ORDRE de la
      // deuxième mention est harmonisé sur la première.
      test(
          'conséquence documentée : la restauration harmonise l\'ordre sur '
          'la première mention', () async {
        const text = 'Dubreuil Thomas anime la réunion. Plus tard, Thomas '
            'Dubreuil confirme le compte rendu.';
        final result = await Ecluse.redact(text);
        final restored = Ecluse.restore(result.maskedText, result.mapping);

        expect(restored, isNot(equals(text)));
        expect(restored, contains('Dubreuil Thomas anime'));
        expect(restored, contains('Plus tard, Dubreuil Thomas confirme'));
      });
    });
  });

  group('invariant global — restauration exacte (sans ambiguïté d\'identité)',
      () {
    // Sur un document SANS re-mention à ordre nom/prénom inversé de la
    // même personne (voir le groupe ci-dessus pour ce cas assumé), la
    // restauration doit redonner le texte d'origine caractère pour
    // caractère. Cet invariant aurait attrapé le bug des spans traversant
    // un saut de ligne (AdresseDetector) : il tourne délibérément sur du
    // texte multi-ligne, multi-paragraphe.
    const documents = [
      'RPPS 10100458923\n\nM. ALBERT Francois (Pédicure-Podologue)',
      'Ligne précédente.\n12 rue des Lilas, 75015 Paris\nLigne suivante.',
      '70160 Saint Rémy en Comté\n\nContact : 02 40 12 34 56.',
      'Compte rendu\n\n'
          'Présents : Mme Sophie Lambert, M. Marc Herbin.\n\n'
          'Adresse du siège : 8 rue de la Mairie, 44000 Nantes.\n\n'
          'RPPS invalide mentionné : 10100987654\n\n'
          'Posologie : innohep 10000 UI en injection.',
    ];

    for (var i = 0; i < documents.length; i++) {
      test('document ${i + 1}/${documents.length}', () async {
        final text = documents[i];
        final result = await Ecluse.redact(text);
        final restored = Ecluse.restore(result.maskedText, result.mapping);
        expect(restored, equals(text));
      });
    }
  });

  group('corpus de démo à clés valides — le seul où un 100 % a un sens', () {
    // Chaque document de validKeysDemoCorpus contient un NIR, un IBAN et
    // un RPPS générés puis revérifiés par nos propres détecteurs
    // structurels (voir samples.dart) : les trois DOIVENT être détectés
    // et masqués ici, sans quoi le "100 %" affiché en démo serait un
    // mensonge.
    for (var i = 0; i < validKeysDemoCorpus.length; i++) {
      final sample = validKeysDemoCorpus[i];
      test(
          '${sample.title} : NIR + IBAN + RPPS tous masqués, round-trip '
          'exact', () async {
        final result = await Ecluse.redact(sample.text);
        final types = result.entities.map((e) => e.type).toSet();

        expect(types, contains(EntityType.nir), reason: sample.title);
        expect(types, contains(EntityType.iban), reason: sample.title);
        expect(types, contains(EntityType.rpps), reason: sample.title);

        for (final entity in result.entities) {
          expect(
            sample.text.substring(entity.start, entity.end),
            entity.value,
            reason: '${sample.title} : offset invalide pour ${entity.type}',
          );
        }

        final restored = Ecluse.restore(result.maskedText, result.mapping);
        expect(restored, equals(sample.text), reason: sample.title);
      });
    }

    test('au moins 3 comptes rendus de réunion dans le corpus', () {
      final meetingMinutes = validKeysDemoCorpus
          .where((s) => s.title.toLowerCase().contains('compte rendu'));
      expect(meetingMinutes.length, greaterThanOrEqualTo(3));
    });
  });
}
