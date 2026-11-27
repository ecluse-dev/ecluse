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

    // P2-313 : quatorze chiffres de Luhn juste qui se lisent comme un
    // horodatage AAAAMMJJhhmmss valide (année 1900 à 2099, jour du calendrier,
    // heure, minutes et secondes) sont des dates et heures, pas des SIRET
    // possibles : sur le corpus de P2-311, les 36 horodatages de Luhn juste
    // étaient tous signalés à tort. Valeurs synthétiques de clé juste.
    test('horodatage valide : rien d\'écarté (collé ou en groupes)', () {
      for (final v in [
        '20261127143000',
        '19000101000007',
        '20991231235959',
        '202 611 271 43000', // groupé : mêmes quatorze chiffres
      ]) {
        final t = 'Export généré $v par la tâche de nuit.';
        expect(FinessDetector.ecartesSiret(t), isEmpty, reason: v);
      }
    });

    test(
        'presque un horodatage : toujours écarté (année, mois, jour, heure, '
        'minutes hors bornes)', () {
      for (final v in [
        '18991231143009', // année 1899
        '21000101143001', // année 2100
        '20261331143002', // mois 13
        '20260230143006', // 30 février
        '20261127243008', // 24 h
        '20261127146003', // minute 60
      ]) {
        final t = 'Merci de recopier $v dans la case.';
        final e = FinessDetector.ecartesSiret(t);
        expect(e, hasLength(1), reason: v);
        expect(t.substring(e.single.start, e.single.end), v);
      }
    });

    test('avec le mot « siret » : un horodatage est masqué comme avant',
        () async {
      final r = await const FinessDetector()
          .detect(NormalizedText.identity('SIRET 20261127143000 noté'));
      expect(r.where((e) => e.type == EntityType.siren), hasLength(1));
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
