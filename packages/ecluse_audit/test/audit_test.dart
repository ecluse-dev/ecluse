import 'dart:convert';

import 'package:ecluse_audit/ecluse_audit.dart';
import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

const _engine = 'ecluse_core 0.1.0 [nir,iban]';

/// Horloge injectée : aucun test ne lit l'heure réelle.
final _t0 = DateTime.utc(2026, 10, 25, 16, 59, 41);
final _t1 = DateTime.utc(2026, 10, 25, 17, 3, 7);

/// Vecteurs calculés indépendamment (hashlib Python sur la forme canonique).
const _hash0 =
    '42930e6c0d7cdeb42519fa2d6bb5e9298154aadec2e136f861115cb7e46a22d3';
const _hash1 =
    '1cd7d57526ea1e4dab283c42a1b774cf901d8abe42ed71dad6233281bbb5aa34';

AuditEntry _first() => AuditChain.next(
      at: _t0,
      engine: _engine,
      op: AuditOp.redact,
      counts: {'nir': 2, 'iban': 1},
    );

List<AuditEntry> _chain(int n) {
  final entries = <AuditEntry>[];
  for (var i = 0; i < n; i++) {
    entries.add(AuditChain.next(
      previous: entries.isEmpty ? null : entries.last,
      at: _t0.add(Duration(minutes: i)),
      engine: _engine,
      op: AuditOp.redact,
      counts: {'nir': i + 1},
    ));
  }
  return entries;
}

/// Copie d'une entrée avec un champ remplacé, hash conservé.
AuditEntry _tamper(AuditEntry e, {int? seq, Map<String, int>? counts}) =>
    AuditEntry(
      seq: seq ?? e.seq,
      ts: e.ts,
      engine: e.engine,
      op: e.op,
      counts: counts ?? e.counts,
      reason: e.reason,
      prev: e.prev,
      hash: e.hash,
    );

