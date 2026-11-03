import 'package:ecluse_audit/ecluse_audit.dart';
import 'package:test/test.dart';

const _moteur = 'ecluse_redact 0.1.0 [nir,iban]';

/// Horloge injectée : aucun test ne lit l'heure réelle.
DateTime _horloge() => DateTime.utc(2026, 11, 3, 21, 30, 12);

/// Sink qui échoue tant que [echoue] est vrai.
final class _SinkFragile implements AuditSink {
  bool echoue = true;
  final List<AuditEntry> entrees = [];

  @override
  Future<void> append(AuditEntry entry) async {
    if (echoue) throw StateError('stockage indisponible');
    entrees.add(entry);
  }
}

/// `JournalAudit` (P2-96) : il garde la dernière entrée, sérialise les
/// écritures et n'avance jamais la chaîne sur un échec d'écriture.
void main() {
  test('cent écritures concurrentes : chaîne linéaire et intacte', () async {
    final sink = InMemoryAuditSink();
    final journal = JournalAudit(sink: sink, horloge: _horloge);
    await Future.wait([
      for (var i = 0; i < 100; i++)
        journal.enregistrerMasquage(moteur: _moteur, comptes: {'nir': i + 1}),
    ]);
    final verif = AuditVerifier.verify(sink.entries);
    expect(verif, isA<AuditIntact>());
    expect((verif as AuditIntact).count, 100);
    expect([for (final e in sink.entries) e.seq], List.generate(100, (i) => i));
    expect(journal.derniere, same(sink.entries.last));
  });

  test('l\'ordre des appels est l\'ordre de la chaîne', () async {
    final sink = InMemoryAuditSink();
    final journal = JournalAudit(sink: sink, horloge: _horloge);
    await Future.wait([
      journal.enregistrerMasquage(moteur: _moteur, comptes: {'nir': 1}),
      journal.enregistrerRefusSecrets(moteur: _moteur, nombre: 2),
      journal.enregistrerRefusIngestion(
          moteur: _moteur, motif: AuditReason.pdfImage),
    ]);
    expect([for (final e in sink.entries) e.op], [
      AuditOp.redact,
      AuditOp.secretsRefused,
      AuditOp.ingestRefused,
    ]);
    expect(sink.entries[1].counts, {'secret': 2});
  });

  test('échec d\'écriture : exception, chaîne inchangée, même numéro ensuite',
      () async {
    final sink = _SinkFragile();
    final journal = JournalAudit(sink: sink, horloge: _horloge);
    await expectLater(
      journal.enregistrerMasquage(moteur: _moteur, comptes: {'nir': 1}),
      throwsStateError,
    );
    expect(journal.derniere, isNull);
    sink.echoue = false;
    final e = await journal.enregistrerMasquage(
        moteur: _moteur, comptes: {'nir': 1});
    expect(e.seq, 0);
    expect(AuditVerifier.verify(sink.entrees), isA<AuditIntact>());
  });

  test('reprise d\'une chaîne existante avec derniere', () async {
    final sink = InMemoryAuditSink();
    final a = JournalAudit(sink: sink, horloge: _horloge);
    await a.enregistrerMasquage(moteur: _moteur, comptes: {'nir': 1});
    final b = JournalAudit(sink: sink, horloge: _horloge, derniere: sink.last);
    await b.enregistrerMasquage(moteur: _moteur, comptes: {'nir': 2});
    expect(sink.entries.map((e) => e.seq), [0, 1]);
    expect(AuditVerifier.verify(sink.entries), isA<AuditIntact>());
  });

  test('entrée invalide : refus explicite, rien n\'est écrit', () async {
    final sink = InMemoryAuditSink();
    final journal = JournalAudit(sink: sink, horloge: _horloge);
    await expectLater(
      journal.enregistrerRefusSecrets(moteur: _moteur, nombre: 0),
      throwsArgumentError,
    );
    await expectLater(
      journal.enregistrerMasquage(moteur: 'étrange', comptes: const {}),
      throwsArgumentError,
    );
    expect(sink.entries, isEmpty);
  });
}
