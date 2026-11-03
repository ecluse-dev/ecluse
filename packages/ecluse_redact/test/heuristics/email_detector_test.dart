import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = EmailDetector();

  /// Détecte dans [text] et vérifie que l'unique entité couvre exactement
  /// [attendu], à la bonne position du texte d'origine.
  void expectSpan(String text, String attendu) {
    final entities = detector.detect(text);
    expect(entities, hasLength(1), reason: text);
    final e = entities.single;
    expect(e.value, attendu);
    expect(e.start, text.indexOf(attendu));
    expect(text.substring(e.start, e.end), attendu);
  }

  group('EmailDetector', () {
    test('adresse email standard', () {
      final entities = detector.detect('Contact : julien.vasseur@example.fr.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'julien.vasseur@example.fr');
    });

    test('texte sans arobase -> non détecté', () {
      final entities = detector.detect('Contact au service RH.');
      expect(entities, isEmpty);
    });
  });

  group('EmailDetector — formes valides', () {
    test('sous-adressage (+tag)', () {
      expectSpan(
          'Écrire à jean+facture@example.fr svp', 'jean+facture@example.fr');
    });

    test('sous-domaines', () {
      expectSpan('Mail : a.b@mail.service.chu-nancy.example.fr',
          'a.b@mail.service.chu-nancy.example.fr');
    });

    test('TLD long', () {
      expectSpan(
          'Voir contact@studio.photography', 'contact@studio.photography');
    });

    test('majuscules', () {
      expectSpan('Mail : Jean.Dupont@EXAMPLE.FR', 'Jean.Dupont@EXAMPLE.FR');
    });

    test('local commençant par un souligné', () {
      expectSpan('Mail : _jean@example.fr', '_jean@example.fr');
    });

    test('deux adresses dans le même texte', () {
      final entities = detector.detect('a@example.fr et b@example.org');
      expect(entities.map((e) => e.value), ['a@example.fr', 'b@example.org']);
    });
  });

  group('EmailDetector — ponctuation et délimiteurs', () {
    const attendu = 'jean@example.fr';
    const cas = {
      'point final': 'Contact : jean@example.fr.',
      'virgule': 'Contact jean@example.fr, merci',
      'point-virgule': 'jean@example.fr; autre',
      'deux-points': 'jean@example.fr: voilà',
      'point d\'exclamation': 'Écrivez à jean@example.fr!',
      'point d\'interrogation': 'Est-ce jean@example.fr?',
      'parenthèses': 'Contact (jean@example.fr) merci',
      'chevrons': 'Jean <jean@example.fr> a écrit',
      'guillemets': 'Contact "jean@example.fr"',
      'mailto': 'mailto:jean@example.fr',
      'fin de ligne': 'Contact\njean@example.fr\nMerci',
    };
    cas.forEach((nom, texte) {
      test('span exact : $nom', () => expectSpan(texte, attendu));
    });
  });

  group('EmailDetector — rejets', () {
    const rejets = {
      'sans TLD': 'root@localhost',
      'TLD d\'un caractère': 'a@b.c',
      'mention sans local': 'Suivez @example.fr sur le réseau',
      'domaine à points consécutifs': 'a@b..fr',
      'label commençant par un tiret': 'a@-b.fr',
      'arobase isolé': 'prix 3 @ 4 euros',
    };
    rejets.forEach((nom, texte) {
      test('ignore : $nom', () => expect(detector.detect(texte), isEmpty));
    });
  });

  group('EmailDetector — obfuscations sûres', () {
    const cas = {
      '[at]': 'jean.dupont[at]example.fr',
      '(at)': 'jean.dupont(at)example.fr',
      '[at] avec espaces': 'jean.dupont [at] example.fr',
      '(arobase)': 'jean.dupont (arobase) example.fr',
      '[AROBASE]': 'jean.dupont[AROBASE]example.fr',
    };
    cas.forEach((nom, adresse) {
      test('détecte $nom', () {
        expectSpan('Écrire à $adresse, merci', adresse);
        final e = detector.detect('Écrire à $adresse, merci').single;
        expect(e.confidence, lessThan(0.85));
      });
    });

    test('« at » en clair n\'est pas une obfuscation', () {
      expect(detector.detect('rendez-vous at example.fr'), isEmpty);
      expect(detector.detect('jean at example.fr'), isEmpty);
    });

    test('un crochet [at] sans domaine n\'est pas détecté', () {
      expect(detector.detect('voir note[at] ci-dessous'), isEmpty);
    });
  });
}
