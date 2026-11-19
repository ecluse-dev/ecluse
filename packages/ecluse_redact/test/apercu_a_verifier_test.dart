import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Signal « à vérifier » de l'aperçu (P2-232, `agent/specs/P2-230.md` § 4).
///
/// Un nom est à vérifier quand la **seule** preuve de ce nom est une tournure
/// de personne. Le signal est une information : il ne change jamais ce qui est
/// masqué. Valeurs synthétiques seulement.
Future<List<bool>> _signaux(String texte, {Dossier? dossier}) async {
  final p = await Apercu.propose(texte, dossier: dossier);
  return [
    for (final e in p.entites)
      if (e.type == EntityType.nom) e.aVerifier
  ];
}

void main() {
  group('aVerifier : les cas de la spec (§ 4)', () {
    test('tournure seule : les deux occurrences sont à vérifier', () async {
      final p = await Apercu.propose(
          'Le dossier de Verdier est transmis. Verdier rappelle.');
      final noms = p.entites.where((e) => e.type == EntityType.nom).toList();
      expect(noms.map((e) => e.valeur), ['Verdier', 'Verdier']);
      expect(noms.map((e) => e.aVerifier), [true, true]);
      expect(p.aVerifier, noms.map((e) => e.id).toList());
    });

    test('civilité ailleurs dans le texte : aucune n\'est à vérifier',
        () async {
      final s = await _signaux(
          'Mme Sophie Verdier est arrivée. Le dossier de Verdier est transmis.');
      expect(s, isNotEmpty);
      expect(s, everyElement(isFalse));
    });

    test('couple prénom + nom ailleurs dans le texte : rien à vérifier',
        () async {
      final s = await _signaux(
          'Le dossier de Verdier est transmis. Sophie Verdier a téléphoné.');
      expect(s, isNotEmpty);
      expect(s, everyElement(isFalse));
    });

    test('patronyme établi dans un document précédent du dossier', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier est arrivée.', dossier: d);
      final s =
          await _signaux('Le dossier de Verdier est transmis.', dossier: d);
      expect(s, [false]);
      // Le calcul du signal ne modifie pas l'état du dossier.
      final sans = await _signaux('Le dossier de Verdier est transmis.');
      expect(sans, [true]);
    });

    test('un nom de civilité n\'est jamais à vérifier', () async {
      expect(await _signaux('Mme Verdier est arrivée.'), [false]);
    });

    test('un autre type d\'entité n\'est jamais à vérifier', () async {
      final p = await Apercu.propose('Contact : sophie.verdier@example.fr');
      expect(p.entites, isNotEmpty);
      expect(p.entites.map((e) => e.aVerifier), everyElement(isFalse));
      expect(p.aVerifier, isEmpty);
    });
  });

  group('la provenance traverse toutes les copies d\'entité', () {
    // Échoue si l'une des copies (moteur, ramenée au texte d'origine, deuxième
    // lecture de NameDetector, minuscules) perd le champ en silence.
    const gabarit = 'Le dossier de Verdier est transmis.';

    ProvenanceEntite? provenanceDuNom(List<DetectedEntity> es) => es
        .firstWhere((e) => e.type == EntityType.nom,
            orElse: () => throw 'aucun')
        .provenance;

    test('NameDetector seul', () {
      expect(provenanceDuNom(const NameDetector().detect(gabarit)),
          ProvenanceEntite.tournureSeule);
    });

    test('Ecluse.detect (moteur et copie ramenée au texte d\'origine)',
        () async {
      expect(provenanceDuNom(await Ecluse.detect(gabarit)),
          ProvenanceEntite.tournureSeule);
      // Vue de détection différente du texte (clé de NIR séparée).
      expect(
          provenanceDuNom(
              await Ecluse.detect('$gabarit NIR 2550814168025 clé 38.')),
          ProvenanceEntite.tournureSeule);
    });

    test('NameDetector, deuxième lecture (séparateurs `_`)', () {
      final es = const NameDetector()
          .detect('Le dossier de Verdier est transmis. Voir pierre_dupont.pdf');
      final tournure = es.where((e) => e.value == 'Verdier');
      expect(tournure.map((e) => e.provenance),
          everyElement(ProvenanceEntite.tournureSeule));
    });

    test('la provenance n\'entre ni dans == ni dans le texte imprimé', () {
      const a = DetectedEntity(
          type: EntityType.nom,
          start: 0,
          end: 3,
          value: 'abc',
          confidence: 0.6,
          provenance: ProvenanceEntite.tournureSeule);
      const b = DetectedEntity(
          type: EntityType.nom,
          start: 0,
          end: 3,
          value: 'abc',
          confidence: 0.6);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), isNot(contains('abc')));
    });
  });

  group('le signal ne change rien à ce qui est masqué', () {
    for (final t in [
      'Le dossier de Verdier est transmis. Verdier rappelle.',
      'Mme Sophie Verdier est arrivée. Le dossier de Verdier est transmis.',
      'À la demande de Gaillard, le dossier de Perrin est clos.',
      'Aucun nom ici.',
    ]) {
      test('« ${t.length > 24 ? t.substring(0, 24) : t} »', () async {
        final p = await Apercu.propose(t);
        final r =
            await Apercu.applique(p, const DecisionApercu(), texteAEnvoyer: t);
        final attendu = await Ecluse.redact(t);
        expect(r.maskedText, attendu.maskedText);
        expect(r.mapping.entrees.toList(), attendu.mapping.entrees.toList());
        expect(r.mapping.jetons.toList(), attendu.mapping.jetons.toList());
      });
    }

    test('descriptionMoteur et versionMoteur ne mentionnent pas le signal', () {
      expect(Ecluse.descriptionMoteur, isNot(contains('verifier')));
      expect(Ecluse.descriptionMoteur, isNot(contains('vérifier')));
    });
  });

  group('aucune valeur du texte hors de l\'objet proposé', () {
    test('EntiteProposee et Proposition n\'impriment pas la valeur', () async {
      final p = await Apercu.propose('Le dossier de Verdier est transmis.');
      expect(p.entites.single.toString(), isNot(contains('Verdier')));
      expect(p.entites.single.toString(), contains('aVerifier'));
      expect(p.aVerifier.toString(), isNot(contains('Verdier')));
    });

    test('un refus invalide ne cite pas la valeur', () async {
      final p = await Apercu.propose('Le dossier de Verdier est transmis.');
      try {
        await Apercu.applique(p, const DecisionApercu(refusees: {99}),
            texteAEnvoyer: 'Le dossier de Verdier est transmis.');
        fail('doit refuser');
      } on ApercuException catch (e) {
        expect(e.toString(), isNot(contains('Verdier')));
      }
    });
  });
}
