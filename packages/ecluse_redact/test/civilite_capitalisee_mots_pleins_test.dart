import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-325 (mesure P2-322, `agent/specs/P2-322.md`) : derrière « Monsieur »,
/// « Madame », « M. » ou « Mme » **capitalisés**, un homonyme de patronyme en
/// minuscules que les listes d'exclusion laissent en clair partait sans
/// avertissement (296 / 1 388 de la sonde). Pour **sept mots pleins** seulement
/// (`doit, fait, va, vient`, `demain, matin, soir`), l'avertissement « mot pris
/// pour un nom commun » est désormais rendu ; les 67 mots-outils (articles,
/// prépositions, pronoms, « est ») restent muets : ils avertiraient sur presque
/// toute phrase naturelle (limite assumée, `LIMITES.md`). Aucun masquage ne
/// change.
void main() {
  final motif = RegExp('mot pris pour un nom commun');
  const civilites = ['Monsieur', 'Madame', 'M.', 'Mme'];
  const motsPleins = ['doit', 'fait', 'va', 'vient', 'demain', 'matin', 'soir'];

  Iterable<String> signaux(RedactResult r) => r.warnings.where(motif.hasMatch);

  group('mots pleins derrière une civilité capitalisée : signalés', () {
    for (final c in civilites) {
      for (final m in motsPleins) {
        test('$c $m', () async {
          final t = '$c $m est venu ce matin.';
          final r = await Ecluse.redact(t);
          final a = signaux(r).toList();
          expect(a, hasLength(1), reason: '$c $m');
          expect(a.single, contains('1 occurrence'));
          expect(a.single, contains('position ${c.length + 1}'));
          // Jamais la valeur du mot dans le message.
          expect(a.single, isNot(contains(' $m ')));
          // Aucun masquage ne change.
          expect(r.maskedText, t);
          expect(r.entities, isEmpty);
        });
      }
    }
  });

  group('mots-outils : inchangés, muets', () {
    for (final c in civilites) {
      for (final m in ['est', 'de', 'des', 'le', 'la', 'sur', 'pour', 'on']) {
        test('$c $m', () async {
          final t = '$c $m venu ce soir.';
          final r = await Ecluse.redact(t);
          expect(signaux(r), isEmpty, reason: '$c $m');
          expect(r.entities, isEmpty);
          expect(r.maskedText, t);
        });
      }
    }
  });

  group('autres cas', () {
    test('un nom derrière la civilité : masqué, pas de signal', () async {
      final r = await Ecluse.redact('Madame Pelletan est venue.');
      expect(r.entities, isNotEmpty);
      expect(signaux(r), isEmpty);
    });

    test('mot plein sans civilité devant : pas de signal', () async {
      final r = await Ecluse.redact('Il fait beau, il vient demain matin.');
      expect(signaux(r), isEmpty);
    });

    test('mot plein collé à un autre mot (« faite ») : pas de signal',
        () async {
      final r = await Ecluse.redact('Madame faite venir.');
      expect(signaux(r), isEmpty);
    });

    test('deux occurrences : un seul avertissement, compte 2', () async {
      final r = await Ecluse.redact('Madame fait un malaise. Monsieur va mal.');
      final a = signaux(r).toList();
      expect(a, hasLength(1));
      expect(a.single, contains('2 occurrences'));
    });
  });
}
