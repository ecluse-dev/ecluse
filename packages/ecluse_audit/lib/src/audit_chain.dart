import 'package:ecluse_core/ecluse_core.dart';

import 'audit_entry.dart';

/// Fabrique les entrées successives du journal. **Sans état** : la
/// dernière entrée (`seq`, `hash`) est fournie par l'application, qui est
/// seule à stocker quoi que ce soit.
abstract final class AuditChain {
  /// Caractères admis dans [AuditEntry.engine] : de quoi écrire
  /// `ecluse_core 0.1.0 [nir,iban]`, rien qui permette d'y glisser une
  /// phrase, un chemin ou un identifiant (la forme est contrôlée, pas
  /// seulement la longueur).
  static final RegExp _engineShape = RegExp(r'^[A-Za-z0-9_.,+\- \[\]]{1,200}$');

  /// Entrée suivant [previous] (`null` pour la première).
  ///
  /// [at] est converti en UTC et tronqué à la minute. Lève [ArgumentError]
  /// si [engine] est mal formé, si [counts] contient un type inconnu ou un
  /// compte négatif, ou si [reason] est incohérent avec [op] (obligatoire
  /// pour `ingestRefused`, interdit pour `redact`).
  static AuditEntry next({
    AuditEntry? previous,
    required DateTime at,
    required String engine,
    required AuditOp op,
    Map<String, int> counts = const {},
    AuditReason? reason,
  }) {
    if (!_engineShape.hasMatch(engine)) {
      throw ArgumentError.value(engine, 'engine', 'forme non admise');
    }
    final knownTypes = EntityType.values.map((t) => t.name).toSet();
    for (final e in counts.entries) {
      if (!knownTypes.contains(e.key)) {
        throw ArgumentError.value(e.key, 'counts', 'type d\'entité inconnu');
      }
      if (e.value < 0) {
        throw ArgumentError.value(e.value, 'counts', 'compte négatif');
      }
    }
    if (op == AuditOp.ingestRefused && reason == null) {
      throw ArgumentError.value(reason, 'reason', 'requis pour ingest_refused');
    }
    if (op == AuditOp.redact && reason != null) {
      throw ArgumentError.value(reason, 'reason', 'interdit pour redact');
    }

    // Les comptes nuls sont omis : une seule écriture canonique par contenu.
    final cleaned = <String, int>{
      for (final e in counts.entries)
        if (e.value > 0) e.key: e.value,
    };
    final hashable = AuditEntry(
      seq: previous == null ? 0 : previous.seq + 1,
      ts: _minuteStamp(at),
      engine: engine,
      op: op,
      counts: Map.unmodifiable(cleaned),
      reason: reason,
      prev: previous?.hash ?? auditGenesisHash,
      hash: '',
    );
    return AuditEntry(
      seq: hashable.seq,
      ts: hashable.ts,
      engine: engine,
      op: op,
      counts: hashable.counts,
      reason: reason,
      prev: hashable.prev,
      hash: hashable.computeHash(),
    );
  }

  /// Comptes par type à partir des entités détectées : uniquement des
  /// nombres, ni valeur, ni position, ni longueur.
  static Map<String, int> countsOf(Iterable<DetectedEntity> entities) {
    final counts = <String, int>{};
    for (final e in entities) {
      counts.update(e.type.name, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// `AAAA-MM-JJThh:mm:00Z`, UTC, secondes forcées à zéro.
  static String _minuteStamp(DateTime at) {
    final u = at.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:00Z';
  }
}
