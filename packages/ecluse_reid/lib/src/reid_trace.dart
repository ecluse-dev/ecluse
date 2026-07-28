import 'package:ecluse_reference/ecluse_reference.dart';

import 'estimator.dart';
import 'generalizer.dart';
import 'labels.dart';
import 'qi.dart';
import 'risk_band.dart';

/// Type de sortie de la boucle de ré-identification (spec §5) : succès (F
/// déjà acceptable), suggestion (une généralisation ramène F au-dessus du
/// seuil), épuisement (même la meilleure généralisation ne suffit pas —
/// `ecluse_reid` rend la main, il ne décide pas seul).
enum TraceOutcome { succes, suggestion, epuisement }

/// Trace d'audit + explication (spec §7) — une seule structure, deux
/// usages : [toAuditMap] (preuve AIPD) et [explainNarrative] (récit lisible
/// DPO).
class ReidTrace {
  const ReidTrace({
    required this.qisInitiaux,
    required this.estimateInitial,
    required this.outcome,
    required this.suggestion,
    required this.candidats,
    required this.seuilVise,
    required this.bandeFinale,
    required this.qisBloquants,
    required this.notes,
  });

  final List<Qi> qisInitiaux;
  final ReidEstimate estimateInitial;
  final TraceOutcome outcome;

  /// La généralisation retenue, ou `null` si succès immédiat ou épuisement
  /// sans aucun candidat exploitable.
  final Generalization? suggestion;

  /// Toutes les tentatives simulées (spec §7 : sert l'audit), vide si
  /// succès immédiat.
  final List<GeneralizationCandidate> candidats;

  final int seuilVise;
  final RiskBand bandeFinale;

  /// Types de QI bloquants, non vide seulement en cas d'épuisement.
  final List<QiType> qisBloquants;

  /// Contrat d'honnêteté (spec §6) + hypothèses de calcul.
  final List<String> notes;

  /// Récit lisible DPO (spec §7, usage 1).
  String explainNarrative(EcluseReference ref) {
    final combinaison =
        qisInitiaux.map((qi) => qiValueLabel(ref, qi)).join(', ');
    final buffer = StringBuffer();
    buffer.writeln(
      'Combinaison [$combinaison] : F ≈ ${estimateInitial.f.toStringAsFixed(2)}, '
      'risque ${estimateInitial.band.name.toUpperCase()}.',
    );

    switch (outcome) {
      case TraceOutcome.succes:
        buffer.writeln('Rien à généraliser (F ≥ seuil visé $seuilVise).');
      case TraceOutcome.suggestion:
        final s = suggestion!;
        buffer.writeln(
          'Généralisation suggérée : ${s.from.type.name} '
          '${qiValueLabel(ref, s.from)} -> ${qiValueLabel(ref, s.to)} '
          '(F : ${s.fBefore.toStringAsFixed(2)} -> '
          '${s.fAfter.toStringAsFixed(2)}, risque devient '
          '${s.bandAfter.name.toUpperCase()}).',
        );
      case TraceOutcome.epuisement:
        buffer.writeln(
          'Même après la meilleure généralisation possible, le risque reste '
          'au-dessus du seuil visé ($seuilVise). QI bloquants : '
          '${qisBloquants.map((t) => t.name).join(', ')}. Décision humaine '
          'requise : envoyer en assumant le risque / retirer le QI / '
          'renoncer.',
        );
    }

    for (final note in notes) {
      buffer.writeln(note);
    }
    return buffer.toString().trimRight();
  }

  /// Dump structuré pour preuve d'audit AIPD (spec §7, usage 2),
  /// JSON-sérialisable (types primitifs / String uniquement).
  Map<String, Object?> toAuditMap() {
    return {
      'qisInitiaux': [for (final qi in qisInitiaux) qi.toString()],
      'fInitial': estimateInitial.f,
      'bandeInitiale': estimateInitial.band.name,
      'typeDeSortie': outcome.name,
      'seuilVise': seuilVise,
      'bandeFinale': bandeFinale.name,
      'qisBloquants': [for (final t in qisBloquants) t.name],
      'candidats': [
        for (final c in candidats)
          {
            'qiConcerne': c.type.name,
            'niveauAvant': c.from.level,
            'niveauApres': c.to?.level,
            'fAvant': c.fBefore,
            'fApres': c.fAfter,
            'raisonDuChoix': c.raison,
            'retenu': c.retenu,
          },
      ],
      'notes': notes,
    };
  }

  @override
  String toString() => 'ReidTrace(${outcome.name}, F='
      '${estimateInitial.f}, bande finale=${bandeFinale.name})';
}
