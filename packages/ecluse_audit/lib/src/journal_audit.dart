import 'dart:async';

import 'package:ecluse_core/ecluse_core.dart';

import 'audit_chain.dart';
import 'audit_entry.dart';
import 'audit_sink.dart';

/// Tient la chaîne du journal à la place de l'application (P2-96, option A
/// de `agent/specs/P2-95.md`).
///
/// Pourquoi : [AuditChain] est sans état. Deux appels qui lisent la même
/// entrée précédente produiraient deux entrées de même numéro, et le
/// vérificateur signalerait une rupture qui n'est pas une falsification.
/// Cette classe garde la dernière entrée et **sérialise** les écritures :
/// la chaîne reste linéaire même sous appels concurrents.
///
/// Elle ne stocke toujours rien elle-même : chaque entrée part dans le
/// [AuditSink] fourni par l'application. L'horloge est injectée (pas
/// d'horloge système dans la bibliothèque, tests reproductibles).
///
/// **Refus explicite** : si `append` échoue, l'exception remonte et la chaîne
/// n'avance pas ; un nouvel essai réutilise le même numéro d'ordre. Un journal
/// qui sauterait une entrée en silence ferait croire à une trace complète.
final class JournalAudit {
  /// [derniere] permet de reprendre une chaîne existante (redémarrage de
  /// l'application) : c'est la dernière entrée déjà écrite dans [sink].
  JournalAudit({
    required AuditSink sink,
    required DateTime Function() horloge,
    AuditEntry? derniere,
  })  : _sink = sink,
        _horloge = horloge,
        _derniere = derniere;

  final AuditSink _sink;
  final DateTime Function() _horloge;
  AuditEntry? _derniere;
  Future<void> _file = Future<void>.value();

  /// Dernière entrée écrite avec succès, `null` avant la première.
  AuditEntry? get derniere => _derniere;

  /// Un masquage réussi : [comptes] par type d'entité, jamais de valeur.
  Future<AuditEntry> enregistrerMasquage({
    required String moteur,
    required Map<String, int> comptes,
  }) =>
      _enregistrer(AuditOp.redact, moteur, comptes, null);

  /// Un envoi refusé parce qu'il contenait [nombre] secrets (au moins 1).
  Future<AuditEntry> enregistrerRefusSecrets({
    required String moteur,
    required int nombre,
  }) {
    final comptes = {EntityType.secret.name: nombre};
    return _enregistrer(AuditOp.secretsRefused, moteur, comptes, null);
  }

  /// Un fichier refusé à l'ingestion, avec son code de motif.
  Future<AuditEntry> enregistrerRefusIngestion({
    required String moteur,
    required AuditReason motif,
  }) =>
      _enregistrer(AuditOp.ingestRefused, moteur, const {}, motif);

  Future<AuditEntry> _enregistrer(
    AuditOp op,
    String moteur,
    Map<String, int> comptes,
    AuditReason? motif,
  ) {
    final fin = Completer<void>();
    final precedent = _file;
    _file = fin.future;
    return precedent.then<AuditEntry>((_) async {
      final entree = AuditChain.next(
        previous: _derniere,
        at: _horloge(),
        engine: moteur,
        op: op,
        counts: comptes,
        reason: motif,
      );
      await _sink.append(entree);
      _derniere = entree;
      return entree;
    }).whenComplete(fin.complete);
  }
}
