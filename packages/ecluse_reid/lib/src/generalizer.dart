import 'package:ecluse_reference/ecluse_reference.dart';

import 'age_bands.dart';
import 'estimator.dart';
import 'qi.dart';
import 'risk_band.dart';

/// Une généralisation suggérée : le QI avant/après, F avant/après, bande
/// avant/après (spec §4, §8).
class Generalization {
  const Generalization(this.from, this.to, this.fBefore, this.fAfter,
      this.bandBefore, this.bandAfter);

  final Qi from;
  final Qi to;
  final double fBefore;
  final double fAfter;
  final RiskBand bandBefore;
  final RiskBand bandAfter;

  @override
  bool operator ==(Object other) =>
      other is Generalization &&
      other.from == from &&
      other.to == to &&
      other.fBefore == fBefore &&
      other.fAfter == fAfter &&
      other.bandBefore == bandBefore &&
      other.bandAfter == bandAfter;

  @override
  int get hashCode =>
      Object.hash(from, to, fBefore, fAfter, bandBefore, bandAfter);

  @override
  String toString() => 'Generalization($from -> $to, F: $fBefore -> '
      '$fAfter, ${bandBefore.name} -> ${bandAfter.name})';
}

/// Un candidat de généralisation simulé pour un QI présent (§4) — retenu ou
/// non selon `simulateOneStep`.
class GeneralizationCandidate {
  const GeneralizationCandidate({
    required this.type,
    required this.from,
    this.to,
    required this.fBefore,
    this.fAfter,
    this.bandAfter,
    required this.retenu,
    required this.raison,
  });

  final QiType type;
  final Qi from;

  /// `null` si aucun palier de généralisation n'est disponible pour ce QI.
  final Qi? to;
  final double fBefore;

  /// `null` si [to] est `null`.
  final double? fAfter;

  /// `null` si [to] est `null`.
  final RiskBand? bandAfter;
  final bool retenu;
  final String raison;
}

/// Palier suivant d'un QI selon son échelle propre, ou `null` si aucun
/// palier supplémentaire n'est disponible/calculable ce jalon.
Qi? nextRung(EcluseReference ref, Qi qi) {
  switch (qi.type) {
    case QiType.lieu:
      return _nextLieuRung(ref, qi);
    case QiType.age:
      return _nextAgeRung(qi);
    case QiType.profession:
      return _nextProfessionRung(qi);
  }
}

/// Échelle lieu : commune(0) -> département(1) -> France(4). Les niveaux
/// région(2)/grande zone(3) sont sautés — non agrégeables ce jalon (voir
/// `lieu_population.dart`).
Qi? _nextLieuRung(EcluseReference ref, Qi qi) {
  switch (qi.level) {
    case 0:
      final commune = ref.geo.communeByCode(qi.value);
      if (commune == null) return null;
      return Qi(QiType.lieu, commune.dep, level: 1);
    case 1:
      return Qi(QiType.lieu, lieuFrance, level: 4);
    default:
      return null;
  }
}

/// Échelle âge : exact(0) -> tranche 5 ans(1) -> tranche 10 ans(2) ->
/// senior(3) -> retrait(4).
Qi? _nextAgeRung(Qi qi) {
  switch (qi.level) {
    case 0:
      final age = int.parse(qi.value);
      return Qi(QiType.age, formatAgeRange(band5(age)), level: 1);
    case 1:
      final lo = parseAgeRange(qi.value).$1;
      return Qi(QiType.age, formatAgeRange(band10(lo)), level: 2);
    case 2:
      final lo = parseAgeRange(qi.value).$1;
      return Qi(QiType.age, formatAgeRange(seniorBand(lo)), level: 3);
    case 3:
      return const Qi(QiType.age, qiRetraitValue, level: 4);
    default:
      return null;
  }
}

/// Échelle profession : spécialité(0) -> « médecin toute spécialité »(1) ->
/// « professionnel de santé »(2) -> retrait(3).
Qi? _nextProfessionRung(Qi qi) {
  switch (qi.level) {
    case 0:
      return const Qi(QiType.profession, professionToutesSpecialites, level: 1);
    case 1:
      return const Qi(QiType.profession, professionnelDeSante, level: 2);
    case 2:
      return const Qi(QiType.profession, qiRetraitValue, level: 3);
    default:
      return null;
  }
}

