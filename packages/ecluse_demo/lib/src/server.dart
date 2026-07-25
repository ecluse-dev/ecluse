import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:shelf/shelf.dart';

import 'llm_client.dart';
import 'redact_service.dart';

/// Construit le handler shelf de la démo : page unique, liste des
/// documents d'exemple, et traitement d'un texte.
///
/// [webDirectory] doit contenir `index.html`.
Handler buildHandler({
  required RedactService redactService,
  required Directory webDirectory,
}) {
  return (Request request) async {
    final path = request.url.path;

    if (request.method == 'GET' && (path.isEmpty || path == 'index.html')) {
      return _serveIndex(webDirectory);
    }
    if (request.method == 'GET' && path == 'api/samples') {
      return _handleSamples();
    }
    if (request.method == 'POST' && path == 'api/process') {
      return _handleProcess(request, redactService);
    }
    return Response.notFound('Route inconnue.');
  };
}

Future<Response> _serveIndex(Directory webDirectory) async {
  final file = File('${webDirectory.path}/index.html');
  if (!file.existsSync()) {
    return Response.internalServerError(
      body: 'index.html introuvable dans ${webDirectory.path}.',
    );
  }
  final html = await file.readAsString();
  return Response.ok(html,
      headers: {'content-type': 'text/html; charset=utf-8'});
}

Response _handleSamples() {
  final payload = [
    for (final sample in demoSamples)
      {
        'title': sample.title,
        'text': sample.text,
        'instruction': sample.instruction,
      },
  ];
  return _jsonResponse(payload);
}

/// Traite une requête `{text, instruction}` : masquage local, appel LLM,
/// restauration locale. Aucune erreur réseau/API ne doit faire planter le
/// serveur — elle est renvoyée comme `{error}` clair pour l'interface.
///
/// Aucun texte reçu (original ou masqué) n'est jamais journalisé ici :
/// seuls des événements de haut niveau, sans contenu, sont affichés sur
/// la sortie standard.
Future<Response> _handleProcess(
  Request request,
  RedactService redactService,
) async {
  final Map<String, dynamic> body;
  try {
    final raw = await request.readAsString();
    body = jsonDecode(raw) as Map<String, dynamic>;
  } on FormatException {
    return _jsonResponse({'error': 'Requête illisible (JSON invalide).'});
  }

  final text = body['text'];
  final instruction = body['instruction'];
  if (text is! String || text.trim().isEmpty) {
    return _jsonResponse({'error': 'Aucun texte à traiter.'});
  }
  if (instruction is! String || instruction.trim().isEmpty) {
    return _jsonResponse({'error': 'Aucune consigne fournie pour le LLM.'});
  }

  stdout.writeln('Écluse démo : requête reçue (${text.length} caractères).');

  try {
    final result = await redactService.process(text, instruction: instruction);
    stdout.writeln(
      'Écluse démo : trajet complet effectué '
      '(${result.entities.length} entités masquées).',
    );
    return _jsonResponse({
      'originalText': result.originalText,
      'entities': [
        for (final entity in result.entities) _encodeEntity(entity),
      ],
      'maskedText': result.maskedText,
      'llmResponse': result.llmResponse,
      'restoredText': result.restoredText,
    });
  } on LlmError catch (error) {
    stdout.writeln("Écluse démo : erreur LLM ('${error.message}').");
    return _jsonResponse({'error': error.message});
  }
}

Map<String, dynamic> _encodeEntity(DetectedEntity entity) => {
      'type': entity.type.name,
      'start': entity.start,
      'end': entity.end,
      'value': entity.value,
      'confidence': entity.confidence,
    };

Response _jsonResponse(Object payload) => Response.ok(
      jsonEncode(payload),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
