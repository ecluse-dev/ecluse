import 'dart:convert';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-193 : `TableDeCorrespondance`, le type qui remplace `Map<String, String>`
/// pour `RedactResult.mapping` et pour l'entrée de `Ecluse.restore`. Valeurs
/// synthétiques.
void main() {
  TableDeCorrespondance table() => TableDeCorrespondance.depuis(
      {'[NOM_1]': 'Sophie Verdier', '[TEL_1]': '06 12 34 56 78'});

  group('opérations exposées', () {
    test('length, isEmpty, jetons, [], contient, entrees', () {
      final t = table();
      expect(t.length, 2);
      expect(t.isEmpty, isFalse);
      expect(t.isNotEmpty, isTrue);
      expect(t.jetons, ['[NOM_1]', '[TEL_1]']);
      expect(t['[NOM_1]'], 'Sophie Verdier');
      expect(t['[NOM_9]'], isNull);
      expect(t.contient('[TEL_1]'), isTrue);
      expect(t.contient('[TEL_2]'), isFalse);
      expect(t.entrees, [
        ('[NOM_1]', 'Sophie Verdier'),
        ('[TEL_1]', '06 12 34 56 78'),
      ]);
    });

    test('depuis recopie la carte : la modifier ensuite ne change rien', () {
      final carte = {'[NOM_1]': 'Sophie Verdier'};
      final t = TableDeCorrespondance.depuis(carte);
      carte['[NOM_2]'] = 'Thomas Fabrier';
      carte.remove('[NOM_1]');
      expect(t.entrees, [('[NOM_1]', 'Sophie Verdier')]);
    });

    test('table vide', () {
      final t = TableDeCorrespondance.depuis(const {});
      expect(t.isEmpty, isTrue);
      expect(t.length, 0);
      expect(t.toString(), 'TableDeCorrespondance(0 jeton)');
    });
  });

  group('opacité', () {
    test('toString : le nombre de jetons, jamais un jeton ni une valeur', () {
      expect(table().toString(), 'TableDeCorrespondance(2 jetons)');
      expect(
          TableDeCorrespondance.depuis({'[NOM_1]': 'Sophie Verdier'})
              .toString(),
          'TableDeCorrespondance(1 jeton)');
      expect('${table()}', isNot(contains('Verdier')));
      expect('${table()}', isNot(contains('NOM_1')));
    });

    test('jsonEncode refuse la table au lieu de l\'écrire en clair', () {
      expect(() => jsonEncode(table()),
          throwsA(isA<JsonUnsupportedObjectError>()));
      expect(() => jsonEncode({'table': table()}),
          throwsA(isA<JsonUnsupportedObjectError>()));
    });

    test('pas d\'égalité structurelle : deux tables égales ne sont pas ==', () {
      expect(table() == table(), isFalse);
    });

    test('n\'est ni une Map ni un Iterable', () {
      final Object t = table();
      expect(t, isNot(isA<Map<Object?, Object?>>()));
      expect(t, isNot(isA<Iterable<Object?>>()));
    });
  });

  group('vider', () {
    test('plus aucun jeton ni valeur, et restore ne restaure plus rien', () {
      final t = table();
      expect(Ecluse.restore('[NOM_1] au [TEL_1]', t),
          'Sophie Verdier au 06 12 34 56 78');
      t.vider();
      expect(t.isEmpty, isTrue);
      expect(t.entrees, isEmpty);
      expect(t['[NOM_1]'], isNull);
      expect(Ecluse.restore('[NOM_1] au [TEL_1]', t), '[NOM_1] au [TEL_1]');
    });

    test('vider le résultat d\'un appel ne touche pas un autre appel',
        () async {
      final a = await Ecluse.redact('Mme Sophie Verdier arrive.');
      final b = await Ecluse.redact('Mme Sophie Verdier arrive.');
      a.mapping.vider();
      expect(a.mapping.isEmpty, isTrue);
      expect(Ecluse.restore(b.maskedText, b.mapping),
          'Mme Sophie Verdier arrive.');
    });
  });

  group('Ecluse.restore et restoreAvecRapport exigent le type', () {
    test('restore sur le résultat d\'un appel', () async {
      const texte = 'M. Jean Dupont, tél. 06 12 34 56 78.';
      final r = await Ecluse.redact(texte);
      expect(r.mapping, isA<TableDeCorrespondance>());
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });

    test('restoreAvecRapport sur une table construite à la main', () {
      final (texte, restes) = Ecluse.restoreAvecRapport(
          '[NOM_1], [NOM_3] et NOM_1.',
          TableDeCorrespondance.depuis({'[NOM_1]': 'Sophie Verdier'}));
      expect(texte, 'Sophie Verdier, [NOM_3] et NOM_1.');
      expect(restes.map((j) => '$j'), ['NOM_3', 'NOM_1']);
    });
  });
}
