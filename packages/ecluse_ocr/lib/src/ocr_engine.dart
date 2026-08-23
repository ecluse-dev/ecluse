import 'dart:typed_data';

import 'ocr_page.dart';

/// Contrat d'un moteur OCR local.
///
/// Implémentations prévues :
///   - `ecluse_ocr_docling.DoclingClient` : sidecar Python (IBM Docling)
///     accessible en HTTP local — le meilleur sur documents structurés.
///   - (à venir) `ecluse_ocr_onnx.VlmOcrEngine` : VLM en ONNX
///     (Qwen 2.5-VL, Phi-3.5-vision, Florence-2), 100 % embarqué.
abstract interface class OcrEngine {
  /// Extrait le texte du document dont on fournit les octets bruts.
  ///
  /// [mediaType] : MIME du fichier d'entrée
  /// (`application/pdf`, `image/png`, `image/jpeg`, `image/tiff`).
  Future<List<OcrPage>> extract(
    Uint8List bytes, {
    required String mediaType,
  });

  /// Libère les ressources (session, sidecar, sockets).
  ///
  /// Après `close()`, tout appel à `extract` doit lever [StateError].
  void close();

  /// Nom court du moteur, propagé dans `OcrPage.sourceEngine`.
  String get name;
}

class OcrEngineClosedException implements Exception {
  const OcrEngineClosedException(this.engineName);
  final String engineName;
  @override
  String toString() => 'OcrEngineClosedException($engineName)';
}

class OcrUnsupportedFormatException implements Exception {
  const OcrUnsupportedFormatException(this.mediaType, this.engineName);
  final String mediaType;
  final String engineName;
  @override
  String toString() =>
      'OcrUnsupportedFormatException($mediaType by $engineName)';
}
