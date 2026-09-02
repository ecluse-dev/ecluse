import 'dart:convert';
import 'dart:typed_data';

import 'package:ecluse_ocr/ecluse_ocr.dart';
import 'package:http/http.dart' as http;

import 'docling_config.dart';
import 'docling_parser.dart';

/// Implémentation `OcrEngine` qui pilote le sidecar Docling via HTTP
/// local. Le sidecar est un service FastAPI Python — voir `sidecar/`.
class DoclingClient implements OcrEngine {
  DoclingClient({
    required this.config,
    http.Client? httpClient,
    DoclingParser? parser,
  })  : _httpClient = httpClient ?? http.Client(),
        _parser = parser ?? const DoclingParser() {
    if (config.verifySidecarBoundToLoopback && !config.isLoopback) {
      throw SidecarNotLoopbackException(config.baseUrl.host);
    }
  }

  final DoclingConfig config;
  final http.Client _httpClient;
  final DoclingParser _parser;
  bool _closed = false;

  @override
  String get name => 'docling';

  static const _supportedMediaTypes = {
    'application/pdf',
    'image/png',
    'image/jpeg',
    'image/tiff',
  };

  @override
  Future<List<OcrPage>> extract(
    Uint8List bytes, {
    required String mediaType,
  }) async {
    if (_closed) throw OcrEngineClosedException(name);
    if (!_supportedMediaTypes.contains(mediaType)) {
      throw OcrUnsupportedFormatException(mediaType, name);
    }

    final request = http.MultipartRequest(
      'POST',
      config.baseUrl.replace(path: '/extract'),
    )..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: _defaultFilename(mediaType),
        ),
      );

    final http.StreamedResponse streamed;
    try {
      streamed = await _httpClient.send(request).timeout(config.timeout);
    } catch (e) {
      throw DoclingSidecarUnreachableException(config.baseUrl, e);
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw DoclingSidecarErrorException(response.statusCode, response.body);
    }

    return _parser.parse(utf8.decode(response.bodyBytes));
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _httpClient.close();
  }

  String _defaultFilename(String mediaType) {
    switch (mediaType) {
      case 'application/pdf':
        return 'input.pdf';
      case 'image/png':
        return 'input.png';
      case 'image/jpeg':
        return 'input.jpg';
      case 'image/tiff':
        return 'input.tif';
      default:
        return 'input';
    }
  }
}
