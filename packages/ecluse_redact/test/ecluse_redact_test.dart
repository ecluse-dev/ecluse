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
  });
}
