import 'package:ecluse_reference/ecluse_reference.dart';

/// Échelle de généralisation de l'âge (spec §4). Le spec ne fixe pas les
/// bornes exactes ; celles-ci sont un choix documenté de ce jalon :
/// - tranche 5 ans : `[floor(age/5)*5, +4]` (ex. 89 -> [85, 89]).
/// - tranche 10 ans : `[floor(age/10)*10, +9]` (ex. 89 -> [80, 89]).
/// - « senior » : symétrique à [seniorThreshold], défini pour tout âge (pas
///   seulement les personnes âgées) : âge >= seuil -> senior, sinon
///   « non-senior ».
/// - retrait : géré par l'estimateur via [qiRetraitValue], pas une plage.
const int seniorThreshold = 65;

/// Borne haute utilisée pour représenter la tranche senior. Sans incidence
/// sur le calcul : `AgeRarity.countAtAge` renvoie 0 (via `?? 0`) pour tout
/// âge hors des données réelles (~0-120 ans dans `age_pyramide.json`).
const int seniorMaxAgeCap = 130;

/// Plage d'âge inclusive `[lo, hi]`.
typedef AgeRange = (int lo, int hi);

/// Tranche 5 ans contenant [age].
AgeRange band5(int age) {
  final lo = (age ~/ 5) * 5;
  return (lo, lo + 4);
}

/// Tranche 10 ans contenant [age].
AgeRange band10(int age) {
  final lo = (age ~/ 10) * 10;
  return (lo, lo + 9);
}

/// Tranche « senior » (>= [seniorThreshold]) ou « non-senior » contenant
/// [age].
AgeRange seniorBand(int age) => age >= seniorThreshold
    ? (seniorThreshold, seniorMaxAgeCap)
    : (0, seniorThreshold - 1);

/// Somme `AgeRarity.countAtAge` sur `[lo, hi]` inclus (âges absents des
/// données traités comme 0), divisée par `AgeRarity.totalPopulation`.
///
/// Pas d'aide de plage dans `ecluse_reference` (confirmé : `countAtAge` et
/// `totalPopulation` sont publics) — on somme ici plutôt que d'étendre le
/// package de référence pour ce seul besoin.
double shareForRange(AgeRarity age, int lo, int hi) {
  var count = 0;
  for (var a = lo; a <= hi; a++) {
    count += age.countAtAge(a) ?? 0;
  }
  return count / age.totalPopulation;
}

/// Formate une plage `(lo, hi)` en la représentation `"lo-hi"` stockée dans
/// `Qi.value` pour un QI âge généralisé.
String formatAgeRange(AgeRange range) => '${range.$1}-${range.$2}';

/// Parse la représentation `"lo-hi"` d'un QI âge généralisé.
AgeRange parseAgeRange(String value) {
  final parts = value.split('-');
  return (int.parse(parts[0]), int.parse(parts[1]));
}
