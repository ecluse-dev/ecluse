import 'package:ecluse_reference/ecluse_reference.dart';

import 'estimator.dart';
import 'generalizer.dart';
import 'qi.dart';
import 'reid_trace.dart';
import 'risk_band.dart';

/// Boucle de ré-identification (spec §8) : estime, suggère une
/// généralisation, explique — sur une combinaison de QI fournie par
/// l'appelant. Ne masque rien, ne décide rien seul (l'épuisement rend la
/// main à l'humain, spec §5/§10).
class ReidLoop {
  ReidLoop(this._ref, {this.threshold = thresholdStandard});

  final EcluseReference _ref;

  /// Seuil d'acceptabilité (F minimal visé). Standard par défaut ce jalon
  /// (pas d'UI de réglage, spec §10) ; `threshold` reste un paramètre de
  /// constructeur pour permettre Renforcé/Strict par du code appelant.
  final int threshold;

  /// Estime F pour [qis] (spec §3).
  ReidEstimate assess(List<Qi> qis) => estimate(_ref, qis);

  /// Suggère la meilleure généralisation d'un cran (spec §4).
  ///
  /// Renvoie `null` si F ≥ seuil (rien à suggérer, spec §5 Succès) OU si
  /// plus aucun QI présent ne peut être généralisé davantage (épuisement
  /// total, aucun candidat exploitable). Dans ce dernier cas, [explain]
  /// distingue via `ReidTrace.outcome == TraceOutcome.epuisement` avec
  /// `suggestion == null`.
  ///
  /// Exception au Cas A (borne haute, `ReidEstimate.upperBound == true`) :
  /// le raccourci « succès si F ≥ seuil » ne s'applique pas, car F y est un
  /// effectif réel de sous-population, pas la vraie classe d'équivalence
  /// (rôle/commune la réduisent, non quantifié) — la suggestion est donc
  /// toujours calculée dans ce cas.
  Generalization? suggest(List<Qi> qis) => _evaluate(qis).suggestion;

  /// Estimation + suggestion + trace complète (spec §7).
  ReidTrace explain(List<Qi> qis) => _evaluate(qis);

  ReidTrace _evaluate(List<Qi> qis) {
    final initial = estimate(_ref, qis);

    // Cas A (borne haute) : F >= seuil ne garantit pas que la vraie classe
    // d'équivalence (plus petite, non quantifiée par rôle/commune) dépasse
    // aussi le seuil — on calcule donc toujours la suggestion plutôt que de
    // conclure au succès sur la seule valeur nominale de F (spec §6 : la
    // borne haute n'est pas une garantie).
    if (!initial.upperBound && initial.f >= threshold) {
      return ReidTrace(
        qisInitiaux: qis,
        estimateInitial: initial,
        outcome: TraceOutcome.succes,
        suggestion: null,
        candidats: const [],
        seuilVise: threshold,
        bandeFinale: initial.band,
        qisBloquants: const [],
        notes: initial.notes,
      );
    }

    final candidats = simulateOneStep(_ref, qis, initial);
    GeneralizationCandidate? winner;
    for (final candidate in candidats) {
      if (candidate.retenu) {
        winner = candidate;
        break;
      }
    }

    if (winner == null) {
      return ReidTrace(
        qisInitiaux: qis,
        estimateInitial: initial,
        outcome: TraceOutcome.epuisement,
        suggestion: null,
        candidats: candidats,
        seuilVise: threshold,
        bandeFinale: initial.band,
        qisBloquants: [for (final q in qis) q.type],
        notes: initial.notes,
      );
    }

    final generalization = Generalization(
      winner.from,
      winner.to!,
      winner.fBefore,
      winner.fAfter!,
      initial.band,
      winner.bandAfter!,
    );
    final outcome = winner.fAfter! >= threshold
        ? TraceOutcome.suggestion
        : TraceOutcome.epuisement;

    return ReidTrace(
      qisInitiaux: qis,
      estimateInitial: initial,
      outcome: outcome,
      suggestion: generalization,
      candidats: candidats,
      seuilVise: threshold,
      bandeFinale: winner.bandAfter!,
      qisBloquants: outcome == TraceOutcome.epuisement
          ? [for (final q in qis) q.type]
          : const [],
      notes: initial.notes,
    );
  }
}
