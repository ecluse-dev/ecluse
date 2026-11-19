import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Signal « à vérifier » de l'aperçu (P2-232, `agent/specs/P2-230.md` § 4).
///
/// Un nom est à vérifier quand sa **seule** preuve est une tournure de
/// personne (« le dossier de X »). Le signal est une information : il ne change
/// jamais ce qui est masqué. Mots et phrases synthétiques.
Future<List<EntiteProposee>> _noms(String t, {Dossier? dossier}) async {
  final p = await Apercu.propose(t, dossier: dossier);
  return [
    for (final e in p.entites)
      if (e.type == EntityType.nom) e
  ];
}

void main() {
  group('les quatre cas de la spec (§ 4)', () {
    test('1. tournure seule : l\'entité est à vérifier', () async {
      final noms = await _noms('Le dossier de Verdier est transmis.');
      expect(noms, hasLength(1));
      expect(noms.single.valeur, 'Verdier');
      expect(noms.single.aVerifier, isTrue);
    });

    test('2. autre occurrence du même mot : à vérifier aussi', () async {
      final noms = await _noms(
          'Le dossier de Verdier est transmis. Verdier rappelle demain.');
      expect(noms.map((e) => e.valeur), ['Verdier', 'Verdier']);
      expect(noms.every((e) => e.aVerifier), isTrue);
    });

    test('3. civilité ailleurs dans le texte : aucune n\'est à vérifier',
        () async {
      for (final t in [
        'Mme Sophie Verdier est arrivée. Le dossier de Verdier est transmis.',
        'Le dossier de Verdier est transmis. Mme Sophie Verdier est arrivée.',
      ]) {
        final noms = await _noms(t);
        expect(noms.length, greaterThanOrEqualTo(2), reason: t);
        expect(noms.where((e) => e.aVerifier), isEmpty, reason: t);
      }
    });

    test('4. patronyme établi dans un document précédent du dossier', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier est arrivée.', dossier: d);
      final noms =
          await _noms('Le dossier de Verdier est transmis.', dossier: d);
      expect(noms, hasLength(1));
      expect(noms.single.aVerifier, isFalse);
      // Sans le document précédent, le même texte est à vérifier.
      final seul = await _noms('Le dossier de Verdier est transmis.');
      expect(seul.single.aVerifier, isTrue);
    });
  });

  group('tournures, autres règles', () {
    test('les tournures d\'après (« a confirmé ») sont à vérifier', () async {
      final noms = await _noms('Verdier a confirmé le rendez-vous.');
      expect(noms, hasLength(1));
      expect(noms.single.aVerifier, isTrue);
    });

    test('un couple prénom + nom n\'est jamais à vérifier', () async {
      final noms = await _noms('Sophie Verdier arrive demain.');
      expect(noms, isNotEmpty);
      expect(noms.where((e) => e.aVerifier), isEmpty);
    });

    test('les entités hors nom ne sont jamais à vérifier', () async {
      final p = await Apercu.propose(
          'Le dossier de Verdier. Contact : sophie@example.fr, 01 99 00 12 34');
      for (final e in p.entites) {
        if (e.type != EntityType.nom) expect(e.aVerifier, isFalse);
      }
    });

    test('Proposition.aVerifier liste les identifiants signalés', () async {
      final p = await Apercu.propose(
          'Mme Sophie Martin. Le dossier de Verdier est transmis.');
      final attendus = [
        for (final e in p.entites)
          if (e.aVerifier) e.id
      ];
      expect(p.aVerifier, attendus);
      expect(() => p.aVerifier.add(0), throwsUnsupportedError);
    });
  });

  group('propagation (un test qui échoue si le champ est perdu)', () {
    const t = 'Le dossier de Verdier est transmis. Verdier rappelle demain.';

    test('NameDetector pose la provenance', () {
      final noms = const NameDetector().detect(t);
      expect(noms, hasLength(2));
      expect(noms.map((e) => e.provenance), everyElement(Provenance.tournure));
    });

    test('Ecluse.detect la conserve (copie du moteur)', () async {
      final noms = [
        for (final e in await Ecluse.detect(t))
          if (e.type == EntityType.nom) e
      ];
      expect(noms, hasLength(2));
      expect(noms.map((e) => e.provenance), everyElement(Provenance.tournure));
    });

    test('Ecluse.redact la conserve dans RedactResult.entities', () async {
      final r = await Ecluse.redact(t);
      final noms = r.entities.where((e) => e.type == EntityType.nom);
      expect(noms.map((e) => e.provenance), everyElement(Provenance.tournure));
    });

    test('texte à vue de détection décalée (accents décomposés)', () async {
      // Une lettre accentuée décomposée oblige `Ecluse` à ramener les positions
      // de la vue au texte d'origine : la copie ne doit pas perdre le champ.
      const nfd = 'Le dossier de Verdié est transmis.';
      final noms = await _noms(nfd);
      expect(noms, hasLength(1));
      expect(noms.single.aVerifier, isTrue);
    });

    test('texte en minuscules : la civilité est une preuve, pas de signal',
        () async {
      // Aucune tournure n'est lue en minuscules : le mode minuscules ne
      // reconnaît ici que la civilité, jamais un signal « à vérifier ».
      final noms = await _noms('le dossier de madame verdier; verdier a '
          'confirmé, merci');
      expect(noms, hasLength(2));
      expect(noms.where((e) => e.aVerifier), isEmpty);
    });

    test('seconde lecture aux séparateurs (nom de fichier) : conservé',
        () async {
      final noms =
          await _noms('Le dossier_de Verdier.pdf est transmis. Verdier a '
              'confirmé');
      expect(noms, hasLength(2));
      expect(noms.every((e) => e.aVerifier), isTrue);
    });

    test('le champ n\'entre pas dans == ni dans hashCode', () {
      const a = DetectedEntity(
          type: EntityType.nom,
          start: 0,
          end: 3,
          value: 'abc',
          confidence: 0.6);
      const b = DetectedEntity(
          type: EntityType.nom,
          start: 0,
          end: 3,
          value: 'abc',
          confidence: 0.6,
          provenance: Provenance.tournure);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('le signal ne change pas ce qui est masqué', () {
    test('tout accepté = Ecluse.redact, texte et table identiques', () async {
      for (final t in [
        'Le dossier de Verdier est transmis. Verdier rappelle demain.',
        'Mme Sophie Verdier est arrivée. Le dossier de Verdier est transmis.',
        'Verdier a confirmé le rendez-vous.',
      ]) {
        final p = await Apercu.propose(t);
        final r =
            await Apercu.applique(p, const DecisionApercu(), texteAEnvoyer: t);
        final attendu = await Ecluse.redact(t);
        expect(r.maskedText, attendu.maskedText, reason: t);
        expect(r.mapping.entrees.toList(), attendu.mapping.entrees.toList());
        expect(attendu.maskedText, contains('[NOM_1]'));
      }
    });

    test('descriptionMoteur ne change pas', () async {
      final r = await Ecluse.redact('Le dossier de Verdier est transmis.');
      expect(r.maskedText, 'Le dossier de [NOM_1] est transmis.');
      expect(Ecluse.descriptionMoteur, isNot(contains('verifier')));
      expect(Ecluse.descriptionMoteur, isNot(contains('tournure')));
    });
  });

  group('aucune valeur du texte dans une sortie', () {
    test('toString de DetectedEntity : nom d\'énumération seulement', () {
      const e = DetectedEntity(
          type: EntityType.nom,
          start: 0,
          end: 7,
          value: 'Verdier',
          confidence: 0.6,
          provenance: Provenance.tournure);
      expect(e.toString(), isNot(contains('Verdier')));
      expect(e.toString(), contains('tournure'));
    });

    test('toString d\'EntiteProposee et de Proposition', () async {
      final p = await Apercu.propose('Le dossier de Verdier est transmis.');
      expect(p.entites.single.toString(), isNot(contains('Verdier')));
      expect(p.toString(), isNot(contains('Verdier')));
      expect(p.resume.toString(), isNot(contains('Verdier')));
    });

    test('les erreurs de l\'aperçu ne citent pas la valeur', () async {
      const t = 'Le dossier de Verdier est transmis.';
      final p = await Apercu.propose(t);
      try {
        await Apercu.applique(p, const DecisionApercu(refusees: {42}),
            texteAEnvoyer: t);
        fail('une exception était attendue');
      } on ApercuException catch (e) {
        expect(e.toString(), isNot(contains('Verdier')));
      }
    });

    test('Provenance est une énumération fermée', () {
      expect(Provenance.values.map((v) => v.name), ['tournure']);
    });
  });
}
