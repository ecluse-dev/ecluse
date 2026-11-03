import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Opérations journalisées — énumération fermée (spec §1).
enum AuditOp {
  redact('redact'),
  ingestRefused('ingest_refused');

  const AuditOp(this.wire);

  /// Valeur écrite dans le journal.
  final String wire;
}

/// Motifs de refus — **codes** d'une liste fermée, jamais le message libre
/// d'un refus (il peut citer du contenu du document, spec §3).
enum AuditReason {
  pdfImage('pdf_image'),
  encrypted('encrypted'),
  unsupportedFormat('unsupported_format'),
  unreadable('unreadable'),
  tooLarge('too_large'),
  other('other');

  const AuditReason(this.wire);

  /// Valeur écrite dans le journal.
  final String wire;
}

/// Version du schéma des entrées. Toute évolution du format canonique
/// l'incrémente : la canonicalisation est figée par version.
const int auditSchemaVersion = 1;

/// Valeur de `prev` de la première entrée (`seq` 0) : 64 zéros hexadécimaux.
final String auditGenesisHash = '0' * 64;

/// Une entrée du journal, immuable et sérialisable.
///
/// Ne contient **jamais** : texte d'entrée, valeur détectée, jeton de
/// substitution, position ou longueur d'entité, empreinte du texte,
/// identité de l'utilisateur, nom de fichier (spec §3). Les champs
/// libres sont validés par [AuditChain] avant fabrication.
///
/// L'empreinte du texte (`digest`) du schéma de la spec §1 est volontairement
/// **absente** en v0 (décision du mainteneur : jamais de hash simple).
final class AuditEntry {
  const AuditEntry({
    required this.seq,
    required this.ts,
    required this.engine,
    required this.op,
    required this.counts,
    required this.reason,
    required this.prev,
    required this.hash,
    this.version = auditSchemaVersion,
  });

  /// Reconstruit une entrée depuis son JSON ; refuse tout champ inconnu ou
  /// mal typé (`FormatException`) plutôt que de l'ignorer en silence.
  factory AuditEntry.fromJson(Map<String, Object?> json) {
    const known = {
      'v',
      'seq',
      'ts',
      'engine',
      'op',
      'counts',
      'reason',
      'prev',
      'hash',
    };
    final unknown = json.keys.where((k) => !known.contains(k));
    if (unknown.isNotEmpty) {
      throw FormatException('champ inconnu : ${unknown.first}');
    }
    T field<T>(String key) {
      final value = json[key];
      if (value is! T) throw FormatException('champ invalide : $key');
      return value;
    }

    final op = AuditOp.values.where((o) => o.wire == field<String>('op'));
    if (op.isEmpty) throw const FormatException('champ invalide : op');
    final rawCounts = field<Map<String, Object?>>('counts');
    final counts = <String, int>{};
    for (final e in rawCounts.entries) {
      final v = e.value;
      if (v is! int) throw FormatException('compte invalide : ${e.key}');
      counts[e.key] = v;
    }
    final reasonWire = json['reason'];
    AuditReason? reason;
    if (reasonWire != null) {
      final found = AuditReason.values.where((r) => r.wire == reasonWire);
      if (found.isEmpty) throw const FormatException('champ invalide : reason');
      reason = found.single;
    }
    return AuditEntry(
      version: field<int>('v'),
      seq: field<int>('seq'),
      ts: field<String>('ts'),
      engine: field<String>('engine'),
      op: op.single,
      counts: Map.unmodifiable(counts),
      reason: reason,
      prev: field<String>('prev'),
      hash: field<String>('hash'),
    );
  }

  final int version;

  /// Numéro d'ordre, 0 pour la première entrée, +1 ensuite.
  final int seq;

  /// Horodatage UTC RFC 3339 **à la minute** (secondes forcées à `00`),
  /// tiré de l'horloge de l'appareil : pas un horodatage qualifié
  /// (RFC 3161 / eIDAS).
  final String ts;

  /// Version du moteur et noms des détecteurs actifs (texte validé).
  final String engine;

  final AuditOp op;

  /// Nombre d'entités par type (`EntityType.name`), jamais de valeur.
  final Map<String, int> counts;

  /// Code de motif, pour `ingest_refused` uniquement.
  final AuditReason? reason;

  /// `hash` de l'entrée précédente ; [auditGenesisHash] pour `seq` 0.
  final String prev;

  /// SHA-256 (hex) de la forme canonique de l'entrée **sans** ce champ.
  final String hash;

  /// Entrée sans son `hash` : la matière à hacher.
  Map<String, Object?> toHashableJson() => {
        'v': version,
        'seq': seq,
        'ts': ts,
        'engine': engine,
        'op': op.wire,
        'counts': counts,
        'reason': reason?.wire,
        'prev': prev,
      };

  Map<String, Object?> toJson() => {...toHashableJson(), 'hash': hash};

  /// Forme canonique de l'entrée complète : une ligne, clés triées.
  String toCanonicalJson() => canonicalJson(toJson());

  /// Recalcule le hash attendu d'après le contenu courant.
  String computeHash() => hashEntryJson(toHashableJson());

  @override
  String toString() => toCanonicalJson();
}

/// SHA-256 (hex) de la forme canonique de [hashable].
String hashEntryJson(Map<String, Object?> hashable) =>
    sha256.convert(utf8.encode(canonicalJson(hashable))).toString();

/// JSON canonique : clés triées par ordre d'unités de code, sans espaces,
/// chaînes encodées par `jsonEncode` (UTF-8 non échappé, sauf caractères de
/// contrôle), entiers sans zéros inutiles, `null` explicite.
///
/// **Aucun flottant** n'est admis : leur représentation textuelle n'est pas
/// stable d'une plateforme à l'autre, ce qui casserait la vérification.
String canonicalJson(Object? value) {
  if (value == null) return 'null';
  if (value is int) return value.toString();
  if (value is String) return jsonEncode(value);
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${canonicalJson(value[k])}').join(',')}}';
  }
  throw ArgumentError('type non canonicalisable : ${value.runtimeType}');
}
