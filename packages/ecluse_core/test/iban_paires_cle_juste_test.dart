import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// P2-283 : IBAN de clé **juste** écrit en paires derrière « FR » + séparateur
/// (`FR 76 30 00 60 00 01 12 34 56 78 90 18 9`). Identifiant synthétique, clé
/// mod 97 vérifiée par le détecteur lui-même (même IBAN de test que
/// `iban_detector_test.dart`).
void main() {
  const fr = IbanFrDetector();
  const sepa = IbanDetector();
  const paires = 'FR 76 30 00 60 00 01 12 34 56 78 90 18 9';

  for (final (nom, d) in <(String, EntityDetector)>[
    ('IbanFrDetector', fr),
    ('IbanDetector', sepa),
  ]) {
    group(nom, () {
      test('masque un IBAN valide écrit en paires, en entier, confiance 1,0',
          () {
        const t = 'Virement vers $paires prévu lundi.';
        final e = d.detect(t);
        expect(e, hasLength(1));
        expect(e.single.type, EntityType.iban);
        expect(e.single.confidence, 1.0);
        expect(t.substring(e.single.start, e.single.end), paires);
        expect(e.single.value, paires);
      });

      test('séparateurs tiret et point', () {
        for (final sep in ['-', '.']) {
          final v = paires.replaceAll(' ', sep);
          final e = d.detect('IBAN : $v ok');
          expect(e, hasLength(1), reason: sep);
          expect(e.single.value, v);
        }
      });

      test('clé fausse : pas émis ici (confiance 0,3 ailleurs)', () {
        final e = d.detect(paires.replaceFirst('76', '77'));
        expect(e, isEmpty);
      });

      test('bornes : suffixe alphanumérique ou préfixe collé refusés', () {
        expect(d.detect('${paires}7'), isEmpty);
        expect(d.detect('X$paires'), isEmpty);
      });

      test('forme stricte : un groupement autre que des paires est refusé', () {
        // Même chiffres, groupes de trois derrière « FR » + séparateur.
        expect(d.detect('FR 76 300 060 000 112 345 678 901 89'), isEmpty);
        // Une paire de moins.
        expect(d.detect('FR 76 30 00 60 00 01 12 34 56 78 90 9'), isEmpty);
      });

      test('une phrase sans IBAN ne donne rien', () {
        expect(d.detect('Rendez-vous en FR 12 et en 2026 à 10 h.'), isEmpty);
      });
    });
  }

  test('la forme compacte et en groupes de quatre reste prise une seule fois',
      () {
    expect(fr.detect('FR7630006000011234567890189'), hasLength(1));
    expect(sepa.detect('FR76 3000 6000 0112 3456 7890 189'), hasLength(1));
  });
}
