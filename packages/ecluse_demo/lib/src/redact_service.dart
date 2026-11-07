import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';

import 'llm_client.dart';

/// Résultat complet d'un trajet redact → LLM → restore, tel qu'affiché
/// dans les 4 panneaux de la démo.
final class ProcessResult {
  const ProcessResult({
    required this.originalText,
    required this.entities,
    required this.maskedText,
    required this.maskedInstruction,
    required this.llmResponse,
    required this.restoredText,
    this.warnings = const [],
    this.risque,
  });

  final String originalText;
  final List<DetectedEntity> entities;
  final String maskedText;

  /// Consigne telle qu'envoyée au LLM : masquée avec la même table que le
  /// texte (une consigne peut citer un nom : « résume le cas de M. X »).
  final String maskedInstruction;
  final String llmResponse;
  final String restoredText;

  /// Avertissements du moteur (secret masqué, texte sans majuscule…), à
  /// montrer à l'utilisateur : ils disent ce que le masquage n'a pas pu
  /// garantir (P2-137).
  final List<String> warnings;

  /// Rapport de risque du texte masqué, si la démo a une référence (P2-141).
  final RiskReport? risque;
}

/// Orchestre le trajet complet : masquage local, appel LLM, restauration
/// locale. La table de correspondance jeton ↔ valeur réelle (`mapping`)
/// ne sort jamais de cette méthode.
final class RedactService {
  const RedactService(this._llmClient, {this.reference});

  final LlmClient _llmClient;

  /// Référence publique chargée (communes, professions, Orphanet). Avec elle,
  /// la démo affiche le rapport de risque de ré-identification et les
  /// pathologies signalées (P2-141) ; sans elle, rien n'est évalué.
  final EcluseReference? reference;

  Future<ProcessResult> process(
    String text, {
    required String instruction,
  }) async {
    // Le texte et la consigne sont masqués séparément, dans un même
    // `Dossier` : une personne citée dans la consigne (« résume le cas de
    // M. Dupont ») reçoit le jeton du texte (règle d'inclusion), et chacun
    // est analysé avec sa propre casse. Avant P2-137, les deux étaient
    // concaténés : un texte en minuscules suivi de la consigne « Résume. »
    // n'était plus « sans majuscule », les détecteurs dédiés (P2-119,
    // P2-120) restaient muets et les noms partaient en clair.
    const separator = '\u0000';
    if (text.contains(separator) || instruction.contains(separator)) {
      throw const LlmError(
        'Texte ou consigne contenant un caractère NUL : requête refusée.',
      );
    }
    final dossier = Dossier(regle: RegleNoms.inclusion);
    // Maladies rares masquées dès que le catalogue Orphanet est chargé
    // (P2-143) ; sans lui, la démo se comporte comme avant.
    final catalogue = reference?.rareDiseases;
    final rares = catalogue != null && catalogue.isLoaded ? catalogue : null;
    try {
      final redacted = await Ecluse.redact(text,
          dossier: dossier, riskReference: reference, maladiesRares: rares);
      final consigne = await Ecluse.redact(instruction,
          dossier: dossier, maladiesRares: rares);
      final maskedText = redacted.maskedText;
      final maskedInstruction = consigne.maskedText;

      final llmResponse = await _llmClient.complete(
        maskedText,
        instruction: maskedInstruction,
      );

      final restoredText = dossier.restore(llmResponse);
      final warnings = {...redacted.warnings, ...consigne.warnings}.toList();

      return ProcessResult(
        originalText: text,
        entities: redacted.entities,
        maskedText: maskedText,
        maskedInstruction: maskedInstruction,
        llmResponse: llmResponse,
        restoredText: restoredText,
        warnings: warnings,
        risque: redacted.risque,
      );
    } finally {
      // La table de correspondance ne survit pas à la requête.
      dossier.fermer();
    }
  }
}
