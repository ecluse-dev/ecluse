import 'package:meta/meta.dart';

@immutable
class DoclingConfig {
  const DoclingConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.verifySidecarBoundToLoopback = true,
  });

  /// URL du sidecar. Doit pointer sur une loopback (`127.0.0.1`,
  /// `localhost`, `::1`) tant que [verifySidecarBoundToLoopback] est
  /// vrai — sinon un [SidecarNotLoopbackException] est levé au premier
  /// appel HTTP.
  final Uri baseUrl;

  final Duration timeout;

  /// Garde-fou : refuse tout `baseUrl` non-loopback.
  ///
  /// Ne désactiver qu'en environnement contrôlé (bench distant sous
  /// firewall). En prod : jamais.
  final bool verifySidecarBoundToLoopback;

  bool get isLoopback {
    final host = baseUrl.host.toLowerCase();
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1' ||
        host == '[::1]';
  }
}

class SidecarNotLoopbackException implements Exception {
  const SidecarNotLoopbackException(this.host);
  final String host;
  @override
  String toString() =>
      'SidecarNotLoopbackException($host — refuse une URL non-loopback)';
}

class DoclingSidecarUnreachableException implements Exception {
  const DoclingSidecarUnreachableException(this.baseUrl, this.cause);
  final Uri baseUrl;
  final Object cause;
  @override
  String toString() => 'DoclingSidecarUnreachableException($baseUrl) : $cause';
}

class DoclingSidecarErrorException implements Exception {
  const DoclingSidecarErrorException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'DoclingSidecarErrorException(HTTP $statusCode: $body)';
}