void main() {
  group('vecteurs fixes', () {
    test('forme canonique et hash de la première entrée', () {
      final e = _first();
      expect(
        e.toHashableJson().toString(),
        isNotEmpty,
      );
      expect(
        canonicalJson(e.toHashableJson()),
        '{"counts":{"iban":1,"nir":2},"engine":"ecluse_core 0.1.0 [nir,iban]",'
        '"op":"redact","prev":"${'0' * 64}","reason":null,"seq":0,'
        '"ts":"2026-10-25T16:59:00Z","v":1}',
      );
      expect(e.hash, _hash0);
      expect(e.prev, auditGenesisHash);
      expect(e.ts, '2026-10-25T16:59:00Z');
    });

    test('deuxième entrée chaînée, refus avec code de motif', () {
      final e = AuditChain.next(
        previous: _first(),
        at: _t1,
        engine: _engine,
        op: AuditOp.ingestRefused,
        reason: AuditReason.pdfImage,
      );
      expect(e.seq, 1);
      expect(e.prev, _hash0);
      expect(e.hash, _hash1);
    });

    test('l\'horodatage est tronqué à la minute, en UTC', () {
      final local = DateTime.parse('2026-10-25T18:59:59.999+02:00');
      final e = AuditChain.next(at: local, engine: _engine, op: AuditOp.redact);
      expect(e.ts, '2026-10-25T16:59:00Z');
    });

    test('les comptes nuls sont omis (une seule écriture par contenu)', () {
      final e = AuditChain.next(
        at: _t0,
        engine: _engine,
        op: AuditOp.redact,
        counts: {'nir': 0, 'iban': 1},
      );
      expect(e.counts, {'iban': 1});
    });
  });

  group('vérification', () {
    test('chaîne intègre', () {
      final result = AuditVerifier.verify(_chain(5));
      expect(result, isA<AuditIntact>());
      final intact = result as AuditIntact;
      expect(intact.count, 5);
      expect(intact.lastSeq, 4);
    });

    test('journal vide : intègre, sans dernier seq', () {
      final r = AuditVerifier.verify(const []) as AuditIntact;
      expect(r.count, 0);
      expect(r.lastSeq, isNull);
    });

    test('champ modifié : hash invalide à la bonne entrée', () {
      final c = _chain(5);
      c[2] = _tamper(c[2], counts: {'nir': 99});
      final r = AuditVerifier.verify(c) as AuditBroken;
      expect((r.index, r.seq, r.kind), (2, 2, AuditBreakKind.invalidHash));
    });

    test('entrée modifiée ET re-hachée : le suivant rompt par prev', () {
      final c = _chain(5);
      final forged = AuditChain.next(
        previous: c[1],
        at: _t0.add(const Duration(minutes: 2)),
        engine: _engine,
        op: AuditOp.redact,
        counts: {'nir': 99},
      );
      c[2] = forged;
      final r = AuditVerifier.verify(c) as AuditBroken;
      expect((r.index, r.kind), (3, AuditBreakKind.prevMismatch));
    });

    test('suppression au milieu : trou de seq', () {
      final c = _chain(5)..removeAt(2);
      final r = AuditVerifier.verify(c) as AuditBroken;
      expect((r.index, r.seq, r.kind), (2, 3, AuditBreakKind.seqGap));
    });

    test('insertion au milieu : décalage de seq', () {
      final c = _chain(5);
      c.insert(2, c[1]);
      final r = AuditVerifier.verify(c) as AuditBroken;
      expect(r.index, 2);
      expect(r.kind, AuditBreakKind.seqGap);
    });

    test('réordonnancement', () {
      final c = _chain(5);
      final tmp = c[1];
      c[1] = c[2];
      c[2] = tmp;
      final r = AuditVerifier.verify(c) as AuditBroken;
      expect((r.index, r.kind), (1, AuditBreakKind.seqGap));
    });

    test('première entrée supprimée : détecté', () {
      final c = _chain(3)..removeAt(0);
      expect(AuditVerifier.verify(c), isA<AuditBroken>());
    });

    test('LIMITE : la troncature en fin de journal N\'EST PAS détectée', () {
      final c = _chain(5);
      final r = AuditVerifier.verify(c.sublist(0, 3));
      expect(r, isA<AuditIntact>(),
          reason: 'documenté : ancrer le dernier hash hors du journal');
    });

    test('aller-retour JSON, et refus d\'un champ inconnu', () {
      final e = _chain(2).last;
      final back = AuditEntry.fromJson(
          jsonDecode(e.toCanonicalJson()) as Map<String, Object?>);
      expect(back.hash, e.hash);
      expect(AuditVerifier.verify([_first(), back]), isA<AuditBroken>());
      expect(
        () => AuditEntry.fromJson({
          ...(jsonDecode(e.toCanonicalJson()) as Map<String, Object?>),
          'texte': 'x',
        }),
        throwsFormatException,
      );
    });
  });

  group('validation à la fabrication', () {
    test('type d\'entité inconnu, compte négatif', () {
      expect(
        () => AuditChain.next(
            at: _t0, engine: _engine, op: AuditOp.redact, counts: {'x': 1}),
        throwsArgumentError,
      );
      expect(
        () => AuditChain.next(
            at: _t0, engine: _engine, op: AuditOp.redact, counts: {'nir': -1}),
        throwsArgumentError,
      );
    });

    test('reason : requis pour un refus, interdit pour redact', () {
      expect(
        () => AuditChain.next(
            at: _t0, engine: _engine, op: AuditOp.ingestRefused),
        throwsArgumentError,
      );
      expect(
        () => AuditChain.next(
            at: _t0,
            engine: _engine,
            op: AuditOp.redact,
            reason: AuditReason.encrypted),
        throwsArgumentError,
      );
    });

    test('engine : une phrase, un chemin ou un nom de fichier sont refusés',
        () {
      for (final bad in [
        'M. Dupont a ouvert /home/dupont/dossier.docx',
        '',
        'a' * 201,
        'moteur\nsuite',
        'étrange',
      ]) {
        expect(
          () => AuditChain.next(at: _t0, engine: bad, op: AuditOp.redact),
          throwsArgumentError,
          reason: bad,
        );
      }
    });

    test('canonicalJson refuse les flottants', () {
      expect(() => canonicalJson({'x': 1.5}), throwsArgumentError);
    });
  });

  group('non-fuite', () {
    test('aucune valeur, aucun fragment, aucune position dans le journal',
        () async {
      // Valeurs synthétiques : NIR de l'exemple du dépôt, IBAN FR fabriqué.
      const nir = '1 85 05 78 006 084 91';
      const iban = 'FR76 3000 6000 0112 3456 7890 189';
      const text = 'Patient $nir, compte $iban, à rappeler.';
      final entities = <DetectedEntity>[
        ...const NirDetector().detect(text),
        ...const IbanFrDetector().detect(text),
      ];
      expect(entities, isNotEmpty);

      final sink = InMemoryAuditSink();
      await sink.append(AuditChain.next(
        previous: sink.last,
        at: _t0,
        engine: _engine,
        op: AuditOp.redact,
        counts: AuditChain.countsOf(entities),
      ));

      final journal = sink.entries.map((e) => e.toCanonicalJson()).join('\n');
      for (final secret in [
        nir,
        iban,
        '1850578006084',
        '85057',
        '3000 6000',
        'Patient',
        'rappeler',
      ]) {
        expect(journal, isNot(contains(secret)), reason: secret);
      }
      // Ni start/end, ni longueur : seuls des comptes figurent.
      for (final e in entities) {
        expect(journal, isNot(contains('"start"')));
        expect(journal, isNot(contains('"end"')));
        expect(journal, isNot(contains('"value"')));
        expect(journal, isNot(contains('"length"')));
        expect(e.start, isNonNegative);
      }
    });
  });
}
