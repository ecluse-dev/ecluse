import 'package:ecluse_core/ecluse_core.dart' show EntityType;
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Numéro de TVA intracommunautaire (P2-260) : « FR » + clé de deux chiffres +
/// SIREN de neuf chiffres, masqué en entier, type `siren` (décision du
/// 23 novembre, point 4). Nombres fabriqués : SIREN 247510795, clé juste 16.
/// Avant la tâche, 29 sur 35 partaient en clair et 6 étaient masqués en partie
/// comme RPPS (« FR » laissé en clair).
void main() {
  const juste = 'FR16247510795';

  for (final (nom, tva) in [
    ('compact', juste),
    ('groupé', 'FR 16 247 510 795'),
    ('clé séparée', 'FR16 247 510 795'),
    ('minuscules', 'fr16247510795'),
  ]) {
    test('$nom, clé juste : masqué en entier, type siren', () async {
      final texte = 'N° de TVA intracommunautaire : $tva.';
      final r = await Ecluse.redact(texte);
      expect(r.entities, hasLength(1));
      expect(r.entities.single.type, EntityType.siren);
      expect(r.entities.single.value, tva);
      expect(r.maskedText, 'N° de TVA intracommunautaire : [SIREN_1].');
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      expect(r.warnings.join(' '), isNot(contains('clé invalide')));
    });
  }

  test('clé juste sans aucun libellé : masqué aussi', () async {
    final r = await Ecluse.redact('Facture émise par $juste le 12/03.');
    expect(r.entities.any((e) => e.value == juste), isTrue);
    expect(r.maskedText, isNot(contains('247510795')));
  });

  test('clé fausse derrière un libellé : masqué, 0,3, « à vérifier »',
      () async {
    final r = await Ecluse.redact('TVA : FR99247510795 notée.');
    expect(r.entities.single.type, EntityType.siren);
    expect(r.entities.single.value, 'FR99247510795');
    expect(r.entities.single.confidence, 0.3);
    expect(r.warnings.join(' '), contains('clé invalide'));
    expect(r.warnings.join(' '), isNot(contains('247510795')));
  });

  test('clé fausse sans libellé : masquée comme TVA à 0,3 (P2-323)', () async {
    final r = await Ecluse.redact('Référence FR99247510795 notée.');
    expect(r.entities.single.type, EntityType.siren);
    expect(r.entities.single.confidence, 0.3);
  });

  test('le RPPS de onze chiffres n\'est plus pris à la place de la TVA',
      () async {
    final r = await Ecluse.redact('N° de TVA intracommunautaire : $juste.');
    expect(r.entities.where((e) => e.type == EntityType.rpps), isEmpty);
  });

  test('un vrai RPPS à côté d\'un « FR » ordinaire ne change pas', () async {
    final r = await Ecluse.redact('RPPS 10000000016 en FR.');
    expect(r.entities.single.type, EntityType.rpps);
    expect(r.entities.single.value, '10000000016');
  });
}
