import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  group('Ecluse.redact / Ecluse.restore', () {
    test('aller-retour complet sur le contrat de travail', () async {
      final sample = contratTravailSample;
      final result = await Ecluse.redact(sample.text);

      expect(result.entities, isNotEmpty);
      expect(result.maskedText, isNot(contains('Vasseur')));
      expect(result.maskedText, isNot(contains('Bonnard')));
      expect(result.maskedText, isNot(contains('1 88 05 44 056 003 25')));
      expect(result.maskedText, isNot(contains('FR40')));
      expect(result.maskedText, contains('[NOM_1]'));
      expect(result.maskedText, contains('[NIR_1]'));
      expect(result.maskedText, contains('[IBAN_1]'));
      expect(result.maskedText, contains('[ETABLISSEMENT_1]'));

      final restored = Ecluse.restore(result.maskedText, result.mapping);
      expect(restored, equals(sample.text));
    });

    test('aller-retour complet sur le compte rendu de réunion', () async {
      final sample = compteRenduSample;
      final result = await Ecluse.redact(sample.text);

      expect(result.entities, isNotEmpty);
      expect(result.maskedText, isNot(contains('Lambert')));
      expect(result.maskedText, isNot(contains('Herbin')));
      expect(result.maskedText, isNot(contains('Ferrand')));
      expect(result.maskedText, contains('[ETABLISSEMENT_1]'));

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
      expect(result.mapping['[NOM_1]'], 'M. Jean Dupont');
      expect(result.mapping['[NOM_2]'], 'Mme Alice Martin');
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
