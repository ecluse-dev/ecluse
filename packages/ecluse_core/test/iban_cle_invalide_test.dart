import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// P2-252 : un IBAN de forme française à clé invalide est masqué en entier,
/// jamais en partie. Cas synthétiques, aucune valeur réelle : les IBAN sont
/// fabriqués par le générateur du banc (graine 42), clé volontairement fausse.
void main() {
  // Deux pièges du corpus d'identifiants (graine 42, 200 000 documents) où une
  // fenêtre de neuf chiffres passe Luhn par hasard : avant P2-252, le FINESS
  // masquait neuf chiffres et laissait le reste en clair.
  const compact = 'FR426729284566735F522327436';
  const groupe = 'FR24 2714 2872 6996 4N17 7449 410';

  final avant = EcluseEngine(const [
    LegacyDetectorAdapter(IbanFrDetector(), DetectorTier.structural,
        name: 'iban'),
    FinessDetector(),
  ]);
  final apres = EcluseEngine(const [
    LegacyDetectorAdapter(IbanFrDetector(), DetectorTier.structural,
        name: 'iban'),
    LegacyDetectorAdapter(IbanCleInvalideDetector(), DetectorTier.structural,
        name: 'iban_cle'),
    FinessDetector(),
  ]);

  group('défaut de départ (sans IbanCleInvalideDetector)', () {
    for (final iban in [compact, groupe]) {
      test('« $iban » : masqué en partie comme FINESS', () async {
        final texte = "L'IBAN $iban a été refusé par la banque.";
        final debut = texte.indexOf(iban);
        final resultat = (await avant.run(texte)).entities;
        expect(resultat, hasLength(1));
        expect(resultat.single.type, EntityType.finess);
        // Partiel : ni le début ni la fin de l'IBAN ne sont couverts.
        expect(
            resultat.single.start > debut ||
                resultat.single.end < debut + iban.length,
            isTrue);
      });
    }
  });

  group('IbanCleInvalideDetector', () {
    const detecteur = IbanCleInvalideDetector();

    test('IBAN à clé invalide : une entité iban, confiance 0,3, empan entier',
        () {
      final texte = "L'IBAN $groupe a été refusé.";
      final e = detecteur.detect(texte);
      expect(e, hasLength(1));
      expect(e.single.type, EntityType.iban);
      expect(e.single.confidence, IbanCleInvalideDetector.confidence);
      expect(e.single.value, groupe);
      expect(texte.substring(e.single.start, e.single.end), groupe);
    });

    test('IBAN valide : rien (déjà couvert à confiance 1,0)', () {
      expect(
          detecteur.detect('IBAN FR76 3000 6000 0112 3456 7890 189'), isEmpty);
      expect(detecteur.detect('FR7630006000011234567890189'), isEmpty);
    });

    test('blancs insécables et multiples : empan entier', () {
      const nbsp = ' ';
      final iban = 'FR24$nbsp${nbsp}2714$nbsp${nbsp}2872${nbsp}6996'
          '${nbsp}4N17${nbsp}7449${nbsp}410';
      final e = detecteur.detect('IBAN $iban refusé');
      expect(e, hasLength(1));
      expect(e.single.value, iban);
    });

    test('rejets : trop court, trop long, enchâssé, autre pays, pas un IBAN',
        () {
      expect(detecteur.detect('FR24 2714 2872 6996 4N17 7449'), isEmpty);
      expect(detecteur.detect('FR24271428726996 4N17 7449 4101 2'), isEmpty);
      expect(detecteur.detect('xFR242714287269964N177449410'), isEmpty);
      expect(detecteur.detect('DE89370400440532013000'), isEmpty);
      expect(detecteur.detect('Frais 2714 2872 6996, FRANCE entière'), isEmpty);
    });

    test('aucune valeur du texte dans le toString d\'une entité', () {
      final e = detecteur.detect(groupe).single;
      expect(e.toString(), isNot(contains('2714')));
    });
  });

  group('moteur avec IbanCleInvalideDetector', () {
    for (final iban in [compact, groupe]) {
      test('« $iban » : masqué en entier, aucun FINESS partiel', () async {
        final texte = "L'IBAN $iban a été refusé par la banque.";
        final debut = texte.indexOf(iban);
        final resultat = (await apres.run(texte)).entities;
        expect(resultat, hasLength(1));
        expect(resultat.single.type, EntityType.iban);
        expect(resultat.single.start, debut);
        expect(resultat.single.end, debut + iban.length);
      });
    }

    test('IBAN valide : confiance 1,0 inchangée', () async {
      final r =
          (await apres.run('IBAN FR76 3000 6000 0112 3456 7890 189')).entities;
      expect(r, hasLength(1));
      expect(r.single.confidence, 1.0);
    });

    test('FINESS valide sans IBAN autour : inchangé', () async {
      final r = (await apres.run('FINESS 750712184')).entities;
      expect(r.single.type, EntityType.finess);
    });
  });

  group('IbanDetector (SEPA), option cleInvalideFr', () {
    const iban = 'FR24 2714 2872 6996 4N17 7449 410';

    test(
        'par défaut : comportement d\'avant, l\'IBAN à clé invalide est ignoré',
        () {
      expect(const IbanDetector().detect('IBAN $iban'), isEmpty);
    });

    test('activée : IBAN à clé invalide en entier à 0,3, valide à 1,0', () {
      const d = IbanDetector(cleInvalideFr: true);
      final e = d.detect('IBAN $iban puis FR76 3000 6000 0112 3456 7890 189');
      expect(e.map((x) => x.confidence), [0.3, 1.0]);
      expect(e.first.value, iban);
    });

    test('activée : IBAN d\'un autre pays à clé invalide toujours ignoré', () {
      const d = IbanDetector(cleInvalideFr: true);
      expect(d.detect('IBAN DE88 3704 0044 0532 0130 00'), isEmpty);
    });
  });
}
