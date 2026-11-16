import 'dart:convert';
import 'dart:math';

import 'package:ecluse_audit/ecluse_audit.dart';
import 'package:test/test.dart';

const _engine = 'ecluse_core 0.1.0 [nir,iban]';
final _t0 = DateTime.utc(2026, 10, 25, 16, 59, 41);

List<AuditEntry> _journal(
    List<({AuditOp op, Map<String, int> counts, AuditReason? reason})> ops,
    {String engine = _engine}) {
  final entries = <AuditEntry>[];
  for (var i = 0; i < ops.length; i++) {
    entries.add(AuditChain.next(
      previous: entries.isEmpty ? null : entries.last,
      at: _t0.add(Duration(hours: i)),
      engine: engine,
      op: ops[i].op,
      counts: ops[i].counts,
      reason: ops[i].reason,
    ));
  }
  return entries;
}

({AuditOp op, Map<String, int> counts, AuditReason? reason}) _redact(
        Map<String, int> counts) =>
    (op: AuditOp.redact, counts: counts, reason: null);

({AuditOp op, Map<String, int> counts, AuditReason? reason}) _refus(
        AuditReason r) =>
    (op: AuditOp.ingestRefused, counts: const {}, reason: r);

void main() {
  group('agrégat', () {
    test('journal vide : aucun compte, mentions présentes', () {
      final e = AuditExporter.agrege(const []);
      expect(e.operations, 0);
      expect(e.premiere, isNull);
      expect(e.verification, isA<AuditIntact>());
      expect(e.mentions, isNotEmpty);
      expect(e.toTexte(), contains('n\'atteste pas la conformité'));
    });

    test('au-dessus du seuil : comptes exacts, période à la minute', () {
      final e = AuditExporter.agrege(_journal([
        for (var i = 0; i < 6; i++) _redact({'nir': 2, 'iban': 1}),
        for (var i = 0; i < 5; i++) _refus(AuditReason.pdfImage),
      ]));
      expect(e.operations, 11);
      expect(e.periodeAuJour, isFalse);
      expect(e.premiere, '2026-10-25T16:59:00Z');
      expect(e.entites, {'nir': 12, 'iban': 6});
      expect(e.refus, {'pdf_image': 5});
      expect(e.parOperation, {'redact': 6, 'ingest_refused': 5});
      expect(e.moteurs.map((m) => m.moteur), [_engine]);
    });

    test('faible effectif : « moins de 5 » et période au jour', () {
      final e = AuditExporter.agrege(_journal([
        _redact({'nir': 1}),
        _refus(AuditReason.encrypted),
      ]));
      expect(e.periodeAuJour, isTrue);
      expect(e.premiere, '2026-10-25');
      expect(e.entites, {'nir': 'moins de 5'});
      expect(e.refus, {'encrypted': 'moins de 5'});
      expect(e.operations, 'moins de 5');
      expect(jsonEncode(e.toJson()), isNot(contains('16:59')));
    });

    test('le seuil est paramétrable', () {
      final e = AuditExporter.agrege(
          _journal([
            for (var i = 0; i < 3; i++) _redact({'nir': 1})
          ]),
          seuil: 2);
      expect(e.entites, {'nir': 3});
      expect(e.periodeAuJour, isFalse);
    });

    test('un seuil invalide est refusé', () {
      expect(
          () => AuditExporter.agrege(const [], seuil: 0), throwsArgumentError);
    });

    List<AuditEntry> avecMoteurs(List<String> moteurs,
        {Duration pas = const Duration(hours: 1)}) {
      final entries = <AuditEntry>[];
      for (var i = 0; i < moteurs.length; i++) {
        entries.add(AuditChain.next(
          previous: entries.isEmpty ? null : entries.last,
          at: _t0.add(pas * i),
          engine: moteurs[i],
          op: AuditOp.redact,
          counts: const {'nir': 1},
        ));
      }
      return entries;
    }

    test('moteurs dans l\'ordre de première apparition, sans doublon', () {
      final e = AuditExporter.agrege(avecMoteurs([
        'ecluse_core 0.2.0 [nir]',
        _engine,
        'ecluse_core 0.2.0 [nir]',
        _engine,
        'ecluse_core 0.2.0 [nir]',
        _engine,
      ]));
      expect(
          e.moteurs.map((m) => m.moteur), ['ecluse_core 0.2.0 [nir]', _engine]);
      expect(e.moteurs.map((m) => m.rang), [1, 2]);
    });

    test(
        '0.10.0 vient après 0.2.0 : l\'ordre est chronologique, pas '
        'alphabétique', () {
      final e = AuditExporter.agrege(avecMoteurs([
        'ecluse_redact 0.2.0 [nir]',
        'ecluse_redact 0.2.0 [nir]',
        'ecluse_redact 0.10.0 [nir]',
        'ecluse_redact 0.10.0 [nir]',
        'ecluse_redact 0.10.0 [nir]',
        'ecluse_redact 0.10.0 [nir]',
      ]));
      expect(e.moteurs.map((m) => m.moteur),
          ['ecluse_redact 0.2.0 [nir]', 'ecluse_redact 0.10.0 [nir]']);
      // Un tri alphabétique donnerait l'ordre inverse.
      expect(e.moteurs.first.moteur.compareTo(e.moteurs.last.moteur),
          greaterThan(0));
    });

    test(
        'journal à deux versions et trois changements (retour en arrière '
        'compris)', () {
      final e = AuditExporter.agrege(avecMoteurs([
        'ecluse_redact 0.2.0 [nir]',
        'ecluse_redact 0.2.0 [nir]',
        'ecluse_redact 0.3.0 [nir]',
        'ecluse_redact 0.2.0 [nir]',
        'ecluse_redact 0.3.0 [nir]',
        'ecluse_redact 0.3.0 [nir]',
      ]));
      expect(e.moteurs, hasLength(2));
      expect(e.changementsDeMoteur, 3);
      expect(
          e.toTexte(),
          contains('Le moteur a changé 3 fois pendant la '
              'période'));
    });

    test('un seul moteur : aucun changement, aucune phrase de changement', () {
      final e = AuditExporter.agrege(
          avecMoteurs([for (var i = 0; i < 6; i++) _engine]));
      expect(e.changementsDeMoteur, 0);
      expect(e.toTexte(), isNot(contains('a changé')));
      expect(e.moteurs, hasLength(1));
    });

    test('un seul changement : singulier', () {
      final e = AuditExporter.agrege(avecMoteurs([
        for (var i = 0; i < 6; i++) i < 3 ? _engine : 'ecluse_core 0.2.0 [nir]'
      ]));
      expect(e.changementsDeMoteur, 1);
      expect(e.toTexte(), contains('Le moteur a changé 1 fois'));
    });

    test('horodatage de première apparition au jour, jamais à la minute', () {
      final e = AuditExporter.agrege(avecMoteurs([
        for (var i = 0; i < 8; i++) i < 4 ? _engine : 'ecluse_core 0.2.0 [nir]'
      ], pas: const Duration(hours: 6)));
      expect(e.moteurs.first.depuis, '2026-10-25');
      expect(e.moteurs.last.depuis, '2026-10-26');
      for (final m in e.moteurs) {
        expect(m.depuis, matches(r'^\d{4}-\d{2}-\d{2}$'));
      }
    });

    test(
        'aucun compte par version dans le JSON ni dans le texte '
        '(recoupement P2-26)', () {
      final e = AuditExporter.agrege(avecMoteurs([
        for (var i = 0; i < 9; i++) i < 7 ? _engine : 'ecluse_core 0.2.0 [nir]'
      ]));
      final json = e.toJson();
      expect(json['version'], 2);
      final moteurs = json['moteurs'] as List;
      for (final m in moteurs) {
        expect((m as Map).keys.toSet(), {'rang', 'moteur', 'depuis'});
      }
      expect(json['changements_de_moteur'], 1);
      // Ni le rang d'entrée, ni le nombre d'entrées de l'ancien moteur.
      expect(jsonEncode(moteurs), isNot(contains('seq')));
      expect(e.toTexte(), isNot(contains('7 entrée')));
    });

    test('mention d\'honnêteté sur le changement de version', () {
      final e = AuditExporter.agrege(const []);
      expect(
          e.mentions.any((m) => m.contains('ne sont pas comparables')), isTrue);
    });
  });

  group('intégrité', () {
    test('chaîne rompue : le rang est rapporté, jamais masqué', () {
      final entries = _journal([
        for (var i = 0; i < 6; i++) _redact({'nir': 1})
      ]);
      final cassee = [entries[0], entries[1], entries[3], ...entries.skip(4)];
      final e = AuditExporter.agrege(cassee);
      expect(e.verification, isA<AuditBroken>());
      expect(e.toTexte(), contains('rompue'));
      expect(e.toJson()['chaine'], isA<Map<String, Object?>>());
    });

    test('chaîne intacte : la troncature reste signalée comme non détectée',
        () {
      final e = AuditExporter.agrege(_journal([
        for (var i = 0; i < 6; i++) _redact({'nir': 1})
      ]));
      expect(e.verification, isA<AuditIntact>());
      expect(e.toTexte(), contains('troncature'));
    });
  });

  group('contenu de la sortie', () {
    test('clés JSON dans une liste fermée, aucune valeur ni position', () {
      final e = AuditExporter.agrege(_journal([
        for (var i = 0; i < 6; i++) _redact({'nir': 2, 'nom': 1}),
      ]));
      const admises = {
        'chaine',
        'changements_de_moteur',
        'entites',
        'mentions',
        'moteurs',
        'operations',
        'par_operation',
        'periode',
        'refus',
        'seuil',
        'version',
      };
      expect(e.toJson().keys.toSet(), admises);
    });

    test('mentions d\'honnêteté présentes dans le texte et le JSON', () {
      final e = AuditExporter.agrege(const []);
      final texte = e.toTexte();
      for (final m in e.mentions) {
        expect(texte, contains(m));
      }
      expect(e.toJson()['mentions'], e.mentions);
      expect(texte, contains('détectées'));
      expect(texte, contains('DPO'));
    });

    test('reproductible : même journal, mêmes sorties', () {
      final j = _journal([
        for (var i = 0; i < 6; i++) _redact({'nir': 2})
      ]);
      expect(
          AuditExporter.agrege(j).toTexte(), AuditExporter.agrege(j).toTexte());
      expect(jsonEncode(AuditExporter.agrege(j).toJson()),
          jsonEncode(AuditExporter.agrege(j).toJson()));
    });
  });

  group('divulgation par recoupement (P2-26)', () {
    test('le nombre d\'entrées de la chaîne suit le masquage de operations',
        () {
      final e = AuditExporter.agrege(_journal([
        for (var i = 0; i < 3; i++) _redact({'nir': 1}),
      ]));
      expect(e.operations, 'moins de 5');
      final chaine = e.toJson()['chaine'] as Map;
      expect(chaine['etat'], 'intacte');
      expect(chaine['entrees'], 'moins de 5');
      expect(e.toTexte(), isNot(contains('3 entrée')));
      expect(jsonEncode(e.toJson()), isNot(contains('"entrees":3')));
    });

    test('un total exact ne permet pas de retrouver une opération masquée', () {
      final e = AuditExporter.agrege(_journal([
        for (var i = 0; i < 9; i++) _redact({'nir': 1}),
        for (var i = 0; i < 3; i++) _refus(AuditReason.pdfImage),
      ]));
      expect(e.parOperation, {'redact': 9, 'ingest_refused': 'moins de 5'});
      expect(e.operations, isA<String>(),
          reason: '12 - 9 donnerait les 3 refus');
      expect((e.toJson()['chaine'] as Map)['entrees'], isA<String>());
    });

    test('un refus masqué ne se déduit pas du total des refus', () {
      final e = AuditExporter.agrege(_journal([
        for (var i = 0; i < 6; i++) _refus(AuditReason.unsupportedFormat),
        for (var i = 0; i < 5; i++) _refus(AuditReason.other),
        for (var i = 0; i < 3; i++) _refus(AuditReason.pdfImage),
      ]));
      expect(e.parOperation['ingest_refused'], 14);
      final inconnus = e.refus.values.whereType<String>().length;
      expect(inconnus, isNot(1), reason: '14 - 6 - 5 donnerait les 3');
      // Aucun compte exact n'est faux : un compte masqué n'est jamais présenté
      // comme « moins de 5 » s'il ne l'est pas.
      expect(e.refus['other'], isNot('moins de 5'));
    });

    test(
        'propriété : jamais une seule inconnue dans une somme exacte '
        '(graine 42)', () {
      final rng = Random(42);
      for (var essai = 0; essai < 400; essai++) {
        final ops =
            <({AuditOp op, Map<String, int> counts, AuditReason? reason})>[
          for (var i = 0; i < rng.nextInt(14); i++) _redact({'nir': 1}),
          for (final r in AuditReason.values)
            for (var i = 0; i < rng.nextInt(8); i++) _refus(r),
        ];
        final e = AuditExporter.agrege(_journal(ops));
        // Groupe 1 : total des opérations et opérations.
        final g1 = e.parOperation.values.whereType<String>().length;
        if (e.operations is int) {
          expect(g1, 0, reason: 'total exact avec une opération masquée');
        }
        // Groupe 2 : refus par code et nombre d'entrées « ingest_refused ».
        final parent = e.parOperation['ingest_refused'];
        if (parent is int) {
          expect(e.refus.values.whereType<String>().length, isNot(1));
        }
      }
    });
  });
}
