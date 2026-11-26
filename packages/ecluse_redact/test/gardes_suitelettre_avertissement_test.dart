import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-304 (principe du 26 novembre, point 0) : les gardes de P2-276
/// `nir_suitelettre`, `finess_suitelettre` et `adr_confusables` retirent un
/// masquage sans rien dire. Une garde ne rend jamais une donnée silencieuse :
/// `Ecluse.redact` signale chaque candidat écarté « à vérifier » dans
/// `RedactResult.warnings` (type et positions, jamais la valeur). **Aucun
/// masquage ne change.** Tous les textes sont synthétiques ; les clés NIR sont
/// volontairement fausses.
void main() {
  const nirFaux = '1 26 07 65 873 965 62';
  const finess = '329300446';
  final motifNir = RegExp(r'NIR.*non masqué.*à vérifier');
  final motifFiness = RegExp(r'FINESS.*non masqué.*à vérifier');
  final motifAdresse = RegExp(r'adresse.*non masquée.*à vérifier');

  Iterable<String> signaux(RedactResult r, RegExp m) =>
      r.warnings.where(m.hasMatch);

  group('nir_suitelettre', () {
    test('écarté et signalé, sans la valeur ni aucun de ses groupes', () async {
      final texte = 'Dossier $nirFaux I2 reçu.';
      final r = await Ecluse.redact(texte);
      expect(r.entities.where((e) => e.type == EntityType.nir), isEmpty);
      final a = signaux(r, motifNir).toList();
      expect(a, hasLength(1));
      expect(a.single, contains('1 occurrence'));
      expect(a.single, contains('position 8'));
      for (final g in ['873', '965', '07 65']) {
        expect(a.single, isNot(contains(g)));
      }
    });

    test('plusieurs occurrences : un seul avertissement, compte et positions',
        () async {
      final r = await Ecluse.redact(
          'Dossier $nirFaux I2 reçu ; autre dossier $nirFaux o1 reçu.');
      final a = signaux(r, motifNir).toList();
      expect(a, hasLength(1));
      expect(a.single, contains('2 occurrences'));
    });

    test('suite faite de chiffres seuls : le NIR reste masqué, pas de signal',
        () async {
      final r = await Ecluse.redact('Dossier $nirFaux 12 pièces reçues.');
      expect(r.entities.where((e) => e.type == EntityType.nir), isNotEmpty);
      expect(signaux(r, motifNir), isEmpty);
    });

    test('sans suite : masqué, pas de signal', () async {
      final r = await Ecluse.redact('Dossier $nirFaux reçu.');
      expect(r.entities.where((e) => e.type == EntityType.nir), isNotEmpty);
      expect(signaux(r, motifNir), isEmpty);
    });
  });

  group('finess_suitelettre', () {
    test('écarté et signalé, sans la valeur', () async {
      final r = await Ecluse.redact('Rattaché au $finess I1 depuis janvier.');
      expect(r.entities.where((e) => e.type == EntityType.finess), isEmpty);
      final a = signaux(r, motifFiness).toList();
      expect(a, hasLength(1));
      expect(a.single, contains('1 occurrence'));
      expect(a.single, isNot(contains(finess)));
      expect(a.single, isNot(contains('329')));
    });

    test('avec contexte : la suite ne compte pas, masqué, pas de signal',
        () async {
      final r = await Ecluse.redact('FINESS $finess I1 depuis janvier.');
      expect(r.entities.where((e) => e.type == EntityType.finess), isNotEmpty);
      expect(signaux(r, motifFiness), isEmpty);
    });

    test('sans suite : masqué, pas de signal', () async {
      final r = await Ecluse.redact('Rattaché au $finess depuis janvier.');
      expect(r.entities.where((e) => e.type == EntityType.finess), isNotEmpty);
      expect(signaux(r, motifFiness), isEmpty);
    });
  });

  group('adr_confusables', () {
    test('commune faite de confusions d\'OCR : non masquée, signalée',
        () async {
      final r = await Ecluse.redact('Pièce détachée 05214 OO1l reçue.');
      expect(r.entities.where((e) => e.type == EntityType.adresse), isEmpty);
      final a = signaux(r, motifAdresse).toList();
      expect(a, hasLength(1));
      expect(a.single, contains('1 occurrence'));
      expect(a.single, isNot(contains('05214')));
    });

    test('vraie adresse : masquée, pas de signal', () async {
      final r = await Ecluse.redact('Courrier à renvoyer à 70000 Vesoul.');
      expect(r.entities.where((e) => e.type == EntityType.adresse), isNotEmpty);
      expect(signaux(r, motifAdresse), isEmpty);
    });

    test('arrondissement : masqué, pas de signal', () async {
      final r = await Ecluse.redact('Courrier à renvoyer à 69003 Lyon 3e.');
      expect(r.entities.where((e) => e.type == EntityType.adresse), isNotEmpty);
      expect(signaux(r, motifAdresse), isEmpty);
    });
  });

  test('texte sans rien : aucun avertissement de garde', () async {
    final r = await Ecluse.redact('Réunion lundi à 14 h, salle 3.');
    expect(signaux(r, motifNir), isEmpty);
    expect(signaux(r, motifFiness), isEmpty);
    expect(signaux(r, motifAdresse), isEmpty);
  });
}
