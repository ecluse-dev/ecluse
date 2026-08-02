import 'dart:convert';

import 'ingest_result.dart';
import 'magic_bytes.dart';

/// Extrait le texte d'un fichier `.txt`/`.md`.
///
/// Aucun rendu Markdown : la syntaxe brute est déjà le texte que le
/// pipeline doit voir, et interpréter la syntaxe n'ajoute rien à la
/// détection tout en risquant de décaler des offsets pour rien.
///
/// UTF-8 strict, sans repli silencieux vers un autre encodage : un fichier
/// UTF-16 ou Windows-1252 mal décodé en UTF-8 décale les caractères
/// accentués et casse le masquage sans qu'on le voie. On refuse plutôt que
/// de deviner.
IngestResult ingestPlainText(List<int> bytes, IngestFormat format) {
  final binaryMatch = matchKnownBinarySignature(bytes);
  if (binaryMatch != null) {
    return IngestRefused(
      'Le contenu du fichier correspond à un format ${binaryMatch.label}, '
      "pas à du texte brut : incohérence entre l'extension déclarée et le "
      'contenu réel, fichier refusé.',
    );
  }

  if (hasUtf16Bom(bytes)) {
    return const IngestRefused(
      'Fichier encodé en UTF-16, pas en UTF-8 : ré-enregistrez-le en UTF-8 '
      'avant de le déposer.',
    );
  }

  final String text;
  try {
    text = utf8.decode(stripUtf8Bom(bytes));
  } on FormatException {
    return const IngestRefused(
      'Encodage non reconnu (ni UTF-8 ni UTF-16) : ré-enregistrez le '
      'fichier en UTF-8 avant de le déposer.',
    );
  }

  return IngestedText(
    text: text,
    format: format,
    warnings: text.isEmpty ? const ['empty'] : const [],
  );
}
