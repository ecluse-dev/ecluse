import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// P2-323 (décision du 27 novembre) : un SIRET de clé de Luhn juste sans le mot
/// « siret », et un numéro de TVA à clé fausse sans libellé, sont **masqués**
/// (type `siren`). Nombres fabriqués : SIREN 732 829 320 (clé juste),
/// SIRET 73282932000009 (clé juste), 73282932000001 (clé fausse), TVA de clé
/// juste FR44 732829320 ; on met la clé 51 pour une TVA à clé fausse.
void main() {
  const detector = FinessDetector();

  Future<List<DetectedEntity>> detect(String text) =>
      detector.detect(NormalizedText.identity(text));

  group('SIRET de clé juste sans le mot « siret »', () {
    test('collé et groupé : siren, confiance 0,5, empan entier', () async {
      for (final v in ['73282932000009', '732 829 320 00009']) {
        final t = 'Merci de recopier $v dans la case.';
        final e = await detect(t);
        expect(e, hasLength(1), reason: v);
        expect(e.single.type, EntityType.siren, reason: v);
        expect(e.single.confidence, 0.5, reason: v);
        expect(t.substring(e.single.start, e.single.end), v, reason: v);
      }
    });

    test('4-4-4-2 ou soudé à un nombre voisin : signalé, pas masqué', () async {
      // Les mêmes quatorze chiffres de clé juste (73282932000009), écrits en
      // 4-4-4-2 ou en onze chiffres puis un nombre de trois chiffres, que la
      // compaction soude. Un identifiant de onze chiffres ne doit pas perdre
      // le chevauchement contre un « SIRET » plus long (P2-323).
      for (final t in [
        'Note 7328 2932 0000 09 hier.',
        'Réf 73282932000 009 suite.',
      ]) {
        expect(await detect(t), isEmpty, reason: t);
        expect(FinessDetector.ecartesSiret(t), hasLength(1), reason: t);
      }
    });

    test('clé fausse sans le mot : rien (un nombre ordinaire)', () async {
      expect(await detect('Valeur 73282932000001 notée.'), isEmpty);
    });

    test('treize ou quinze chiffres : rien', () async {
      expect(await detect('Valeur 7328293200000 notée.'), isEmpty);
      expect(await detect('Valeur 732829320000090 notée.'), isEmpty);
    });

    test('avec le mot « siret » : inchangé, confiance 0,9', () async {
      final e = await detect('SIRET 73282932000009 noté.');
      expect(e.single.confidence, 0.9);
    });
  });

  group('TVA à clé fausse sans libellé', () {
    test('masquée en siren, confiance 0,3, empan entier', () async {
      const t = 'Merci de recopier FR51732829320 dans la case.';
      final e = await detect(t);
      expect(e, hasLength(1));
      expect(e.single.type, EntityType.siren);
      expect(e.single.confidence, 0.3);
      expect(t.substring(e.single.start, e.single.end), 'FR51732829320');
    });

    test('clé juste sans libellé : inchangée, confiance 0,9', () async {
      final e = await detect('Valeur FR44732829320 notée.');
      expect(e.single.confidence, 0.9);
    });
  });
}
