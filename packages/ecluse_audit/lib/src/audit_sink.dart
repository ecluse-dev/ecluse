import 'audit_entry.dart';

/// Destination des entrées, à implémenter par l'application (fichier en
/// ajout seul, base, etc.). Écluse ne fournit **aucune** implémentation
/// qui écrit sur disque : ce serait du stockage.
abstract interface class AuditSink {
  Future<void> append(AuditEntry entry);
}

/// Implémentation en mémoire, pour les tests et les démonstrations. Perdue à
/// la fin du processus, par construction.
final class InMemoryAuditSink implements AuditSink {
  final List<AuditEntry> _entries = [];

  /// Entrées reçues, dans l'ordre.
  List<AuditEntry> get entries => List.unmodifiable(_entries);

  /// Dernière entrée, à fournir à `AuditChain.next`.
  AuditEntry? get last => _entries.isEmpty ? null : _entries.last;

  @override
  Future<void> append(AuditEntry entry) async => _entries.add(entry);
}
