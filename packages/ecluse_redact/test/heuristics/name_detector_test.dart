import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = NameDetector();

  group('NameDetector', () {
    test('civilité + prénom + nom -> confiance haute', () {
      final entities = detector.detect('M. Jean Dupont est arrivé.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'M. Jean Dupont');
      expect(entities.single.confidence, 0.9);
    });

    test('civilité + un seul mot capitalisé -> détecté', () {
      final entities = detector.detect('Dr Martin recevra le patient.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Dr Martin');
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

    test('civilité + NOM en majuscules + prénom -> bloc complet', () {
      final entities = detector.detect('Mme HOUSER Lorette est présente.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Mme HOUSER Lorette');
      expect(entities.single.confidence, 0.9);
    });

    test('sigle en majuscules isolé, sans prénom ni civilité -> non détecté',
        () {
      final entities = detector.detect('Hier, le CSE a voté à l\'unanimité.');
      expect(entities, isEmpty);
    });

    test('type exposé est EntityType.nom', () {
      expect(detector.type, EntityType.nom);
    });
  });
}
