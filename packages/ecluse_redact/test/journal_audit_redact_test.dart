import 'dart:io';

import 'package:ecluse_audit/ecluse_audit.dart';
import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Journal d'audit branché dans `Ecluse.redact` (P2-96, option A de
/// `agent/specs/P2-95.md`, décisions P2-96a). Sans journal, rien ne change ;
/// avec, chaque appel laisse une entrée sans donnée personnelle, écrite avant
/// que le résultat soit rendu.
const _texte = 'Mme Sophie Verdier, née le 12/03/1950, joignable au '
    '01 99 00 12 34. Contact : sophie.verdier@example.fr';

/// Jeton GitHub de test, assemblé à l'exécution (jamais en clair dans le
/// dépôt, jamais un vrai jeton).
final _secret = 'ghp_${'a1B2' * 9}';

DateTime _horloge() => DateTime.utc(2026, 11, 3, 21, 45);

/// Détecteur dont le nom ne respecte pas la forme admise par le journal.
final class _DetecteurMaison implements Detector {
  const _DetecteurMaison();

  @override
  DetectorTier get tier => DetectorTier.pattern;

  @override
  String get name => 'mon détecteur';

  @override
  Future<List<DetectedEntity>> detect(NormalizedText text) async => const [];
}

final class _SinkEnPanne implements AuditSink {
  @override
  Future<void> append(AuditEntry entry) async =>
      throw StateError('stockage indisponible');
}

void main() {
  test('sans journal comme avec : même texte masqué, même table', () async {
    final sans = await Ecluse.redact(_texte);
    final journal = JournalAudit(sink: InMemoryAuditSink(), horloge: _horloge);
    final avec = await Ecluse.redact(_texte, journal: journal);
    expect(avec.maskedText, sans.maskedText);
    expect(avec.mapping, sans.mapping);
    expect(avec.warnings, sans.warnings);
  });

  test('une entrée par appel, comptes par type, chaîne intacte', () async {
    final sink = InMemoryAuditSink();
    final journal = JournalAudit(sink: sink, horloge: _horloge);
    final r = await Ecluse.redact(_texte, journal: journal);
    await Ecluse.redact('Rien à masquer.', journal: journal);
    expect(sink.entries, hasLength(2));
    expect(sink.entries.first.op, AuditOp.redact);
    expect(sink.entries.first.counts, AuditChain.countsOf(r.entities));
    expect(sink.entries.last.counts, isEmpty);
    expect(AuditVerifier.verify(sink.entries), isA<AuditIntact>());
  });

  test('aucune valeur du texte dans le journal', () async {
    final sink = InMemoryAuditSink();
    final journal = JournalAudit(sink: sink, horloge: _horloge);
    await Ecluse.redact(_texte, journal: journal);
    final brut = sink.entries.map((e) => e.toCanonicalJson()).join('\n');
    for (final valeur in [
      'Sophie',
      'Verdier',
      '12/03/1950',
      '01 99 00 12 34',
      'example.fr',
    ]) {
      expect(brut, isNot(contains(valeur)), reason: valeur);
    }
  });

  test('description du moteur construite par Écluse', () async {
    final sink = InMemoryAuditSink();
    final journal = JournalAudit(sink: sink, horloge: _horloge);
    await Ecluse.redact(_texte, journal: journal);
    expect(sink.entries.single.engine, Ecluse.descriptionMoteur());
    expect(sink.entries.single.engine,
        startsWith('${Ecluse.versionMoteur} [nir,rpps,'));
  });

  test('refus de secrets : entrée secrets_refused, puis exception', () async {
    final sink = InMemoryAuditSink();
    final journal = JournalAudit(sink: sink, horloge: _horloge);
    await expectLater(
      Ecluse.redact('Clé : $_secret', refuseSecrets: true, journal: journal),
      throwsA(isA<SecretsRefusedException>()),
    );
    expect(sink.entries.single.op, AuditOp.secretsRefused);
    expect(sink.entries.single.counts, {'secret': 1});
    expect(sink.entries.single.toCanonicalJson(), isNot(contains(_secret)));
  });

  test('écriture impossible : exception, et le dossier n\'a pas bougé',
      () async {
    final temoin = Dossier();
    final dossier = Dossier();
    final enPanne = JournalAudit(sink: _SinkEnPanne(), horloge: _horloge);
    await expectLater(
      Ecluse.redact(_texte, dossier: dossier, journal: enPanne),
      throwsStateError,
    );
    final apres = await Ecluse.redact(_texte, dossier: dossier);
    final attendu = await Ecluse.redact(_texte, dossier: temoin);
    expect(apres.maskedText, attendu.maskedText);
    expect(apres.mapping, attendu.mapping);
  });

  test('un nom de détecteur hors forme devient « autre »', () {
    const detecteurs = <Detector>[SecretDetector(), _DetecteurMaison()];
    expect(Ecluse.descriptionMoteur(detecteurs),
        '${Ecluse.versionMoteur} [secret,autre]');
  });

  test('versionMoteur suit la version de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final motif = RegExp(r'^version: (\S+)$', multiLine: true);
    final version = motif.firstMatch(pubspec)!.group(1);
    expect(Ecluse.versionMoteur, 'ecluse_redact $version');
  });
}
