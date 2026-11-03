import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

void main() {
  const detector = RppsDetector();

  group('RppsDetector — RPPS valides', () {
    test('détecte un RPPS compact à clé Luhn valide', () {
      final entities = detector.detect('Dr Martin, RPPS 10001234565.');
      expect(entities, hasLength(1));
      expect(entities.single.type, EntityType.rpps);
      expect(entities.single.value, '10001234565');
      expect(entities.single.confidence, 0.9);
    });

    test('détecte un RPPS avec espaces', () {
      final entities = detector.detect('RPPS : 10987 65432 3');
      expect(entities, hasLength(1));
    });

    test('détecte plusieurs RPPS dans le même texte', () {
      final entities = detector.detect(
        'Transfert du Dr 10001234565 vers le Dr 20345678906.',
      );
      expect(entities, hasLength(2));
    });

    test('les positions start/end correspondent au texte source', () {
      const text = 'RPPS=10001234565;';
      final e = detector.detect(text).single;
      expect(text.substring(e.start, e.end), e.value);
    });
  });

  group('RppsDetector — variantes de séparateurs', () {
    // Même RPPS (clé Luhn valide) écrit avec chaque séparateur : le span et
    // la valeur doivent couvrir exactement le texte d'origine.
    const variantes = {
      'espace insécable (U+00A0)': '10001\u00A0234\u00A0565',
      'espace fine insécable (U+202F)': '10001\u202F234\u202F565',
      'tabulation': '10001\t234\t565',
      'espaces multiples': '10001   234  565',
      'points': '10001.234.565',
      'tirets': '10001-234-565',
      'mélange': '10001 \u00A0234.565',
    };
    variantes.forEach((nom, rpps) {
      test('détecte un RPPS avec $nom', () {
        final text = 'Dr Martin, RPPS $rpps, cabinet.';
        final entities = detector.detect(text);
        expect(entities, hasLength(1));
        final e = entities.single;
        expect(e.start, text.indexOf(rpps));
        expect(e.end, text.indexOf(rpps) + rpps.length);
        expect(e.value, rpps);
        expect(text.substring(e.start, e.end), e.value);
      });
    });

    test('un espace de mot ordinaire n\'est pas absorbé', () {
      const text = 'RPPS 10001234565 inscrit';
      final e = detector.detect(text).single;
      expect(text.substring(e.start, e.end), '10001234565');
    });

    test('rejette une clé Luhn invalide malgré les séparateurs', () {
      expect(detector.detect('10001\u00A0234\u00A0566'), isEmpty);
      expect(detector.detect('10001.234.566'), isEmpty);
    });

    test('ne matche pas dans une séquence plus longue à séparateurs', () {
      expect(detector.detect('1000.1234.5651.2'), isEmpty);
    });
  });

  group('RppsDetector — rejets', () {
    test('rejette une clé Luhn invalide', () {
      expect(detector.detect('10001234566'), isEmpty);
    });

    test('ignore un numéro de téléphone français (10 chiffres)', () {
      expect(detector.detect('Appelez le 06 12 34 56 78.'), isEmpty);
    });

    test('ne matche pas à l\'intérieur d\'une séquence plus longue', () {
      expect(detector.detect('9910001234565'), isEmpty);
    });

    test('ne détecte pas de faux RPPS dans un NIR espacé', () {
      expect(detector.detect('NIR : 1 85 05 78 006 084 91'), isEmpty);
    });

    test('texte vide', () {
      expect(detector.detect(''), isEmpty);
    });
  });

  group('RppsDetector — enchâssé dans un IBAN — bug corrigé', () {
    // Les groupes d'un IBAN affiché par blocs de chiffres séparés d'un
    // espace unique ("8471 5621 003") ont exactement la forme que le
    // motif RPPS tolère (chiffre + jusqu'à 10 fois « espace optionnel +
    // chiffre ») : une somme de blocs consécutifs totalisant 11 chiffres
    // peut passer Luhn par hasard. Quand l'IBAN englobant est lui-même
    // invalide (donc jamais détecté par IbanFrDetector), rien ne
    // départage ce faux positif via resolveOverlaps — il faut l'écarter
    // à la source.
    test(
        'fenêtre Luhn-valide à cheval sur plusieurs blocs d\'un IBAN '
        'invalide -> aucun RPPS', () {
      // IBAN invalide (clé FR76 non vérifiée), mais dont les 3 derniers
      // blocs ("8471 5621 003", 4+4+3=11 chiffres) passent Luhn par
      // coïncidence.
      const text = 'FR76 3000 3004 1012 8471 5621 003';
      expect(detector.detect(text), isEmpty);
    });

    test(
        'un RPPS légitime juste après un IBAN reste détecté (non-'
        'régression)', () {
      const text = 'FR76 3000 3004 1012 8471 5621 003. '
          'RPPS du médecin traitant : 10001234565.';
      final entities = detector.detect(text);
      expect(entities, hasLength(1));
      expect(entities.single.value, '10001234565');
    });
  });

  group('RppsDetector — identifiant adjacent à un nombre', () {
    test('nombre après', () {
      const text = 'RPPS 10001234565 12';
      final e = detector.detect(text).single;
      expect(text.substring(e.start, e.end), '10001234565');
    });

    test('nombre avant', () {
      const text = 'Dossier 3 10001234565';
      final e = detector.detect(text).single;
      expect(text.substring(e.start, e.end), '10001234565');
    });
  });
}
