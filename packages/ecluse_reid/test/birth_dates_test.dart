import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Échelle de dates de naissance et dérivation d'âge (P2-17, spec P2-07
/// §§ 2.1 et 2.2). Aucun test ne lit l'horloge : la date de référence est
/// toujours fournie.
void main() {
  group('BirthDate', () {
    test('une date valide est acceptée', () {
      final d = BirthDate(1931, 3, 12);
      expect((d.year, d.month, d.day), (1931, 3, 12));
    });

    test('29 février : valide les années bissextiles seulement', () {
      expect(() => BirthDate(2000, 2, 29), returnsNormally);
      expect(() => BirthDate(2024, 2, 29), returnsNormally);
      expect(() => BirthDate(1900, 2, 29), throwsArgumentError);
      expect(() => BirthDate(2025, 2, 29), throwsArgumentError);
    });

    test('mois et jours hors bornes refusés', () {
      expect(() => BirthDate(1990, 0, 10), throwsArgumentError);
      expect(() => BirthDate(1990, 13, 10), throwsArgumentError);
      expect(() => BirthDate(1990, 4, 31), throwsArgumentError);
      expect(() => BirthDate(1990, 4, 0), throwsArgumentError);
      expect(() => BirthDate(0, 4, 10), throwsArgumentError);
    });
  });

  group('ageOn', () {
    test('la veille de l\'anniversaire, l\'âge n\'a pas encore changé', () {
      expect(ageOn(BirthDate(1990, 6, 15), (2026, 6, 14)), 35);
    });

    test('le jour de l\'anniversaire, l\'âge change', () {
      expect(ageOn(BirthDate(1990, 6, 15), (2026, 6, 15)), 36);
    });

    test('le surlendemain du mois, avant l\'anniversaire du mois suivant', () {
      expect(ageOn(BirthDate(1990, 6, 15), (2026, 5, 31)), 35);
      expect(ageOn(BirthDate(1990, 6, 15), (2026, 12, 31)), 36);
    });

    test(
        'naissance un 29 février : anniversaire le 1er mars en année non '
        'bissextile', () {
      final d = BirthDate(2000, 2, 29);
      expect(ageOn(d, (2025, 2, 28)), 24);
      expect(ageOn(d, (2025, 3, 1)), 25);
      expect(ageOn(d, (2024, 2, 29)), 24);
    });

    test('le jour de la naissance, l\'âge est 0', () {
      expect(ageOn(BirthDate(2026, 10, 26), (2026, 10, 26)), 0);
    });

    test('une référence antérieure à la naissance est refusée', () {
      expect(() => ageOn(BirthDate(2026, 10, 26), (2026, 10, 25)),
          throwsArgumentError);
    });

    test('une date de référence invalide est refusée', () {
      expect(() => ageOn(BirthDate(1990, 6, 15), (2026, 2, 30)),
          throwsArgumentError);
    });

    test('résultat identique à chaque appel (aucune horloge)', () {
      final d = BirthDate(1931, 3, 12);
      expect(ageOn(d, (2026, 1, 1)), ageOn(d, (2026, 1, 1)));
      expect(ageOn(d, (2026, 1, 1)), 94);
    });
  });

  group('échelle de dates', () {
    final d = BirthDate(1931, 3, 5);

    test('format de chaque palier', () {
      expect(formatBirthDate(d, DateRung.exacte), '05/03/1931');
      expect(formatBirthDate(d, DateRung.moisAnnee), '03/1931');
      expect(formatBirthDate(d, DateRung.annee), '1931');
      expect(formatBirthDate(d, DateRung.decennie), '1930-1939');
      expect(formatBirthDate(d, DateRung.retrait), qiRetraitValue);
    });

    test('palier suivant : exacte, mois/année, année, décennie, retrait', () {
      expect(nextDateRung(DateRung.exacte), DateRung.moisAnnee);
      expect(nextDateRung(DateRung.moisAnnee), DateRung.annee);
      expect(nextDateRung(DateRung.annee), DateRung.decennie);
      expect(nextDateRung(DateRung.decennie), DateRung.retrait);
      expect(nextDateRung(DateRung.retrait), isNull);
    });

    test('la décennie contient toujours l\'année', () {
      for (final y in [1899, 1900, 1930, 1939, 1940, 2000, 2026]) {
        final texte = formatBirthDate(BirthDate(y, 1, 1), DateRung.decennie);
        final parts = texte.split('-');
        expect(int.parse(parts[0]) <= y && y <= int.parse(parts[1]), isTrue,
            reason: '$y -> $texte');
      }
    });
  });

  group('palier grands âges', () {
    test('85 ans et plus : une tranche 85-130, en dessous 0-84', () {
      expect(oldestBand(85), (85, seniorMaxAgeCap));
      expect(oldestBand(104), (85, seniorMaxAgeCap));
      expect(oldestBand(84), (0, 84));
      expect(oldestBand(0), (0, 84));
    });

    test('la tranche contient toujours l\'âge', () {
      for (var a = 0; a <= 120; a++) {
        final (lo, hi) = oldestBand(a);
        expect(lo <= a && a <= hi, isTrue, reason: '$a');
      }
    });
  });
}
