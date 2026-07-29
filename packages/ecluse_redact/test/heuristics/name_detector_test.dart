import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = NameDetector();

  group('NameDetector', () {
    test('civilité + prénom + nom -> confiance haute, civilité préservée', () {
      final entities = detector.detect('M. Jean Dupont est arrivé.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Jean Dupont');
      expect(entities.single.start, 'M. '.length);
      expect(entities.single.confidence, 0.9);
    });

    test('civilité + un seul mot capitalisé -> détecté, civilité préservée',
        () {
      final entities = detector.detect('Dr Martin recevra le patient.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Martin');
    });

    test('prénom connu + mot capitalisé -> confiance moyenne', () {
      final entities = detector.detect('Sophie Lambert dirige le foyer.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Sophie Lambert');
      expect(entities.single.confidence, 0.6);
    });

    test('prénom connu isolé, sans nom qui suit -> confiance plus faible', () {
      final entities = detector.detect('Sophie rappelle que le dossier '
          'avance.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Sophie');
      expect(entities.single.confidence, 0.5);
    });

    test('mot capitalisé en début de phrase sans indice -> non détecté', () {
      final entities = detector.detect('Le contrat est signé aujourd\'hui.');
      expect(entities, isEmpty);
    });

    test('mot capitalisé quelconque sans prénom connu -> non détecté', () {
      final entities = detector.detect('Nantes accueille de nombreux '
          'établissements.');
      expect(entities, isEmpty);
    });

    test('NOM en majuscules avant un prénom connu -> bloc complet', () {
      final entities = detector.detect('DANNER Laurent a signé le contrat.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'DANNER Laurent');
      expect(entities.single.confidence, 0.6);
    });

    // Reproduction exacte du bug signalé : "DANNER Laurent" strictement en
    // début de texte, sans rien avant. Le mot en majuscules doit être
    // rattaché au prénom qui le suit, pas laissé en clair à côté du jeton.
    test('"DANNER Laurent" seul, en tout début de texte -> bloc complet',
        () async {
      final entities = detector.detect('DANNER Laurent');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'DANNER Laurent');
      expect(entities.single.start, 0);
      expect(entities.single.end, 'DANNER Laurent'.length);
      expect(entities.single.confidence, 0.6);

      final masked = (await Ecluse.redact('DANNER Laurent')).maskedText;
      expect(masked, isNot(contains('DANNER')));
      expect(masked, contains('[NOM_1]'));
    });

    test('prénom connu suivi d\'un NOM en majuscules -> bloc complet', () {
      final entities = detector.detect('Laurent DANNER a signé le contrat.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Laurent DANNER');
      expect(entities.single.confidence, 0.6);
    });

    // Ordre inverse de la reproduction ci-dessus, même exigence.
    test('"Laurent DANNER" seul, en tout début de texte -> bloc complet',
        () async {
      final entities = detector.detect('Laurent DANNER');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Laurent DANNER');
      expect(entities.single.confidence, 0.6);

      final masked = (await Ecluse.redact('Laurent DANNER')).maskedText;
      expect(masked, isNot(contains('DANNER')));
      expect(masked, contains('[NOM_1]'));
    });

    test(
        'civilité + NOM en majuscules + prénom -> bloc complet, civilité '
        'préservée', () {
      final entities = detector.detect('Mme HOUSER Lorette est présente.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'HOUSER Lorette');
      expect(entities.single.confidence, 0.9);
    });

    test('sigle en majuscules isolé, sans prénom ni civilité -> non détecté',
        () {
      final entities = detector.detect('Hier, le CSE a voté à l\'unanimité.');
      expect(entities, isEmpty);
    });

    group('ordre NOM Prénom (sans majuscules) — bug corrigé', () {
      // Avant correction : seul le prénom connu était capté, le nom de
      // famille qui le précède (non tout-majuscules) fuitait en clair.
      test('"Dubreuil Thomas" -> bloc complet, pas seulement le prénom', () {
        final entities = detector.detect('Dubreuil Thomas a signé le '
            'contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Dubreuil Thomas');
        expect(entities.single.confidence, 0.6);
      });

      test('"Valette Sophie" -> bloc complet (le nom ne doit pas fuiter)', () {
        final entities = detector.detect('Valette Sophie a signé le '
            'contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Valette Sophie');
      });

      test('"Roche Chantal" -> bloc complet (le nom ne doit pas fuiter)', () {
        final entities = detector.detect('Roche Chantal a signé le '
            'contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Roche Chantal');
      });

      test('"Vasseur Marc" -> bloc complet (le nom ne doit pas fuiter)', () {
        final entities = detector.detect('Vasseur Marc a signé le contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Vasseur Marc');
      });
    });

    group('prénom composé (tiret) — bug corrigé', () {
      // Avant correction : le motif capitalisé gourmand avalait le tiret
      // ("Jean-Marc" comme un seul jeton), qui ne correspondait à aucune
      // entrée du gazetteer -> aucune détection, fuite totale.
      test('"VALETTE Jean-Marc" -> bloc complet, prénom composé reconnu', () {
        final entities = detector.detect('VALETTE Jean-Marc a signé le '
            'contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'VALETTE Jean-Marc');
        expect(entities.single.confidence, 0.6);
      });

      test('prénom composé après civilité reste géré normalement', () {
        final entities = detector.detect('Mme Anne-Sophie Perrin est '
            'arrivée.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Anne-Sophie Perrin');
      });

      test('un mot composé qui n\'est pas un prénom connu reste ignoré', () {
        final entities = detector.detect('Peut-être qu\'il viendra '
            'demain.');
        expect(entities, isEmpty);
      });
    });

    test('acronymes métier en majuscules -> jamais masqués (non-régression)',
        () {
      const acronymSentences = [
        'Hier, le SSIAD a coordonné la visite.',
        'La CARSAT a validé le dossier.',
        'Le HAD intervient à domicile.',
        'La RCP se tient jeudi.',
        'Le MSP accueille de nouveaux patients.',
        'La PCH a été accordée.',
        'L\'APA couvre une partie des frais.',
        'L\'IDE est passée ce matin.',
        'L\'IDEC a validé le protocole.',
        'L\'ESAT emploie 40 personnes.',
        'Le CSE a voté à l\'unanimité.',
      ];
      for (final sentence in acronymSentences) {
        expect(
          detector.detect(sentence),
          isEmpty,
          reason: 'faux positif sur : $sentence',
        );
      }
    });

    test('civilité + nom seul reste inchangée par la règle bidirectionnelle',
        () {
      final entities = detector.detect('Dr Vasseur recevra le patient.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Vasseur');
      expect(entities.single.confidence, 0.9);
    });

    test('type exposé est EntityType.nom', () {
      expect(detector.type, EntityType.nom);
    });
  });
}
