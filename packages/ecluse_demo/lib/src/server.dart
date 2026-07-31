import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_ingest/ecluse_ingest.dart';
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
    if (request.method == 'POST' && path == 'api/ingest') {
      return _handleIngest(request);
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

/// Reçoit un fichier déposé (`{filename, bytes}`, `bytes` en base64) et
/// délègue l'extraction à `ecluse_ingest`. Un format hors périmètre (PDF,
/// image, extension inconnue) ou un contenu incohérent avec l'extension
/// revient comme `{error}` explicite — jamais un texte vide silencieux.
///
/// Le fichier n'est jamais écrit sur disque. Aucun nom de fichier ni
/// contenu n'est journalisé : seuls la taille et le résultat
/// (accepté/refusé) apparaissent en sortie standard.
Future<Response> _handleIngest(Request request) async {
  final Map<String, dynamic> body;
  try {
    final raw = await request.readAsString();
    body = jsonDecode(raw) as Map<String, dynamic>;
  } on FormatException {
    return _jsonResponse({'error': 'Requête illisible (JSON invalide).'});
  }

  final filename = body['filename'];
  final bytesB64 = body['bytes'];
  if (filename is! String || filename.trim().isEmpty) {
    return _jsonResponse({'error': 'Aucun nom de fichier fourni.'});
  }
  if (bytesB64 is! String) {
    return _jsonResponse({'error': 'Fichier illisible (contenu manquant).'});
  }

  final List<int> bytes;
  try {
    bytes = base64Decode(bytesB64);
  } on FormatException {
    return _jsonResponse({'error': 'Fichier illisible (encodage invalide).'});
  }

  stdout.writeln(
    'Écluse démo : dépôt de fichier reçu (${bytes.length} octets).',
  );

  final result = ingestFile(bytes, filename: filename);
  switch (result) {
    case IngestedText(:final text, :final format):
      stdout.writeln('Écluse démo : dépôt accepté (format ${format.name}).');
      return _jsonResponse({'text': text, 'format': format.name});
    case IngestRefused(:final reason):
      stdout.writeln('Écluse démo : dépôt refusé.');
      return _jsonResponse({'error': reason});
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