/// Simule la généralisation d'un cran de chaque QI présent dans [qis], et
/// désigne le candidat qui fait le plus remonter F (spec §4 — UN levier,
/// pas de boucle multi-crans).
///
/// Priorité de départage en cas d'égalité stricte de `fAfter` : profession >
/// lieu > age (choix arbitraire mais fixe et documenté).
///
/// Note de conception : certains candidats ne changent pas F (ex.
/// généraliser `lieu` de commune à département en Cas A, alors que le
/// département était déjà résolu identiquement) ou ne sont plus
/// recalculables du tout (ex. généraliser `lieu` au-delà du département en
/// Cas A, qui casse la résolution du département) — dans les deux cas, ce
/// candidat ne gagne jamais face à un candidat qui améliore réellement F ;
/// pas besoin de cas particulier, la simulation uniforme (avec capture des
/// combinaisons non calculables, voir plus bas) est sûre.
List<GeneralizationCandidate> simulateOneStep(
  EcluseReference ref,
  List<Qi> qis,
  ReidEstimate baseline,
) {
  final candidates = <GeneralizationCandidate>[];
  for (final qi in qis) {
    final rung = nextRung(ref, qi);
    if (rung == null) {
      candidates.add(GeneralizationCandidate(
        type: qi.type,
        from: qi,
        fBefore: baseline.f,
        retenu: false,
        raison: 'Aucun palier de généralisation disponible (déjà au maximum '
            'calculable ce jalon).',
      ));
      continue;
    }
    final modified = [
      for (final q in qis) q.type == qi.type ? rung : q,
    ];
    // Certaines combinaisons généralisées ne sont pas recalculables (ex. le
    // lieu passé au-delà du département casse la résolution du département
    // exigée par le Cas A profession) : ce candidat n'est alors simplement
    // pas exploitable, pas une erreur de la simulation elle-même.
    ReidEstimate? after;
    try {
      after = estimate(ref, modified);
    } on ArgumentError {
      after = null;
    }
    candidates.add(GeneralizationCandidate(
      type: qi.type,
      from: qi,
      to: rung,
      fBefore: baseline.f,
      fAfter: after?.f,
      bandAfter: after?.band,
      retenu: false,
      raison: after == null
          ? 'Généralisation non applicable dans cette combinaison '
              '(recalcul impossible).'
          : 'F : ${baseline.f.toStringAsFixed(2)} -> '
              '${after.f.toStringAsFixed(2)}.',
    ));
  }
  return _markWinner(candidates);
}

/// Priorité de départage des égalités (spec §4 : un seul candidat retenu).
const List<QiType> _tieBreakPriority = [
  QiType.profession,
  QiType.lieu,
  QiType.age,
];

List<GeneralizationCandidate> _markWinner(
  List<GeneralizationCandidate> candidates,
) {
  final withResult = candidates.where((c) => c.fAfter != null).toList();
  if (withResult.isEmpty) return candidates;

  GeneralizationCandidate winner = withResult.first;
  for (final candidate in withResult.skip(1)) {
    final better = candidate.fAfter! > winner.fAfter! ||
        (candidate.fAfter == winner.fAfter &&
            _tieBreakPriority.indexOf(candidate.type) <
                _tieBreakPriority.indexOf(winner.type));
    if (better) winner = candidate;
  }

  return [
    for (final candidate in candidates)
      if (identical(candidate, winner))
        GeneralizationCandidate(
          type: candidate.type,
          from: candidate.from,
          to: candidate.to,
          fBefore: candidate.fBefore,
          fAfter: candidate.fAfter,
          bandAfter: candidate.bandAfter,
          retenu: true,
          raison: candidate.raison,
        )
      else if (candidate.fAfter != null)
        GeneralizationCandidate(
          type: candidate.type,
          from: candidate.from,
          to: candidate.to,
          fBefore: candidate.fBefore,
          fAfter: candidate.fAfter,
          bandAfter: candidate.bandAfter,
          retenu: false,
          raison: 'F après généralisation moins élevé que le candidat '
              'retenu (${winner.type.name}).',
        )
      else
        candidate,
  ];
}
