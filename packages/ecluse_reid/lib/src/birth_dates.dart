import 'age_bands.dart';
import 'qi.dart';

/// Date de naissance validée (calendrier grégorien). Sert à dériver un âge et à
/// générer l'échelle de dates (P2-17, spec P2-07 §§ 2.1 et 2.2).
///
/// Ne lit jamais l'horloge : toute dérivation reçoit sa date de référence.
final class BirthDate {
  /// Lève [ArgumentError] pour une date qui n'existe pas (mois hors 1-12,
  /// 31 avril, 29 février d'une année non bissextile, année < 1).
  BirthDate(this.year, this.month, this.day) {
    if (year < 1) throw ArgumentError.value(year, 'year', 'au moins 1');
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'entre 1 et 12');
    }
    if (day < 1 || day > _daysIn(year, month)) {
      throw ArgumentError.value(day, 'day', 'jour inexistant ce mois-ci');
    }
  }

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is BirthDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'BirthDate($year-$month-$day)';
}

bool _isLeap(int year) => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

int _daysIn(int year, int month) => switch (month) {
      2 => _isLeap(year) ? 29 : 28,
      4 || 6 || 9 || 11 => 30,
      _ => 31,
    };

/// Date de référence : (année, mois, jour).
typedef ReferenceDate = (int year, int month, int day);

/// Âge en années révolues de [birth] à la date [reference], fournie par
/// l'appelant (jamais l'horloge système : les résultats sont reproductibles).
///
/// Le jour de l'anniversaire, l'âge change. Une naissance un 29 février a son
/// anniversaire le 1er mars les années non bissextiles. Lève [ArgumentError]
/// si [reference] est invalide ou antérieure à la naissance.
int ageOn(BirthDate birth, ReferenceDate reference) {
  final (ry, rm, rd) = reference;
  // Valide la date de référence avec les mêmes règles que la naissance.
  final ref = BirthDate(ry, rm, rd);
  final reached = _compare(ref, birth);
  if (reached < 0) {
    throw ArgumentError.value(
        reference, 'reference', 'antérieure à la date de naissance');
  }
  var age = ref.year - birth.year;
  if (!_birthdayReached(birth, ref)) age -= 1;
  return age;
}

int _compare(BirthDate a, BirthDate b) {
  if (a.year != b.year) return a.year - b.year;
  if (a.month != b.month) return a.month - b.month;
  return a.day - b.day;
}

bool _birthdayReached(BirthDate birth, BirthDate ref) {
  var month = birth.month;
  var day = birth.day;
  // Anniversaire d'un 29 février en année non bissextile : le 1er mars.
  if (month == 2 && day == 29 && !_isLeap(ref.year)) {
    month = 3;
    day = 1;
  }
  if (ref.month != month) return ref.month > month;
  return ref.day >= day;
}

/// Paliers de généralisation d'une date de naissance, du plus précis au retrait
/// (`CONCEPTION_BOUCLE.md`, « Date »). Chaque passage au palier suivant est
/// irréversible ; le moteur ne l'applique jamais de lui-même.
enum DateRung { exacte, moisAnnee, annee, decennie, retrait }

/// Palier suivant, ou `null` après le retrait.
DateRung? nextDateRung(DateRung rung) => switch (rung) {
      DateRung.exacte => DateRung.moisAnnee,
      DateRung.moisAnnee => DateRung.annee,
      DateRung.annee => DateRung.decennie,
      DateRung.decennie => DateRung.retrait,
      DateRung.retrait => null,
    };

/// Représentation de [birth] à un [rung] donné : `JJ/MM/AAAA`, `MM/AAAA`,
/// `AAAA`, `AAAA-AAAA` (décennie) ou [qiRetraitValue].
String formatBirthDate(BirthDate birth, DateRung rung) {
  String two(int n) => n.toString().padLeft(2, '0');
  switch (rung) {
    case DateRung.exacte:
      return '${two(birth.day)}/${two(birth.month)}/${birth.year}';
    case DateRung.moisAnnee:
      return '${two(birth.month)}/${birth.year}';
    case DateRung.annee:
      return '${birth.year}';
    case DateRung.decennie:
      final lo = (birth.year ~/ 10) * 10;
      return '$lo-${lo + 9}';
    case DateRung.retrait:
      return qiRetraitValue;
  }
}

/// Seuil du palier « grands âges » (décision P2-07, `DECISIONS.md`).
const int oldestAgeThreshold = 85;

/// Tranche « 85 et plus » ou « 0 à 84 » contenant [age]. Les grands âges sont
/// fortement ré-identifiants (peu d'individus) : le palier évite de passer par
/// des tranches de 5 ou 10 ans qui isoleraient encore quelques personnes.
AgeRange oldestBand(int age) => age >= oldestAgeThreshold
    ? (oldestAgeThreshold, seniorMaxAgeCap)
    : (0, oldestAgeThreshold - 1);
