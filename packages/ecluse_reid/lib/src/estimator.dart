import 'package:ecluse_reference/ecluse_reference.dart';

import 'age_bands.dart';
import 'honesty.dart';
import 'lieu_population.dart';
import 'profession_rarity.dart';
import 'qi.dart';
import 'risk_band.dart';

/// Résultat de l'estimation de rareté pour une combinaison de QI (spec §3,
/// §8).
class ReidEstimate {
  const ReidEstimate(
      this.f, this.band, this.dominant, this.upperBound, this.notes);

  /// Taille estimée de la classe d'équivalence.
  final double f;
  final RiskBand band;

  /// Le QI qui pèse le plus dans l'estimation, ou `null` si aucun QI n'a été
  /// fourni.
  final QiType? dominant;

  /// `true` au Cas A (profession) : [f] est un effectif réel d'une
  /// sous-population, donc une borne haute — la classe réelle est plus
  /// petite mais non quantifiée.
  final bool upperBound;

  /// Contrat d'honnêteté (spec §6) + hypothèses spécifiques à ce calcul.
  final List<String> notes;

  @override
  bool operator ==(Object other) =>
      other is ReidEstimate &&
      other.f == f &&
      other.band == band &&
      other.dominant == dominant &&
      other.upperBound == upperBound;

  @override
  int get hashCode => Object.hash(f, band, dominant, upperBound);

  @override
  String toString() =>
      'ReidEstimate(F=$f, ${band.name}, dominant: ${dominant?.name}, '
      'upperBound: $upperBound)';
}

/// Estime F pour une liste de QI (spec §3). Fonction pure vis-à-vis de
/// [ref] (déterministe, testable indépendamment de `ReidLoop`).
///
/// Contraintes (lèvent [ArgumentError]) :
/// - au plus un QI par [QiType] (pas d'ambiguïté ce jalon) ;
/// - un QI `profession` exige un QI `lieu` de niveau 0 (commune) ou 1
///   (département), pour résoudre le département (Cas A, spec §3).
ReidEstimate estimate(EcluseReference ref, List<Qi> qis) {
  _checkNoDuplicateTypes(qis);
  // Un QI à la valeur sentinelle de retrait n'est plus une contrainte sur la
  // classe d'équivalence : on le traite comme absent de la combinaison
  // (dernier palier des échelles âge et profession, spec §4).
  final active = qis.where((q) => q.value != qiRetraitValue).toList();
  final profession = _find(active, QiType.profession);
  final lieu = _find(active, QiType.lieu);
  final age = _find(active, QiType.age);

  if (profession != null) return _estimateCasA(ref, profession, lieu);
  return _estimateCasB(ref, lieu, age);
}

Qi? _find(List<Qi> qis, QiType type) {
  final matches = qis.where((q) => q.type == type);
  return matches.isEmpty ? null : matches.first;
}

void _checkNoDuplicateTypes(List<Qi> qis) {
  for (final type in QiType.values) {
    final count = qis.where((q) => q.type == type).length;
    if (count > 1) {
      throw ArgumentError(
        'Un seul QI par type est accepté ce jalon (type en double : '
        '${type.name}).',
      );
    }
  }
}

/// Cas A (spec §3) : un QI profession de santé est présent. F = effectif
/// réel d'une sous-population (borne haute) — on ne multiplie **pas** par
/// âge/sexe (la structure d'âge d'une profession n'est pas celle de la
/// population générale ; honnêteté > drame).
ReidEstimate _estimateCasA(EcluseReference ref, Qi profession, Qi? lieu) {
  if (lieu == null) {
    throw ArgumentError(
      'profession: un QI lieu (commune ou département) est requis pour '
      'résoudre le département — spec §3 Cas A.',
    );
  }
  final dep = depForLieu(ref, lieu);

  final int f;
  if (profession.value == professionnelDeSante) {
    f = professionnelDeSanteCount(ref.rarity, dep);
  } else if (profession.value == professionToutesSpecialites) {
    f = medecinTouteSpecialite(ref.rarity, dep);
  } else if (ref.rarity.specialtyCodes().contains(profession.value)) {
    f = ref.rarity.medecinsCount(dep, profession.value) ?? 0;
  } else if (ref.rarity.professions().contains(profession.value)) {
    f = ref.rarity.professionCount(profession.value, dep) ?? 0;
  } else {
    throw ArgumentError(
      'profession: code "${profession.value}" inconnu (ni spécialité DREES, '
      'ni profession référencée).',
    );
  }

  return ReidEstimate(
    f.toDouble(),
    bandForF(f.toDouble()),
    QiType.profession,
    true,
    honestyNotes(upperBound: true),
  );
}

/// Cas B (spec §3) : pas de profession, F ≈ population(lieu) × part-âge,
/// sous hypothèse d'indépendance lieu × âge (explicitement notée — jamais
/// de facteur sexe : hors périmètre §1 ce jalon).
ReidEstimate _estimateCasB(EcluseReference ref, Qi? lieu, Qi? age) {
  final extraNotes = <String>[];

  final int population;
  if (lieu != null) {
    population = populationForLieu(ref, lieu);
  } else {
    population = ref.age.totalPopulation;
    extraNotes.add(
      'Aucun lieu fourni : estimation sur la population de référence '
      'France entière (équivalent à lieu = France).',
    );
  }

  final double share;
  if (age != null) {
    share = _shareForAgeQi(ref.age, age);
  } else {
    share = 1.0;
    if (lieu != null) {
      extraNotes.add(
        "Aucun âge fourni : la classe d'équivalence n'est pas filtrée par "
        'âge (F = population du lieu seul).',
      );
    }
  }

  if (lieu == null && age == null) {
    extraNotes.add('Aucun QI fourni : F = population de référence totale.');
  }

  final f = population * share;

  final QiType? dominant;
  if (lieu != null && age != null) {
    final fLieuAlone = population.toDouble();
    final fAgeAlone = ref.age.totalPopulation * share;
    dominant = fLieuAlone <= fAgeAlone ? QiType.lieu : QiType.age;
  } else if (lieu != null) {
    dominant = QiType.lieu;
  } else if (age != null) {
    dominant = QiType.age;
  } else {
    dominant = null;
  }

  return ReidEstimate(
    f,
    bandForF(f),
    dominant,
    false,
    honestyNotes(upperBound: false, extra: extraNotes),
  );
}

/// Part de la population à l'âge/tranche d'âge du QI [ageQi], selon son
/// niveau (0=âge exact, 1-3=tranche généralisée, 4=retrait -> 1.0, pas de
/// filtre).
double _shareForAgeQi(AgeRarity age, Qi ageQi) {
  switch (ageQi.level) {
    case 0:
      return age.shareAtAge(int.parse(ageQi.value));
    case 1:
    case 2:
    case 3:
      final range = parseAgeRange(ageQi.value);
      return shareForRange(age, range.$1, range.$2);
    default:
      return 1.0; // niveau 4 : retrait, pas de filtre âge
  }
}
