import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Scission détection / application de `Ecluse.redact` (P2-16, préalable de
/// l'aperçu de `agent/specs/P2-08.md`). `Ecluse.detect` ne masque rien et ne
/// modifie jamais l'état d'un `Dossier`.
void main() {
  const textes = [
    'Mme Sophie Verdier, née le 12/03/1950, joignable au 01 99 00 12 34, '
        'habite à Thionville. Le Dr Martin, pneumologue, la suit depuis ses '
        '74 ans. Contact : sophie.verdier@example.fr',
    'Aucun nom ici, seulement une réunion à Dole.',
    '',
    'M. Jean Dupont puis M. Dupont ; Mme Dupont rappelle.',
  ];

  group('detect rend les entités de redact', () {
    for (final t in textes) {
      test('« ${t.length > 30 ? t.substring(0, 30) : t} »', () async {
        final entites = await Ecluse.detect(t);
        final r = await Ecluse.redact(t);
        expect(entites, r.entities);
      });
    }

    test('avec un dossier fraîchement créé, mêmes entités', () async {
      for (final t in textes) {
        final entites = await Ecluse.detect(t, dossier: Dossier());
        final r = await Ecluse.redact(t, dossier: Dossier());
        expect(entites, r.entities);
      }
    });

    test('des détecteurs fournis par l\'appelant sont respectés', () async {
      final entites =
          await Ecluse.detect('Mme Sophie Verdier arrive.', detectors: []);
      expect(entites, isEmpty);
    });
  });

  group('detect n\'a aucun effet de bord', () {
    test('aucun numéro de jeton consommé', () async {
      final d = Dossier();
      for (var i = 0; i < 3; i++) {
        await Ecluse.detect('Mme Sophie Verdier arrive.', dossier: d);
      }
      final r = await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      expect(r.maskedText, 'Mme [NOM_1] arrive.');
    });

    test('aucun patronyme n\'est établi dans le dossier', () async {
      final d = Dossier();
      await Ecluse.detect('Mme Sophie Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('Verdier a confirmé.', dossier: d);
      expect(r.maskedText, 'Verdier a confirmé.');
    });

    test('la carte du dossier reste vide', () async {
      final d = Dossier();
      await Ecluse.detect('Mme Sophie Verdier arrive.', dossier: d);
      expect(d.restore('[NOM_1]'), '[NOM_1]');
    });
  });

  group('detect et le cycle de vie du dossier', () {
    test('un dossier fermé refuse la détection', () async {
      final d = Dossier()..fermer();
      await expectLater(Ecluse.detect('Bonjour.', dossier: d),
          throwsA(isA<DossierFermeException>()));
    });

    test('detect est sérialisé après les appels précédents du dossier',
        () async {
      final d = Dossier();
      // Non attendu : la détection voit l'état laissé par l'appel précédent.
      final premier = Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final entites = await Ecluse.detect('Verdier a confirmé.', dossier: d);
      await premier;
      expect(entites.map((e) => e.value), ['Verdier']);
    });
  });
}
