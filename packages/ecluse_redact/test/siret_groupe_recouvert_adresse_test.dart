import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-324 : un SIRET de clé juste écrit en groupes 3-3-3-5 dont le dernier
/// groupe est suivi d'un mot (« 732 829 320 33565 puis ») était recouvert par
/// une « adresse » (cinq chiffres lus comme code postal, mot lu comme commune)
/// plus longue que lui : `resolveOverlaps` gardait l'adresse et les neuf
/// premiers chiffres, le SIREN, restaient en clair (sonde P2-303 : 13 / 40).
/// Valeurs synthétiques : SIREN 732 829 320 (clé de Luhn juste) ; le quatorzième
/// chiffre est calculé pour que la clé du SIRET soit juste.
void main() {
  const siren = '732829320';

  /// Le SIRET de clé juste « siren + nic4 + clé » (clé de Luhn calculée).
  String siretJuste(String nic4) {
    for (var c = 0; c < 10; c++) {
      final s = '$siren$nic4$c';
      if (isLuhnValid(s)) return s;
    }
    throw StateError('aucune clé');
  }

  String groupes(String s) =>
      '${s.substring(0, 3)} ${s.substring(3, 6)} ${s.substring(6, 9)} '
      '${s.substring(9)}';

  // Quatre premiers chiffres du dernier groupe : tous les départements et
  // formes de code postal usuels, dont un « 0 » de tête.
  const nics = ['3356', '6493', '6195', '0123', '9500', '7000', '2A00'];

  group('SIRET groupé de clé juste suivi d\'un mot', () {
    for (final nic in nics.where((n) => !n.contains('A'))) {
      final v = groupes(siretJuste(nic));
      for (final mot in ['puis signature', 'dans la case', 'Vesoul']) {
        test('$mot : le SIRET est masqué en entier, aucun chiffre en clair',
            () async {
          final t = 'Pièce jointe 3 : $v $mot.';
          final r = await Ecluse.redact(t);
          for (final g in v.split(' ')) {
            expect(r.maskedText, isNot(contains(g)), reason: 'groupe de $nic');
          }
          final e = r.entities.where((e) => e.type == EntityType.siren);
          expect(e, hasLength(1));
          expect(t.substring(e.single.start, e.single.end), v);
          expect(
              r.entities.where((e) => e.type == EntityType.adresse), isEmpty);
          expect(
              r.warnings.where(RegExp(r'SIRET.*sans le mot.*masqué').hasMatch),
              hasLength(1));
        });
      }
    }

    test('avec le mot « siret » : masqué aussi', () async {
      final v = groupes(siretJuste('3356'));
      final r = await Ecluse.redact('SIRET $v puis signature.');
      expect(r.maskedText, isNot(contains('732')));
      expect(r.entities.where((e) => e.type == EntityType.adresse), isEmpty);
    });
  });

  group('une vraie adresse reste masquée', () {
    test('adresse complète à côté d\'un SIRET', () async {
      final v = groupes(siretJuste('3356'));
      const adr = '12 rue des Lilas, 70000 Vesoul';
      final t = 'Pièce jointe 3 : $v puis $adr.';
      final r = await Ecluse.redact(t);
      final a = r.entities.where((e) => e.type == EntityType.adresse).toList();
      expect(a, hasLength(1));
      expect(t.substring(a.single.start, a.single.end), startsWith('12 rue'));
      expect(r.maskedText, isNot(contains('Vesoul')));
      expect(r.maskedText, isNot(contains('732')));
    });

    test('code postal et commune seuls, sans SIRET', () async {
      final r = await Ecluse.redact('Adresse : 70000 Vesoul, bâtiment B.');
      expect(
          r.entities.where((e) => e.type == EntityType.adresse), hasLength(1));
    });

    test('SIRET de clé fausse suivi d\'un mot : inchangé (rien de masqué)',
        () async {
      // Quatorze chiffres de clé fausse sans le mot : un nombre ordinaire.
      final bon = siretJuste('3356');
      final faux = '${bon.substring(0, 13)}${(int.parse(bon[13]) + 1) % 10}';
      final r =
          await Ecluse.redact('Pièce jointe 3 : ${groupes(faux)} puis x.');
      expect(r.entities.where((e) => e.type == EntityType.siren), isEmpty);
    });
  });

  test('aucune valeur du texte dans un message', () async {
    final v = groupes(siretJuste('3356'));
    final r = await Ecluse.redact('Pièce jointe 3 : $v puis signature.');
    for (final w in r.warnings) {
      for (final g in v.split(' ')) {
        expect(w, isNot(contains(g)));
      }
    }
  });
}
