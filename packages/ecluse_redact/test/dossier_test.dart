import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// État de dossier en mémoire (P2-06, décisions de `DECISIONS.md`,
/// « Préconisations … validées par délégation » ; spec `agent/specs/P2-05.md`).
// Valeur fabriquée à l'exécution (aucun secret réel dans le dépôt).
final String _secret =
    'ghp_${'aB3dE6gH9jK2mN5pQ8sT1vW4yZ7cF0hJ3kL6' * 2}'.substring(0, 4 + 36);

void main() {
  const textes = [
    'Mme Sophie Verdier, née le 12/03/1950, joignable au 01 99 00 12 34, '
        'habite à Thionville. Le Dr Martin, pneumologue, la suit depuis ses '
        '74 ans. Contact : sophie.verdier@example.fr',
    'Aucun nom ici, seulement une réunion à Dole.',
    '',
    'M. Jean Dupont puis M. Dupont ; Mme Dupont rappelle.',
  ];

  group('équivalence : le premier texte d\'un dossier est celui d\'avant', () {
    for (final t in textes) {
      test('« ${t.length > 30 ? t.substring(0, 30) : t} »', () async {
        final sans = await Ecluse.redact(t);
        final avec = await Ecluse.redact(t, dossier: Dossier());
        expect(avec.maskedText, sans.maskedText);
        expect(avec.mapping, sans.mapping);
        expect(avec.mapping.keys.toList(), sans.mapping.keys.toList());
        expect(avec.warnings, sans.warnings);
        expect(avec.entities.length, sans.entities.length);
      });
    }

    test('dossier: null est l\'appel d\'avant', () async {
      final a = await Ecluse.redact(textes[0]);
      final b = await Ecluse.redact(textes[0], dossier: null);
      expect(b.maskedText, a.maskedText);
      expect(b.mapping, a.mapping);
    });
  });

  group('cohérence entre les documents d\'un dossier', () {
    test('la même personne (identité complète) garde son jeton', () async {
      final d = Dossier();
      final r1 = await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final r2 =
          await Ecluse.redact('Rappeler Mme Sophie Verdier.', dossier: d);
      expect(r1.maskedText, 'Mme [NOM_1] arrive.');
      expect(r2.maskedText, 'Rappeler Mme [NOM_1].');
    });

    test('deux personnes ne partagent jamais un jeton', () async {
      final d = Dossier();
      final r1 = await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final r2 = await Ecluse.redact('M. Thomas Fabrier arrive.', dossier: d);
      expect(r1.maskedText, 'Mme [NOM_1] arrive.');
      expect(r2.maskedText, 'M. [NOM_2] arrive.');
    });

    test('ordre d\'apparition différent : mêmes jetons', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier puis M. Thomas Fabrier.',
          dossier: d);
      final r = await Ecluse.redact(
          'M. Thomas Fabrier puis Mme Sophie Verdier.',
          dossier: d);
      expect(r.maskedText, 'M. [NOM_2] puis Mme [NOM_1].');
    });

    test('e-mail et téléphone répétés : même jeton', () async {
      final d = Dossier();
      final r1 = await Ecluse.redact(
          'Contact : sophie.verdier@example.fr / 01 99 00 12 34',
          dossier: d);
      final r2 = await Ecluse.redact(
          'Écrire à sophie.verdier@example.fr ou appeler le 01 99 00 12 34',
          dossier: d);
      expect(r1.maskedText, 'Contact : [EMAIL_1] / [TELEPHONE_1]');
      expect(r2.maskedText, 'Écrire à [EMAIL_1] ou appeler le [TELEPHONE_1]');
    });

    test(
        'N1 : une mention partielle d\'un autre document reçoit un nouveau '
        'jeton, jamais une fusion par patronyme', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Loyer arrive.', dossier: d);
      final r2 = await Ecluse.redact('Mme Loyer rappelle.', dossier: d);
      final r3 = await Ecluse.redact('Mme Laure Loyer rappelle.', dossier: d);
      expect(r2.maskedText, 'Mme [NOM_2] rappelle.');
      expect(r3.maskedText, 'Mme [NOM_3] rappelle.');
      expect(r2.mapping, {'[NOM_2]': 'Loyer'});
    });

    test('dans un document, la règle d\'inclusion est inchangée', () async {
      final d = Dossier();
      final r =
          await Ecluse.redact('M. Jean Dupont puis M. Dupont.', dossier: d);
      expect(r.maskedText, 'M. [NOM_1] puis M. [NOM_1].');
    });
  });

  group('restauration par le dossier', () {
    test('une réponse qui cite un jeton d\'un message précédent', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      await Ecluse.redact('M. Thomas Fabrier arrive.', dossier: d);
      expect(d.restore('Bonjour [NOM_1], voyez avec [NOM_2].'),
          'Bonjour Sophie Verdier, voyez avec Thomas Fabrier.');
    });

    test('deux dossiers sont cloisonnés : chacun restaure sa carte', () async {
      final a = Dossier();
      final b = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: a);
      await Ecluse.redact('M. Thomas Fabrier arrive.', dossier: b);
      expect(a.restore('[NOM_1]'), 'Sophie Verdier');
      expect(b.restore('[NOM_1]'), 'Thomas Fabrier');
    });

    test('un jeton inconnu du dossier est laissé tel quel', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      expect(d.restore('[NOM_7] et [NOM_1]'), '[NOM_7] et Sophie Verdier');
    });

    test('la carte d\'un appel ne contient que ses propres jetons', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('M. Thomas Fabrier arrive.', dossier: d);
      expect(r.mapping, {'[NOM_2]': 'Thomas Fabrier'});
    });
  });

  group('cycle de vie : refus explicite plutôt que silence', () {
    test('un dossier fermé refuse de masquer et de restaurer', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      d.fermer();
      expect(d.estFerme, isTrue);
      await expectLater(Ecluse.redact('Bonjour.', dossier: d),
          throwsA(isA<DossierFermeException>()));
      expect(() => d.restore('[NOM_1]'), throwsA(isA<DossierFermeException>()));
      d.fermer(); // idempotent
    });

    test('la représentation textuelle n\'expose rien', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier, sophie.verdier@example.fr',
          dossier: d);
      final texte = '$d ${d.runtimeType}';
      expect(texte, isNot(contains('Verdier')));
      expect(texte, isNot(contains('NOM_1')));
      expect(texte, isNot(contains('example.fr')));
      expect(DossierFermeException().toString(), isNot(contains('Verdier')));
    });

    test('un refus de secret ne consomme aucun numéro', () async {
      final d = Dossier();
      await expectLater(
          Ecluse.redact('Mme Sophie Verdier a la clé $_secret',
              refuseSecrets: true, dossier: d),
          throwsA(isA<SecretsRefusedException>()));
      final r = await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      expect(r.maskedText, 'Mme [NOM_1] arrive.');
    });
  });

  group('jeton littéral dans un texte ultérieur', () {
    test('avertir, sans modifier le texte', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('Brouillon : « [NOM_1] a confirmé ».',
          dossier: d);
      expect(r.maskedText, 'Brouillon : « [NOM_1] a confirmé ».');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('[NOM_1]'));
      expect(r.warnings.single, contains('littéral'));
    });

    test(
        'un jeton littéral jamais attribué ne déclenche pas d\'avertissement '
        'et reste évité', () async {
      final d = Dossier();
      final r = await Ecluse.redact('Cité : [NOM_1]. Mme Sophie Verdier.',
          dossier: d);
      expect(r.warnings, isEmpty);
      expect(r.maskedText, 'Cité : [NOM_1]. Mme [NOM_2].');
    });
  });

  group('concurrence : les appels d\'un même dossier sont sérialisés', () {
    test('numérotation unique et dans l\'ordre des appels', () async {
      const personnes = [
        'Mme Sophie Verdier',
        'M. Thomas Fabrier',
        'Mme Laure Delaunay',
        'M. Marc Chevrier',
        'Mme Nathalie Aubry',
        'M. Julien Vasseur',
        'Mme Céline Gauthier',
        'M. Antoine Perrot',
      ];
      final d = Dossier();
      final futurs = [
        for (final p in personnes)
          Ecluse.redact('Rendez-vous de $p.', dossier: d)
      ];
      final resultats = await Future.wait(futurs);
      for (var i = 0; i < personnes.length; i++) {
        expect(resultats[i].mapping,
            {'[NOM_${i + 1}]': personnes[i].split(' ').skip(1).join(' ')});
      }
    });
  });

  group('avec le rapport de risque', () {
    test('le dossier et riskReference se combinent sans changer le texte',
        () async {
      final ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
      final d = Dossier();
      final a = await Ecluse.redact('Mme Sophie Verdier, 66 ans, à Dole.',
          dossier: d, riskReference: ref);
      expect(a.maskedText, 'Mme [NOM_1], 66 ans, à Dole.');
      expect(a.risque, isNotNull);
    });
  });
}
