import 'audit_entry.dart';

/// Nature de la première rupture détectée.
enum AuditBreakKind {
  /// Le `hash` ne correspond pas au contenu (entrée modifiée).
  invalidHash,

  /// `seq` non consécutif (suppression, insertion ou réordonnancement).
  seqGap,

  /// `prev` ne désigne pas le `hash` de l'entrée précédente.
  prevMismatch,
}

/// Résultat d'une vérification.
sealed class AuditVerification {
  const AuditVerification();
}

/// Chaîne cohérente de bout en bout. [lastSeq] vaut `null` si le journal
/// est vide. **Ne prouve pas** l'absence de troncature en fin de journal.
final class AuditIntact extends AuditVerification {
  const AuditIntact({required this.count, required this.lastSeq});

  final int count;
  final int? lastSeq;
}

/// Première rupture : position [index] dans la séquence fournie, [seq]
/// stocké dans l'entrée fautive, et [kind].
final class AuditBroken extends AuditVerification {
  const AuditBroken({
    required this.index,
    required this.seq,
    required this.kind,
  });

  final int index;
  final int seq;
  final AuditBreakKind kind;

  @override
  String toString() => 'AuditBroken(index: $index, seq: $seq, ${kind.name})';
}

abstract final class AuditVerifier {
  /// Recalcule la chaîne. Détecte : modification d'une entrée, suppression
  /// ou insertion au milieu, réordonnancement.
  ///
  /// **Ne détecte pas** : la troncature en fin de journal (la chaîne reste
  /// valide : ancrer le dernier `hash` hors du journal), ni la réécriture
  /// complète par qui contrôle tout le fichier (un hash chaîné n'est pas une
  /// signature), ni la justesse de l'horloge.
  static AuditVerification verify(Iterable<AuditEntry> entries) {
    var index = 0;
    var expectedPrev = auditGenesisHash;
    int? lastSeq;
    for (final entry in entries) {
      // Dans l'ordre : l'entrée est-elle cohérente avec elle-même, puis
      // avec sa position, puis avec la précédente.
      if (entry.hash != entry.computeHash()) {
        return AuditBroken(
          index: index,
          seq: entry.seq,
          kind: AuditBreakKind.invalidHash,
        );
      }
      if (entry.seq != index) {
        return AuditBroken(
          index: index,
          seq: entry.seq,
          kind: AuditBreakKind.seqGap,
        );
      }
      if (entry.prev != expectedPrev) {
        return AuditBroken(
          index: index,
          seq: entry.seq,
          kind: AuditBreakKind.prevMismatch,
        );
      }
      expectedPrev = entry.hash;
      lastSeq = entry.seq;
      index++;
    }
    return AuditIntact(count: index, lastSeq: lastSeq);
  }
}
