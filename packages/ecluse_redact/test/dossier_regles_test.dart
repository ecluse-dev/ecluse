import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Règle de noms entre documents d'un dossier (P2-13, N3 de
/// `agent/specs/P2-05.md` § 5) : N1 (`identiteComplete`, défaut) ou N2
/// (`inclusion`, la règle d'un document appliquée entre documents).
void main() {
  const textes = [
    'Mme Sophie Verdier, née le 12/03/1950, joignable au 01 99 00 12 34, '
        'habite à Thionville. Le Dr Martin, pneumologue, la suit depuis ses '
        '74 ans. Contact : sophie.verdier@example.fr',
    'M. Jean Dupont puis M. Dupont ; Mme Dupont rappelle.',
    'Aucun nom ici.',
  ];

  group('défaut : N1, comportement de P2-06 inchangé', () {
    test('le constructeur sans argument est N1', () async {
      for (final d in [Dossier(), Dossier(regle: RegleNoms.identiteComplete)]) {
        await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
        final r = await Ecluse.redact('Mme Verdier rappelle.', dossier: d);
        expect(r.maskedText, 'Mme [NOM_2] rappelle.');
      }
    });

    test('N1 explicite et défaut donnent les mêmes sorties', () async {
      final a = Dossier();
      final b = Dossier(regle: RegleNoms.identiteComplete);
      for (final t in [
        'Mme Sophie Verdier arrive.',
        'Mme Verdier rappelle.',
        'M. Thomas Fabrier, M. Fabrier.',
        'Mme Sophie Verdier.',
      ]) {
        final ra = await Ecluse.redact(t, dossier: a);
        final rb = await Ecluse.redact(t, dossier: b);
        expect(rb.maskedText, ra.maskedText);
        expect(rb.mapping, ra.mapping);
      }
    });
  });

  group('N2 : fusion par inclusion entre documents', () {
    test('le premier document d\'un dossier est celui d\'avant', () async {
      for (final t in textes) {
        final sans = await Ecluse.redact(t);
        final avec = await Ecluse.redact(t,
            dossier: Dossier(regle: RegleNoms.inclusion));
        expect(avec.maskedText, sans.maskedText);
        expect(avec.mapping, sans.mapping);
      }
    });

    test(
        'une mention partielle rejoint l\'identité complète d\'un document '
        'précédent', () async {
      final d = Dossier(regle: RegleNoms.inclusion);
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('Mme Verdier rappelle.', dossier: d);
      expect(r.maskedText, 'Mme [NOM_1] rappelle.');
      expect(r.mapping, {'[NOM_1]': 'Sophie Verdier'});
    });

    test('une mention complète enrichit une identité partielle antérieure',
        () async {
      final d = Dossier(regle: RegleNoms.inclusion);
      await Ecluse.redact('Mme Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('Mme Sophie Verdier rappelle.', dossier: d);
      expect(r.maskedText, 'Mme [NOM_1] rappelle.');
      // La carte du dossier reprend la forme la plus complète : une réponse
      // qui cite le jeton pour le premier document est restaurée en forme
      // complète (limite assumée, LIMITES.md § 5.3).
      expect(d.restore('[NOM_1]'), 'Sophie Verdier');
    });

    test(
        'deux personnes de même patronyme restent distinctes, la mention '
        'ambiguë reçoit son propre jeton', () async {
      final d = Dossier(regle: RegleNoms.inclusion);
      final r1 = await Ecluse.redact('Mme Sophie Loyer arrive.', dossier: d);
      final r2 = await Ecluse.redact('Mme Laure Loyer arrive.', dossier: d);
      final r3 = await Ecluse.redact('Mme Loyer rappelle.', dossier: d);
      expect(r1.maskedText, 'Mme [NOM_1] arrive.');
      expect(r2.maskedText, 'Mme [NOM_2] arrive.');
      expect(r3.maskedText, 'Mme [NOM_3] rappelle.');
    });

    test('un couple (civilités de sexe différent) garde deux jetons', () async {
      final d = Dossier(regle: RegleNoms.inclusion);
      await Ecluse.redact('M. Thomas Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('Mme Verdier rappelle.', dossier: d);
      expect(r.maskedText, 'Mme [NOM_2] rappelle.');
    });

    test('e-mail et téléphone ne dépendent pas de la règle de noms', () async {
      for (final regle in RegleNoms.values) {
        final d = Dossier(regle: regle);
        await Ecluse.redact('Contact : sophie.verdier@example.fr', dossier: d);
        final r = await Ecluse.redact('Écrire à sophie.verdier@example.fr',
            dossier: d);
        expect(r.maskedText, 'Écrire à [EMAIL_1]', reason: '$regle');
      }
    });

    test('la règle est choisie par dossier, pas globale', () async {
      final n1 = Dossier();
      final n2 = Dossier(regle: RegleNoms.inclusion);
      for (final d in [n1, n2]) {
        await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      }
      final r1 = await Ecluse.redact('Mme Verdier rappelle.', dossier: n1);
      final r2 = await Ecluse.redact('Mme Verdier rappelle.', dossier: n2);
      expect(r1.maskedText, 'Mme [NOM_2] rappelle.');
      expect(r2.maskedText, 'Mme [NOM_1] rappelle.');
    });
  });
}
