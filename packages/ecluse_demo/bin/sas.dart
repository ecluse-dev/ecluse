import 'dart:io';

import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Lance le sas Écluse local utilisé par le mod Claude Code `ecluse-sas`.
///
/// N'appelle aucun LLM et ne demande aucune clé : il masque et restaure
/// seulement. Écoute uniquement sur 127.0.0.1.
///
/// Variable d'environnement : `ECLUSE_SAS_PORT` (défaut `8787`).
Future<void> main() async {
  final port =
      int.tryParse(Platform.environment['ECLUSE_SAS_PORT'] ?? '') ?? 8787;
  final server = await shelf_io.serve(
    buildSasHandler(),
    InternetAddress.loopbackIPv4,
    port,
  );
  stdout.writeln(
    'Écluse sas disponible sur http://${server.address.host}:${server.port}',
  );
}
