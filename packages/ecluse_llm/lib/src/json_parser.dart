import 'dart:convert';

import 'leak_span.dart';

/// Exception levée quand la réponse LLM ne contient pas de JSON exploitable.
class LlmJsonParseException implements Exception {
  const LlmJsonParseException(this.message, this.rawResponse);
  final String message;
  final String rawResponse;
  @override
  String toString() => 'LlmJsonParseException: $message';
}

/// Parse la sortie brute d'un LLM en `List<LeakSpan>`.
///
/// Tolère les enveloppes de type ```` ```json ... ``` ```` et le texte
/// parasite avant/après l'objet JSON.
///
/// [textLength] sert à valider que les offsets restent dans le texte
/// original ; les leaks dont les offsets débordent sont écartés et remontés
/// via [warnings].
ParsedLeaks parseLeakSpansJson(String raw, {required int textLength}) {
  final warnings = <String>[];
  final jsonText = _extractJsonObject(raw);
  if (jsonText == null) {
    throw LlmJsonParseException('aucun objet JSON trouvé', raw);
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (e) {
    throw LlmJsonParseException('JSON invalide: ${e.message}', raw);
  }

  if (decoded is! Map<String, dynamic>) {
    throw LlmJsonParseException('racine attendue: objet', raw);
  }

  final leaksField = decoded['leaks'];
  if (leaksField is! List) {
    throw LlmJsonParseException('champ "leaks" attendu: array', raw);
  }

  final result = <LeakSpan>[];
  for (var i = 0; i < leaksField.length; i++) {
    final item = leaksField[i];
    if (item is! Map) {
      warnings.add('leak #$i: entrée non-objet, ignorée');
      continue;
    }
    final map = item.cast<String, dynamic>();
    final leak = _tryParseLeak(map, textLength, i, warnings);
    if (leak != null) result.add(leak);
  }

  return ParsedLeaks(leaks: result, warnings: warnings);
}

LeakSpan? _tryParseLeak(
  Map<String, dynamic> map,
  int textLength,
  int index,
  List<String> warnings,
) {
  final start = _asInt(map['start']);
  final end = _asInt(map['end']);
  if (start == null || end == null) {
    warnings.add('leak #$index: start/end manquant ou non-entier, ignoré');
    return null;
  }
  if (start < 0 || end <= start) {
    warnings.add('leak #$index: offsets invalides ($start-$end), ignoré');
    return null;
  }
  if (end > textLength) {
    warnings
        .add('leak #$index: end=$end dépasse textLength=$textLength, ignoré');
    return null;
  }
  final kind = _parseKind(map['kind']);
  if (kind == null) {
    warnings.add('leak #$index: kind inconnu "${map['kind']}", '
        'basculé sur unknown');
  }
  final reason =
      (map['reason'] is String) ? map['reason'] as String : '(non fourni)';
  final confidence = _asDouble(map['confidence']) ?? 0.5;
  if (confidence < 0 || confidence > 1) {
    warnings.add('leak #$index: confidence hors [0,1] ($confidence), clampée');
  }
  final clamped = confidence.clamp(0.0, 1.0);

  return LeakSpan(
    start: start,
    end: end,
    kind: kind ?? LeakKind.unknown,
    reason: reason,
    confidence: clamped,
  );
}

LeakKind? _parseKind(Object? value) {
  if (value is! String) return null;
  switch (value) {
    case 'semantic_quasi_identifier':
      return LeakKind.semanticQuasiIdentifier;
    case 'coreference':
      return LeakKind.coreference;
    case 'ambiguity_resolved_to_pii':
      return LeakKind.ambiguityResolvedToPii;
    case 'contextual_leak':
      return LeakKind.contextualLeak;
    default:
      return null;
  }
}

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is double && v == v.toInt()) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Extrait le premier objet JSON `{...}` équilibré du texte brut.
///
/// Ignore le texte avant `{`, ignore un éventuel ```` ```json ```` et
/// s'arrête à l'accolade fermante qui équilibre la première ouvrante,
/// en respectant les strings (guillemets et échappements).
String? _extractJsonObject(String raw) {
  final start = raw.indexOf('{');
  if (start < 0) return null;

  var depth = 0;
  var inString = false;
  var escape = false;

  for (var i = start; i < raw.length; i++) {
    final ch = raw[i];
    if (escape) {
      escape = false;
      continue;
    }
    if (inString) {
      if (ch == r'\') {
        escape = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        return raw.substring(start, i + 1);
      }
    }
  }
  return null;
}

class ParsedLeaks {
  const ParsedLeaks({required this.leaks, required this.warnings});
  final List<LeakSpan> leaks;
  final List<String> warnings;
}
