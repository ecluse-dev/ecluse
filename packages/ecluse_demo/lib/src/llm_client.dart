import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erreur renvoyée par un [LlmClient] — jamais une exception non gérée :
/// la démo doit afficher un message clair plutôt que planter en pleine
/// présentation.
final class LlmError implements Exception {
  const LlmError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contrat commun à tous les clients LLM d'Écluse.
///
/// Le prompt envoyé au fournisseur ne doit **jamais** contenir que le
/// texte déjà masqué par `Ecluse.redact` — jamais le texte original, jamais
/// la table de correspondance. C'est la responsabilité de l'appelant
/// (`RedactService`), pas de l'implémentation de [LlmClient].
abstract interface class LlmClient {
  /// Envoie [maskedText] au LLM avec la consigne [instruction] et retourne
  /// sa réponse brute (jetons `[NOM_1]` etc. toujours présents).
  Future<String> complete(String maskedText, {required String instruction});
}

/// Consigne système rappelant au LLM de préserver les jetons Écluse tels
/// quels. Indispensable : sans elle, un LLM reformule ou traduit
/// spontanément `[NOM_1]` et la restauration échoue silencieusement.
const String tokenPreservationSystemPrompt =
    'Le texte contient des identifiants entre crochets, par exemple '
    "[NOM_1]. Conserve-les strictement à l'identique dans ta réponse, sans "
    'jamais les reformuler ni les remplacer.';

/// Client pour l'API Messages d'Anthropic (Claude).
///
/// Fournisseur unique retenu pour cette démonstration, derrière
/// l'interface [LlmClient] : ajouter un autre fournisseur ne demande
/// qu'une nouvelle implémentation, sans toucher au reste du pipeline
/// (voir principe de neutralité entre providers du README racine).
final class AnthropicClient implements LlmClient {
  AnthropicClient({
    required this.apiKey,
    this.model = 'claude-sonnet-5',
    this.timeout = const Duration(seconds: 30),
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final Duration timeout;
  final http.Client _httpClient;

  static final Uri _endpoint =
      Uri.parse('https://api.anthropic.com/v1/messages');

  @override
  Future<String> complete(
    String maskedText, {
    required String instruction,
  }) async {
    final http.Response response;
    try {
      response = await _httpClient
          .post(
            _endpoint,
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'max_tokens': 1024,
              'system': tokenPreservationSystemPrompt,
              'messages': [
                {'role': 'user', 'content': '$instruction\n\n$maskedText'},
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const LlmError(
        "Le fournisseur LLM n'a pas répondu à temps (délai dépassé).",
      );
    } catch (error) {
      throw LlmError(
        'Impossible de joindre le fournisseur LLM (pas de réseau ou '
        'service indisponible) : $error',
      );
    }

    if (response.statusCode != 200) {
      throw LlmError(
        'Le fournisseur LLM a renvoyé une erreur '
        '(HTTP ${response.statusCode}).',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const LlmError(
        'Réponse du fournisseur LLM illisible (format inattendu).',
      );
    }

    final content = decoded['content'];
    if (content is! List) {
      throw const LlmError(
        'Réponse du fournisseur LLM illisible (contenu absent).',
      );
    }

    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map<String, dynamic> && block['type'] == 'text') {
        buffer.write(block['text'] as String? ?? '');
      }
    }
    return buffer.toString();
  }
}
