import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// P2-307 : `FinessDetector.ecartesSiret` et `ecartesTva` rendent les bornes
/// (jamais la valeur) de ce que le détecteur ne masque pas faute de contexte.
/// Valeurs synthétiques : SIRET de clé juste 732 829 320 00009, TVA de clé
/// juste FR44 732829320 (on met 51).
void main() {
  group('ecartesSiret', () {
    test('clé juste sans le mot : bornes exactes, groupes et collé', () {
      for (final v in ['732 829 320 00009', '73282932000009']) {
        final t = 'Merci de recopier $v dans la case.';
        final e = FinessDetector.ecartesSiret(t);
        expect(e, hasLength(1), reason: v);
        expect(t.substring(e.single.start, e.single.end), v);
      }
    });

    test('avec le mot « siret » : rien d\'écarté', () {
      expect(
          FinessDetector.ecartesSiret('SIRET 732 829 320 00009 noté'), isEmpty);
    });

    test('clé fausse : rien (un nombre ordinaire)', () {
      expect(
          FinessDetector.ecartesSiret('Valeur 73282932000001 notée'), isEmpty);
    });
  });

  group('ecartesTva', () {
    test('clé fausse sans libellé : bornes exactes', () {
      const t = 'Merci de recopier FR51732829320 dans la case.';
      final e = FinessDetector.ecartesTva(t);
      expect(e, hasLength(1));
      expect(t.substring(e.single.start, e.single.end), 'FR51732829320');
    });

    test('libellé ou clé juste : rien d\'écarté', () {
      expect(FinessDetector.ecartesTva('TVA FR51732829320 notée'), isEmpty);
      expect(FinessDetector.ecartesTva('Valeur FR44732829320 notée'), isEmpty);
    });
  });
}
