import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// Rapport de risque de ré-identification d'un texte masqué (P2-04, option A de
/// `agent/specs/P2-03.md`). **Il ne change jamais le texte envoyé** : la
/// généralisation, irréversible, relève de l'appelant.
final class RiskReport {
  const RiskReport({
    required this.evaluation,
    required this.limites,
    this.suggestions = const [],
  });

  /// Évaluation des quasi-identifiants restés dans le **texte masqué** (c'est
  /// lui qui quitte la machine) : statut explicite, estimation ou motifs,
  /// QI repérés avec leur position **dans `maskedText`**, notes d'honnêteté.
  final Evaluation evaluation;

  /// Ce que ce rapport ne voit pas. Toujours présent, quel que soit le statut :
  /// un statut « aucun QI détecté » n'est pas un risque faible.
  final List<String> limites;

  /// Généralisations d'un cran proposées pour faire remonter F (P2-91),
  /// candidat retenu en premier. Vide si rien n'a été évalué, si F atteint
  /// déjà le seuil *Standard* hors borne haute, ou si aucun palier ne fait
  /// remonter F. **Ce sont des propositions** : rien n'est appliqué au texte
  /// (décision P2-03 n° 1, le moteur ne généralise jamais de lui-même).
  final List<SuggestionPositionnee> suggestions;
}

/// Une généralisation proposée et les occurrences du QI concerné dans le
/// **texte masqué** (P2-91).
///
/// Pourquoi le texte masqué : c'est lui qui quitte la machine et que
/// l'appelant généraliserait (option B de P2-03, P2-92). Les positions
/// d'origine n'ont pas de sens ici, les jetons ayant déjà décalé le texte.
final class SuggestionPositionnee {
  const SuggestionPositionnee({
    required this.candidat,
    required this.positions,
  });

  /// Le QI avant et après, F avant et après, et si c'est le candidat retenu
  /// (`retenu`) parmi les autres.
  final GeneralizationCandidate candidat;

  /// Chaque occurrence de `candidat.from` dans le texte masqué. Une commune
  /// ambiguë (QI indéterminé) n'y figure pas : elle n'est pas généralisable
  /// sans savoir laquelle est visée.
  final List<QiSpan> positions;
}

/// Limites de l'extraction actuelle, sans NER (spec P2-03 § 4). À mettre à jour
/// quand le NER (P2-01) sera branché.
const List<String> limitesSansNer = [
  'Rappel limité : les quasi-identifiants ne sont repérés que par des règles '
      '(treize spécialités médicales et quatre professions par mot-clé, '
      'communes par nom capitalisé, âge en chiffres). Un indice formulé '
      "autrement n'est pas vu.",
  'Le rapport porte sur le texte masqué : un quasi-identifiant déjà masqué '
      "par un détecteur (adresse, date de naissance) n'est pas évalué.",
];

/// Évalue [texteMasque] avec [reference]. Ne lève jamais : toute erreur de la
/// référence ou de l'estimation devient un statut « non évaluable » avec son
/// motif, pour qu'un problème d'estimation ne fasse jamais échouer la
/// pseudonymisation (règle 4 : ni exception qui perd le texte, ni silence).
RiskReport evaluerRisque(EcluseReference reference, String texteMasque) {
  Evaluation evaluation;
  try {
    evaluation = evaluateText(reference, texteMasque);
  } catch (e) {
    evaluation = Evaluation(
      statut: EvaluationStatut.nonEvaluable,
      motifs: ['évaluation impossible : ${e.runtimeType}'],
      notes: honestyNotes(upperBound: false),
    );
  }
  return RiskReport(
    evaluation: evaluation,
    limites: limitesSansNer,
    suggestions: _suggestions(reference, evaluation),
  );
}

/// Propositions de généralisation d'un cran (P2-91). Ne lève jamais : si la
/// simulation échoue, il n'y a pas de proposition, et l'évaluation elle-même
/// reste rendue (règle 4).
List<SuggestionPositionnee> _suggestions(
  EcluseReference reference,
  Evaluation evaluation,
) {
  if (evaluation.statut != EvaluationStatut.evalue) return const [];
  try {
    final candidats = ReidLoop(reference).explain(evaluation.qis).candidats;
    return _positionner(candidats, evaluation.spans);
  } catch (_) {
    return const [];
  }
}

/// Seul un palier qui fait remonter F est une proposition. Le candidat retenu
/// par la simulation vient en premier ; les autres gardent leur ordre.
List<SuggestionPositionnee> _positionner(
  List<GeneralizationCandidate> candidats,
  List<QiSpan> spans,
) {
  bool utile(GeneralizationCandidate c) =>
      c.to != null && c.fAfter != null && c.fAfter! > c.fBefore;
  final ordonnes = [
    for (final c in candidats)
      if (c.retenu && utile(c)) c,
    for (final c in candidats)
      if (!c.retenu && utile(c)) c,
  ];
  return [
    for (final c in ordonnes)
      SuggestionPositionnee(
        candidat: c,
        positions: [
          for (final span in spans)
            if (span.qi == c.from) span,
        ],
      ),
  ];
}
