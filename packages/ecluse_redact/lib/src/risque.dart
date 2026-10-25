import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// Rapport de risque de ré-identification d'un texte masqué (P2-04, option A de
/// `agent/specs/P2-03.md`). **Il ne change jamais le texte envoyé** : la
/// généralisation, irréversible, relève de l'appelant.
final class RiskReport {
  const RiskReport({required this.evaluation, required this.limites});

  /// Évaluation des quasi-identifiants restés dans le **texte masqué** (c'est
  /// lui qui quitte la machine) : statut explicite, estimation ou motifs,
  /// QI repérés avec leur position **dans `maskedText`**, notes d'honnêteté.
  final Evaluation evaluation;

  /// Ce que ce rapport ne voit pas. Toujours présent, quel que soit le statut :
  /// un statut « aucun QI détecté » n'est pas un risque faible.
  final List<String> limites;
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
  return RiskReport(evaluation: evaluation, limites: limitesSansNer);
}
