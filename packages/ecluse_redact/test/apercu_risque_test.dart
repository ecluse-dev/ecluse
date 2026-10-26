import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// Rapport de risque de l'aperçu (P2-23, décision 7 de P2-08) : calculé sur le
/// texte que l'application produirait, sans rien modifier.
const _texte = 'Mme Sophie Verdier, 66 ans, habite à Thionville. Le Dr Martin, '
    'pneumologue, la suit. Contact : sophie.verdier@example.fr';

void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  List<Object?> resume(RiskReport r) => [
        r.evaluation.statut,
        r.evaluation.estimate?.f,
        [for (final s in r.evaluation.spans) (s.start, s.end, s.text)],
        r.limites,
      ];

  group('Apercu.risque', () {
    test('égal au rapport que donnerait l\'application, tout accepté',
        () async {
      final p = await Apercu.propose(_texte);
      final avant = await Apercu.risque(p, riskReference: ref);
      final r = await Apercu.applique(p, const DecisionApercu(),
          texteAEnvoyer: _texte, riskReference: ref);
      expect(resume(avant), resume(r.risque!));
    });

    test('égal au rapport de l\'application avec refus et ajout', () async {
      final p = await Apercu.propose(_texte);
      final email = p.entites.firstWhere((e) => e.type == EntityType.email);
      final debut = _texte.indexOf('Thionville');
      final decision = DecisionApercu(
        refusees: {email.id},
        ajouts: [AjoutManuel(debut, debut + 10, EntityType.adresse)],
      );
      final avant =
          await Apercu.risque(p, decision: decision, riskReference: ref);
      final r = await Apercu.applique(p, decision,
          texteAEnvoyer: _texte, riskReference: ref);
      expect(resume(avant), resume(r.risque!));
      // L'ajout masque Thionville : le lieu n'est plus évalué.
      expect(r.maskedText, isNot(contains('Thionville')));
    });

    test('égal à l\'application dans un dossier déjà alimenté', () async {
      final a = Dossier();
      final b = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: a);
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: b);
      final p = await Apercu.propose(_texte, dossier: a);
      final avant = await Apercu.risque(p, riskReference: ref, dossier: a);
      final pb = await Apercu.propose(_texte, dossier: b);
      final r = await Apercu.applique(pb, const DecisionApercu(),
          texteAEnvoyer: _texte, riskReference: ref, dossier: b);
      expect(resume(avant), resume(r.risque!));
    });

    test('aucun effet de bord sur le dossier', () async {
      final d = Dossier();
      final temoin = Dossier();
      final p = await Apercu.propose(_texte, dossier: d);
      for (var i = 0; i < 3; i++) {
        await Apercu.risque(p, riskReference: ref, dossier: d);
      }
      final r = await Ecluse.redact(_texte, dossier: d);
      final attendu = await Ecluse.redact(_texte, dossier: temoin);
      expect(r.maskedText, attendu.maskedText);
      expect(r.mapping, attendu.mapping);
    });

    test('décision invalide, dossier fermé, proposition périmée : refus',
        () async {
      final d = Dossier();
      final p = await Apercu.propose(_texte, dossier: d);
      await expectLater(
          Apercu.risque(p,
              decision: const DecisionApercu(refusees: {999}),
              riskReference: ref,
              dossier: d),
          throwsA(isA<ApercuException>()));
      await Ecluse.redact('Autre document.', dossier: d);
      await expectLater(Apercu.risque(p, riskReference: ref, dossier: d),
          throwsA(isA<ApercuException>()));
      d.fermer();
      await expectLater(Apercu.risque(p, riskReference: ref, dossier: d),
          throwsA(isA<DossierFermeException>()));
    });
  });

  group('Proposition.risque', () {
    test('absent sans référence, présent et égal à Apercu.risque avec',
        () async {
      final sans = await Apercu.propose(_texte);
      expect(sans.risque, isNull, reason: 'fonction inactive');
      final avec = await Apercu.propose(_texte, riskReference: ref);
      expect(avec.risque, isNotNull);
      expect(resume(avec.risque!),
          resume(await Apercu.risque(avec, riskReference: ref)));
      // Les entités proposées sont les mêmes avec ou sans référence.
      expect(avec.entites.length, sans.entites.length);
    });

    test('dans un dossier : même rapport que l\'application, rien modifié',
        () async {
      final d = Dossier();
      final temoin = Dossier();
      final p = await Apercu.propose(_texte, dossier: d, riskReference: ref);
      final pt = await Apercu.propose(_texte, dossier: temoin);
      final r = await Apercu.applique(pt, const DecisionApercu(),
          texteAEnvoyer: _texte, riskReference: ref, dossier: temoin);
      expect(resume(p.risque!), resume(r.risque!));
      final suite = await Ecluse.redact(_texte, dossier: d);
      expect(suite.maskedText, r.maskedText);
    });
  });
}
