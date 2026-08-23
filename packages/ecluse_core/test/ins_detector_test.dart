import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

void main() {
  const detector = InsDetector();

  group('InsDetector — détection OID', () {
    test('détecte un OID INS-NIR catalogué', () {
      final entities = detector.detect(
        'Identifiant: 1.2.250.1.213.1.4.8 attribué le 12/03/2024',
      );
      expect(entities, hasLength(1));
      final e = entities.single;
      expect(e.type, EntityType.ins);
      expect(e.value, '1.2.250.1.213.1.4.8');
      expect(e.confidence, greaterThan(0.9));
    });

    test('détecte un OID INS avec préfixe ANS mais suffixe non catalogué', () {
      final entities = detector.detect(
        'oid: 1.2.250.1.213.1.4.99 test',
      );
      expect(entities, hasLength(1));
      final e = entities.single;
      expect(e.value, '1.2.250.1.213.1.4.99');
      // Suffixe non catalogué : confiance modérée, signalé plutôt que raté.
      expect(e.confidence, lessThan(0.9));
    });

    test('ignore un OID non-INS français', () {
      final entities = detector.detect(
        'oid random 1.3.6.1.4.1.1234 sans rapport',
      );
      expect(entities, isEmpty);
    });

    test('détecte plusieurs OIDs dans le même texte', () {
      final entities = detector.detect(
        'Patient A: 1.2.250.1.213.1.4.8, Patient B: 1.2.250.1.213.1.4.10',
      );
      expect(entities, hasLength(2));
      // Triés par position croissante.
      expect(entities[0].start, lessThan(entities[1].start));
    });
  });

  group('InsDetector — marqueurs textuels', () {
    test('détecte "INS-NIR" avec frontière de mot', () {
      final entities = detector.detect('Champ INS-NIR : 155047800000162');
      final markers =
          entities.where((e) => e.value.toUpperCase().contains('INS'));
      expect(markers, isNotEmpty);
    });

    test('détecte "matricule INS" avec espaces multiples', () {
      final entities = detector.detect('le  matricule   INS  du patient');
      expect(entities, isNotEmpty);
      expect(entities.first.type, EntityType.ins);
    });

    test('respecte les frontières de mot (pas de match dans MARINSTEIN)', () {
      final entities = detector.detect('MARINSTEIN et POINSOT');
      expect(entities, isEmpty);
    });

    test('insensible à la casse', () {
      final entities = detector.detect('ins-nir : xxx');
      expect(entities, hasLength(1));
    });

    test('accepte accents ou pas dans "identité nationale de santé"', () {
      final withAccents = detector.detect('l\'identité nationale de santé');
      final withoutAccents = detector.detect('identite nationale de sante');
      expect(withAccents, isNotEmpty);
      expect(withoutAccents, isNotEmpty);
    });
  });

  group('InsDetector — pas de faux positif', () {
    test('texte médical sans INS ne produit aucune entité', () {
      final entities = detector.detect(
        'Compte-rendu de consultation. Patient vu ce jour, RAS.',
      );
      expect(entities, isEmpty);
    });

    test('OID préfixe partiel non-INS ignoré', () {
      final entities = detector.detect('oid tronqué : 1.2.250.1.213 fin');
      expect(entities, isEmpty);
    });
  });

  group('InsDetector — configuration', () {
    test('catalogue custom peut ajouter de nouveaux OIDs', () {
      const custom = InsDetector(
        oidCatalog: {
          '1.2.250.1.213.1.4.42': InsIdentityKind.nis,
        },
      );
      final entities = custom.detect('id: 1.2.250.1.213.1.4.42 vérifier');
      expect(entities, hasLength(1));
      expect(entities.single.confidence, greaterThan(0.9));
    });

    test('hasInsOidPrefix reconnaît le segment ANS', () {
      expect(InsDetector.hasInsOidPrefix('1.2.250.1.213.1.4.999'), isTrue);
      expect(InsDetector.hasInsOidPrefix('1.3.6.1.4.1.9999'), isFalse);
    });
  });

  group('InsDetector — cohérence EntityDetector interface', () {
    test('type = EntityType.ins', () {
      expect(detector.type, EntityType.ins);
    });

    test('offsets pointent bien dans le texte', () {
      const text = 'prefix 1.2.250.1.213.1.4.8 suffix';
      final entities = detector.detect(text);
      expect(entities, hasLength(1));
      final e = entities.single;
      expect(text.substring(e.start, e.end), '1.2.250.1.213.1.4.8');
    });

    test('résultats triés par position croissante', () {
      final entities = detector.detect(
        'INS-NIR abc 1.2.250.1.213.1.4.8 def INS-NIA',
      );
      for (var i = 1; i < entities.length; i++) {
        expect(entities[i].start, greaterThanOrEqualTo(entities[i - 1].start));
      }
    });
  });
}
