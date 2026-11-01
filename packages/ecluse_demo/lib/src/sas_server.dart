import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:shelf/shelf.dart';

/// Jeton typé tel que produit par `Ecluse.redact` : `[NOM_1]`, `[NIR_2]`…
final _tokenPattern = RegExp(r'\[([A-Z_]+)_(\d+)\]');

/// Table de correspondance d'une session du sas.
///
/// `Ecluse.redact` renumérote ses jetons à chaque appel : sans cette table,
/// `[NOM_1]` désignerait une personne au premier prompt et une autre au
/// suivant. La session attribue donc des jetons stables sur toute la
/// conversation : une même valeur garde le même jeton, une nouvelle valeur
/// reçoit le numéro suivant de son type.
///
/// Limite assumée : entre deux prompts, l'identité d'un nom repose sur la
/// valeur exacte. « Dupont » seul, après « Jean Dupont » dans un prompt
/// précédent, reçoit un jeton distinct (la fusion des mentions partielles
/// d'`Ecluse.redact` ne joue qu'à l'intérieur d'un même texte).
final class SasSession {
  final Map<String, String> _valueByToken = {};
  final Map<String, String> _tokenByIdentity = {};
  final Map<String, int> _counterByLabel = {};
  DateTime lastUse = DateTime.now();

  /// Masque [text] et renvoie le texte masqué avec des jetons de session,
  /// ainsi que le nombre d'entités détectées.
  Future<({String text, int entities})> redact(String text) async {
    lastUse = DateTime.now();
    final result = await Ecluse.redact(text);

    final sessionTokenByLocal = <String, String>{};
    for (final entry in result.mapping.entries) {
      final match = _tokenPattern.matchAsPrefix(entry.key);
      if (match == null || match.end != entry.key.length) {
        // Jeton de forme inattendue : on refuse plutôt que de laisser
        // passer un texte au masquage incertain.
        throw StateError('Jeton de forme inattendue.');
      }
      final label = match.group(1)!;
      final identity = '$label:${entry.value}';
      sessionTokenByLocal[entry.key] = _tokenByIdentity.putIfAbsent(identity, () {
        final next = (_counterByLabel[label] ?? 0) + 1;
        _counterByLabel[label] = next;
        final token = '[${label}_$next]';
        _valueByToken[token] = entry.value;
        return token;
      });
    }

    // Une seule passe : pas d'enchaînement de remplacements
    // ([NOM_1] -> [NOM_2] -> [NOM_3]).
    final masked = result.maskedText.replaceAllMapped(
      _tokenPattern,
      (m) => sessionTokenByLocal[m[0]!] ?? m[0]!,
    );
    return (text: masked, entities: result.entities.length);
  }

  /// Restaure les jetons de cette session présents dans [text].
  String restore(String text) {
    lastUse = DateTime.now();
    return Ecluse.restore(text, _valueByToken);
  }
}

/// Sessions en mémoire uniquement : rien n'est jamais écrit sur disque ni
/// journalisé. Au-delà de [maxSessions], la session la moins récemment
/// utilisée est oubliée (ses jetons ne sont alors plus restaurables).
final class SasStore {
  SasStore({this.maxSessions = 64});

  final int maxSessions;
  final Map<String, SasSession> _sessions = {};

  SasSession sessionFor(String id) {
    final existing = _sessions.remove(id);
    final session = existing ?? SasSession();
    _sessions[id] = session; // réinsertion = plus récente en fin de table
    while (_sessions.length > maxSessions) {
      _sessions.remove(_sessions.keys.first);
    }
    return session;
  }

  /// Session existante, ou `null` : une restauration ne crée jamais de
  /// session.
  SasSession? existing(String id) => _sessions[id];
}

/// Hôtes acceptés : le sas n'écoute que la boucle locale, et refuse une
/// requête dont l'en-tête Host ne désigne pas la machine elle-même
/// (protection contre le « DNS rebinding » depuis une page web).
const _loopbackHosts = {'127.0.0.1', 'localhost', '::1', '[::1]'};

/// Handler du sas Écluse pour Claude Code (mod `ecluse-sas`).
///
/// - `POST /v1/redact`  `{session, text}` → `{text, entities}`
/// - `POST /v1/restore` `{session, text}` → `{text}`
///
/// Toute anomalie renvoie un code d'erreur HTTP : le mod bloque alors
/// l'envoi du prompt. La table de correspondance ne sort jamais du
/// processus. Aucun texte n'est journalisé, seulement des compteurs.
Handler buildSasHandler({SasStore? store}) {
  final sessions = store ?? SasStore();
  return (Request request) async {
    if (!_loopbackHosts.contains(request.requestedUri.host)) {
      return Response.forbidden('Hôte refusé.');
    }
    final path = request.url.path;
    if (request.method != 'POST' ||
        (path != 'v1/redact' && path != 'v1/restore')) {
      return Response.notFound('Route inconnue.');
    }
    // Un navigateur ne peut pas envoyer de JSON vers une autre origine
    // sans requête préalable CORS, que ce serveur ne valide jamais.
    final contentType = request.headers['content-type'] ?? '';
    if (!contentType.startsWith('application/json')) {
      return Response(415, body: 'JSON attendu.');
    }

    final String session;
    final String text;
    try {
      final body = jsonDecode(await request.readAsString());
      if (body is! Map<String, dynamic> ||
          body['session'] is! String ||
          body['text'] is! String) {
        return Response.badRequest(body: 'Champs session et text attendus.');
      }
      session = body['session'] as String;
      text = body['text'] as String;
    } on FormatException {
      return Response.badRequest(body: 'JSON invalide.');
    }
    if (session.isEmpty || session.length > 128) {
      return Response.badRequest(body: 'Identifiant de session invalide.');
    }

    if (path == 'v1/redact') {
      try {
        final out = await sessions.sessionFor(session).redact(text);
        stdout.writeln('Écluse sas : texte masqué (${out.entities} entités).');
        return _json({'text': out.text, 'entities': out.entities});
      } catch (_) {
        stdout.writeln('Écluse sas : échec du masquage, prompt refusé.');
        return Response.internalServerError(body: 'Échec du masquage.');
      }
    }

    final known = sessions.existing(session);
    stdout.writeln('Écluse sas : réponse restaurée.');
    return _json({'text': known == null ? text : known.restore(text)});
  };
}

Response _json(Object payload) => Response.ok(
      jsonEncode(payload),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
