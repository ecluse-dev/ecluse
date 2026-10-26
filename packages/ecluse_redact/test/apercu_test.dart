import 'dart:math';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Composant d'aperçu avec validation (P2-18, contrat de
/// `agent/specs/P2-08.md` et choix de `DECISIONS.md`).
const _texte = 'Mme Sophie Verdier, née le 12/03/1950, joignable au '
    '01 99 00 12 34, habite à Thionville. Le Dr Martin la suit. '
    'Contact : sophie.verdier@example.fr';

// Valeur fabriquée à l'exécution (aucun secret réel dans le dépôt).
final String _secret =
    'ghp_${'aB3dE6gH9jK2mN5pQ8sT1vW4yZ7cF0hJ3kL6' * 2}'.substring(0, 4 + 36);

void main() {
  group('équivalence : tout accepté = Ecluse.redact', () {
    for (final t in [
      _texte,
      'Aucun nom ici, seulement une réunion à Dole.',
      '',
      'M. Jean Dupont puis M. Dupont ; Mme Dupont rappelle.',
    ]) {
      test('« ${t.length > 30 ? t.substring(0, 30) : t} »', () async {
        final p = await Apercu.propose(t);
        final r =
            await Apercu.applique(p, const DecisionApercu(), texteAEnvoyer: t);
        final attendu = await Ecluse.redact(t);
        expect(r.maskedText, attendu.maskedText);
        expect(r.mapping, attendu.mapping);
        expect(r.mapping.keys.toList(), attendu.mapping.keys.toList());
        expect(r.warnings, attendu.warnings);
        expect(r.entities, attendu.entities);
      });
    }

    test('même séquence de documents dans un dossier', () async {
      final a = Dossier();
      final b = Dossier();
      for (final t in [_texte, 'Verdier a rappelé.', 'Mme Sophie Verdier.']) {
        final p = await Apercu.propose(t, dossier: a);
        final r = await Apercu.applique(p, const DecisionApercu(),
            texteAEnvoyer: t, dossier: a);
        final attendu = await Ecluse.redact(t, dossier: b);
        expect(r.maskedText, attendu.maskedText);
        expect(r.mapping, attendu.mapping);
      }
    });
  });

  group('proposition', () {
    test('entités, identifiants, résumé par type', () async {
      final p = await Apercu.propose(_texte);
      expect(p.texte, _texte);
      expect(p.entites.map((e) => e.id).toList(),
          List.generate(p.entites.length, (i) => i));
      for (final e in p.entites) {
        expect(_texte.substring(e.start, e.end), e.valeur);
      }
      expect(p.resume[EntityType.email], 1);
      expect(p.resume[EntityType.telephone], 1);
    });

    test('aucun effet de bord sur le dossier', () async {
      final d = Dossier();
      for (var i = 0; i < 3; i++) {
        await Apercu.propose(_texte, dossier: d);
      }
      final r = await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      expect(r.maskedText, 'Mme [NOM_1] arrive.');
    });

    test('refuseSecrets refuse avant toute proposition', () async {
      await expectLater(Apercu.propose('clé $_secret', refuseSecrets: true),
          throwsA(isA<SecretsRefusedException>()));
    });
  });

  group('refus', () {
    test('un refus laisse l\'entité en clair et sans jeton', () async {
      final p = await Apercu.propose(_texte);
      final email = p.entites.firstWhere((e) => e.type == EntityType.email);
      final r = await Apercu.applique(p, DecisionApercu(refusees: {email.id}),
          texteAEnvoyer: _texte);
      expect(r.maskedText, contains('sophie.verdier@example.fr'));
      expect(r.maskedText, isNot(contains('[EMAIL_')));
      expect(Ecluse.restore(r.maskedText, r.mapping), _texte);
    });

    test('un refus ne consomme aucun numéro de jeton', () async {
      final d = Dossier();
      final p = await Apercu.propose(_texte, dossier: d);
      final noms = {
        for (final e in p.entites)
          if (e.type == EntityType.nom) e.id
      };
      await Apercu.applique(p, DecisionApercu(refusees: noms),
          texteAEnvoyer: _texte, dossier: d);
      final r = await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      expect(r.maskedText, 'Mme [NOM_1] arrive.');
    });

    test('un identifiant inconnu est une erreur explicite', () async {
      final p = await Apercu.propose(_texte);
      await expectLater(
          Apercu.applique(p, const DecisionApercu(refusees: {999}),
              texteAEnvoyer: _texte),
          throwsA(isA<ApercuException>()));
    });

    test('refuser une entité structurelle exige une option explicite',
        () async {
      const t = 'Dossier 1 99 05 13 055 001 46 (NIR de test).';
      final p = await Apercu.propose(t);
      final structurelles =
          p.entites.where((e) => e.tier == DetectorTier.structural).toList();
      if (structurelles.isEmpty) return; // NIR de test non reconnu : sans objet
      final decision = DecisionApercu(refusees: {structurelles.first.id});
      await expectLater(Apercu.applique(p, decision, texteAEnvoyer: t),
          throwsA(isA<ApercuException>()));
      final r = await Apercu.applique(p, decision,
          texteAEnvoyer: t, autoriserRefusStructurel: true);
      expect(r.maskedText, contains(structurelles.first.valeur));
    });

    test('refuser un secret est toujours interdit', () async {
      final t = 'clé $_secret';
      final p = await Apercu.propose(t);
      final s = p.entites.firstWhere((e) => e.type == EntityType.secret);
      await expectLater(
          Apercu.applique(p, DecisionApercu(refusees: {s.id}),
              texteAEnvoyer: t, autoriserRefusStructurel: true),
          throwsA(isA<ApercuException>()));
    });
  });

  group('ajouts manuels', () {
    test('un passage manqué est masqué et restauré à l\'identique', () async {
      const t = 'Le dossier de Zanzibar est clos.';
      final p = await Apercu.propose(t);
      expect(p.entites, isEmpty);
      final debut = t.indexOf('Zanzibar');
      final r = await Apercu.applique(
          p,
          DecisionApercu(
              ajouts: [AjoutManuel(debut, debut + 8, EntityType.nom)]),
          texteAEnvoyer: t);
      expect(r.maskedText, 'Le dossier de [NOM_1] est clos.');
      expect(r.mapping, {'[NOM_1]': 'Zanzibar'});
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });

    test('un ajout hors bornes ou vide est refusé', () async {
      final p = await Apercu.propose('abc');
      for (final a in [
        AjoutManuel(-1, 2, EntityType.nom),
        AjoutManuel(2, 2, EntityType.nom),
        AjoutManuel(1, 10, EntityType.nom),
      ]) {
        await expectLater(
            Apercu.applique(p, DecisionApercu(ajouts: [a]),
                texteAEnvoyer: 'abc'),
            throwsA(isA<ApercuException>()),
            reason: '$a');
      }
    });

    test('les espaces en bordure d\'un ajout restent en clair (P2-20)',
        () async {
      const t = 'Voir le chef de projet puis le chef de projet encore.';
      final p = await Apercu.propose(t);
      final a = t.indexOf('chef');
      final b = t.lastIndexOf('chef');
      final r = await Apercu.applique(
          p,
          DecisionApercu(ajouts: [
            // Sélection « à la souris » : espace avant et après.
            AjoutManuel(a - 1, a + 'chef de projet'.length + 1, EntityType.nom),
            AjoutManuel(b, b + 'chef de projet'.length, EntityType.nom),
          ]),
          texteAEnvoyer: t);
      expect(r.mapping.values, ['chef de projet']);
      expect(r.maskedText, 'Voir le [NOM_1] puis le [NOM_1] encore.');
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });

    test('un ajout fait seulement d\'espaces est refusé', () async {
      final p = await Apercu.propose('abc   def');
      await expectLater(
          Apercu.applique(
              p, DecisionApercu(ajouts: [AjoutManuel(3, 6, EntityType.nom)]),
              texteAEnvoyer: 'abc   def'),
          throwsA(isA<ApercuException>()));
    });

    test('un ajout qui coupe une paire de substituts est refusé (P2-21)',
        () async {
      const t = 'Bonjour 😀 Zanzibar arrive.';
      final p = await Apercu.propose(t);
      final i = t.indexOf('😀');
      for (final (s, e) in [
        (i + 1, i + 11), // début au milieu de l'émoji
        (i - 3, i + 1), // fin au milieu de l'émoji
        (i + 1, i + 2), // seulement la moitié basse
      ]) {
        await expectLater(
            Apercu.applique(
                p, DecisionApercu(ajouts: [AjoutManuel(s, e, EntityType.nom)]),
                texteAEnvoyer: t),
            throwsA(isA<ApercuException>()),
            reason: '($s, $e)');
      }
    });

    test('un ajout qui encadre un émoji entier reste accepté', () async {
      const t = 'Bonjour 😀 Zanzibar arrive.';
      final p = await Apercu.propose(t);
      final i = t.indexOf('😀');
      final r = await Apercu.applique(p,
          DecisionApercu(ajouts: [AjoutManuel(i, i + 2 + 9, EntityType.nom)]),
          texteAEnvoyer: t);
      expect(r.maskedText, 'Bonjour [NOM_1] arrive.');
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });

    test('le type secret est refusé pour un ajout', () async {
      final p = await Apercu.propose('abc def');
      await expectLater(
          Apercu.applique(
              p, DecisionApercu(ajouts: [AjoutManuel(0, 3, EntityType.secret)]),
              texteAEnvoyer: 'abc def'),
          throwsA(isA<ApercuException>()));
    });

    test('un ajout qui recouvre entièrement une détection la remplace',
        () async {
      final p = await Apercu.propose(_texte);
      final email = p.entites.firstWhere((e) => e.type == EntityType.email);
      final r = await Apercu.applique(
          p,
          DecisionApercu(ajouts: [
            AjoutManuel(email.start - 8, email.end, EntityType.nom)
          ]),
          texteAEnvoyer: _texte);
      expect(r.maskedText, isNot(contains('sophie.verdier@')));
      expect(r.maskedText, isNot(contains('Contact')));
      expect(Ecluse.restore(r.maskedText, r.mapping), _texte);
    });

    test('un chevauchement partiel est une erreur explicite', () async {
      final p = await Apercu.propose(_texte);
      final email = p.entites.firstWhere((e) => e.type == EntityType.email);
      await expectLater(
          Apercu.applique(
              p,
              DecisionApercu(ajouts: [
                AjoutManuel(email.start + 3, email.end + 1, EntityType.nom)
              ]),
              texteAEnvoyer: _texte),
          throwsA(isA<ApercuException>()));
    });

    test('un ajout inclus dans une détection est refusé (redondant)', () async {
      final p = await Apercu.propose(_texte);
      final email = p.entites.firstWhere((e) => e.type == EntityType.email);
      await expectLater(
          Apercu.applique(
              p,
              DecisionApercu(ajouts: [
                AjoutManuel(email.start + 2, email.start + 6, EntityType.nom)
              ]),
              texteAEnvoyer: _texte),
          throwsA(isA<ApercuException>()));
    });

    test('deux ajouts qui se chevauchent sont refusés', () async {
      final p = await Apercu.propose('abcdefghij');
      await expectLater(
          Apercu.applique(
              p,
              DecisionApercu(ajouts: [
                AjoutManuel(0, 5, EntityType.nom),
                AjoutManuel(3, 8, EntityType.nom)
              ]),
              texteAEnvoyer: 'abcdefghij'),
          throwsA(isA<ApercuException>()));
    });
  });

  group('liaison au texte et cycle de vie', () {
    test('un texte modifié depuis l\'aperçu est refusé', () async {
      final p = await Apercu.propose(_texte);
      await expectLater(
          Apercu.applique(p, const DecisionApercu(),
              texteAEnvoyer: '$_texte !'),
          throwsA(isA<ApercuException>()));
    });

    test('un refus d\'application ne modifie pas le dossier', () async {
      final d = Dossier();
      final p = await Apercu.propose(_texte, dossier: d);
      await expectLater(
          Apercu.applique(p, const DecisionApercu(refusees: {999}),
              texteAEnvoyer: _texte, dossier: d),
          throwsA(isA<ApercuException>()));
      final r = await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      expect(r.maskedText, 'Mme [NOM_1] arrive.');
    });

    test('un dossier fermé refuse la proposition et l\'application', () async {
      final d = Dossier();
      final p = await Apercu.propose(_texte, dossier: d);
      d.fermer();
      await expectLater(Apercu.propose(_texte, dossier: d),
          throwsA(isA<DossierFermeException>()));
      await expectLater(
          Apercu.applique(p, const DecisionApercu(),
              texteAEnvoyer: _texte, dossier: d),
          throwsA(isA<DossierFermeException>()));
    });
  });

  group('péremption (P2-19)', () {
    test('une proposition périmée par un autre document est refusée', () async {
      final d = Dossier();
      final p = await Apercu.propose(_texte, dossier: d);
      await Ecluse.redact('Verdier a rappelé.', dossier: d);
      await expectLater(
          Apercu.applique(p, const DecisionApercu(),
              texteAEnvoyer: _texte, dossier: d),
          throwsA(isA<ApercuException>()));
    });

    test('périmée par une autre application d\'aperçu', () async {
      final d = Dossier();
      final p1 = await Apercu.propose(_texte, dossier: d);
      final p2 = await Apercu.propose(_texte, dossier: d);
      await Apercu.applique(p1, const DecisionApercu(),
          texteAEnvoyer: _texte, dossier: d);
      await expectLater(
          Apercu.applique(p2, const DecisionApercu(),
              texteAEnvoyer: _texte, dossier: d),
          throwsA(isA<ApercuException>()));
    });

    test('une proposition ne s\'applique qu\'au dossier qui l\'a produite',
        () async {
      final a = Dossier();
      final p = await Apercu.propose(_texte, dossier: a);
      await expectLater(
          Apercu.applique(p, const DecisionApercu(),
              texteAEnvoyer: _texte, dossier: Dossier()),
          throwsA(isA<ApercuException>()));
      await expectLater(
          Apercu.applique(p, const DecisionApercu(), texteAEnvoyer: _texte),
          throwsA(isA<ApercuException>()));
    });

    test('sans dossier à la proposition, aucun dossier à l\'application',
        () async {
      final p = await Apercu.propose(_texte);
      await expectLater(
          Apercu.applique(p, const DecisionApercu(),
              texteAEnvoyer: _texte, dossier: Dossier()),
          throwsA(isA<ApercuException>()));
    });

    test('un refus de péremption ne modifie pas le dossier', () async {
      final d = Dossier();
      final temoin = Dossier();
      final p = await Apercu.propose(_texte, dossier: d);
      await Ecluse.redact('Verdier a rappelé.', dossier: d);
      await Ecluse.redact('Verdier a rappelé.', dossier: temoin);
      await expectLater(
          Apercu.applique(p, const DecisionApercu(),
              texteAEnvoyer: _texte, dossier: d),
          throwsA(isA<ApercuException>()));
      final r = await Ecluse.redact(_texte, dossier: d);
      final attendu = await Ecluse.redact(_texte, dossier: temoin);
      expect(r.maskedText, attendu.maskedText);
      expect(r.mapping, attendu.mapping);
    });
  });

  test(
      'propriété : restauration identique pour des décisions aléatoires '
      '(graine 42)', () async {
    final rng = Random(42);
    final p = await Apercu.propose(_texte);
    for (var i = 0; i < 40; i++) {
      final refusees = <int>{
        for (final e in p.entites)
          if (e.tier != DetectorTier.structural &&
              e.type != EntityType.secret &&
              rng.nextBool())
            e.id
      };
      final r = await Apercu.applique(p, DecisionApercu(refusees: refusees),
          texteAEnvoyer: _texte);
      expect(Ecluse.restore(r.maskedText, r.mapping), _texte,
          reason: 'refusées : $refusees');
    }
  });
}
