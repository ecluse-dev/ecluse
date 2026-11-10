import 'dart:io';

import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
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

  // Référence publique pour le rapport de risque (P2-141) : dossier des
  // assets d'`ecluse_reference`, `ECLUSE_REFERENCE` pour le changer. Absente :
  // la démo fonctionne sans rapport de risque.
  final dossierReference = Platform.environment['ECLUSE_REFERENCE'] ??
      '${Directory.current.path}/../ecluse_reference/assets';
  EcluseReference? reference;
  if (Directory(dossierReference).existsSync()) {
    reference = EcluseReference(fileAssets(assetsDir: dossierReference));
    await reference.preload();
    await reference.rareDiseases.load();
    await reference.firstNameFrequencies.load();
  } else {
    stdout.writeln('Écluse démo : référence introuvable ($dossierReference), '
        'rapport de risque désactivé.');
  }
  final redactService = RedactService(
      AnthropicClient(apiKey: apiKey, model: model),
      reference: reference);
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
