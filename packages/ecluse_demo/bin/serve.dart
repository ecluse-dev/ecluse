import 'dart:io';

import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Lance la démo Écluse. Variables d'environnement :
/// - `ANTHROPIC_API_KEY` (requise) : clé API Anthropic.
/// - `ECLUSE_LLM_MODEL` (optionnelle) : modèle Claude, défaut
///   `claude-sonnet-5`.
/// - `PORT` (optionnelle) : port d'écoute local, défaut `8080`.
Future<void> main() async {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      "ANTHROPIC_API_KEY n'est pas définie. Positionnez-la avant de "
      'lancer la démo, par exemple :\n'
      r'  $env:ANTHROPIC_API_KEY = "sk-ant-..."'
      '\npuis relancez `dart run bin/serve.dart`.',
    );
    exitCode = 1;
    return;
  }

  final model = Platform.environment['ECLUSE_LLM_MODEL'] ?? 'claude-sonnet-5';
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  final redactService =
      RedactService(AnthropicClient(apiKey: apiKey, model: model));
  final webDirectory = Directory('${Directory.current.path}/web');
  final handler = buildHandler(
    redactService: redactService,
    webDirectory: webDirectory,
  );

  final server =
      await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
  stdout.writeln(
    'Écluse démo disponible sur http://${server.address.host}:${server.port}',
  );
}
