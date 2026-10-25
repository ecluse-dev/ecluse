/// Journal d'audit chaîné et horodaté d'Écluse (v0).
///
/// La bibliothèque **fabrique et vérifie** des entrées ; elle n'écrit nulle
/// part (le stockage appartient à l'application cliente, via [AuditSink]) et
/// ne contient jamais de donnée personnelle : voir `agent/specs/P1-08-audit.md`
/// et `LIMITES.md`.
library;

export 'src/audit_chain.dart';
export 'src/audit_entry.dart';
export 'src/audit_sink.dart';
export 'src/audit_verifier.dart';
