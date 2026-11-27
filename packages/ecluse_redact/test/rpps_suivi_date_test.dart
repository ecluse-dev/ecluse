import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-306 : un RPPS de onze chiffres (clé de Luhn juste) écrit « neuf chiffres,
/// espace, deux chiffres » et suivi d'un mois ou de « ans » était écarté par la
/// garde `rpps_finess_date` : les deux derniers chiffres partaient en clair
/// (mesure P2-303, 39 / 39). Décision du mainteneur, « dans le doute,
/// masquer » : les onze chiffres sont masqués en entier. Valeurs synthétiques.
void main() {
  // Dix chiffres + clé de Luhn : « 10003456786 » ; on le coupe après neuf.
  String avecCle(String corps) {
    var somme = 0;
    for (var i = 0; i < corps.length; i++) {
      var d = int.parse(corps[corps.length - 1 - i]);
      if (i % 2 == 0) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      somme += d;
    }
    return '$corps${(10 - somme % 10) % 10}';
  }

  final rpps = avecCle('1000345678');
  final coupe = '${rpps.substring(0, 9)} ${rpps.substring(9)}';

  for (final suite in ['mars', 'mai', 'juin', 'ans']) {
    test('« … $suite » : masqué en entier, aucun chiffre en clair', () async {
      final texte = 'Numéro noté $coupe $suite en marge.';
      final r = await Ecluse.redact(texte);
      final d = texte.indexOf(coupe);
      final couvert = {
        for (final e in r.entities)
          for (var i = e.start; i < e.end; i++) i
      };
      for (var i = d; i < d + coupe.length; i++) {
        if (texte[i] != ' ') expect(couvert, contains(i), reason: 'rang $i');
      }
      expect(r.maskedText, isNot(contains(rpps.substring(9))));
      expect(r.maskedText, isNot(matches(RegExp(r'[0-9]{9}'))));
    });
  }

  test('un RPPS écrit d\'un tenant suivi d\'un mois : inchangé, masqué',
      () async {
    final r = await Ecluse.redact('Numéro noté $rpps mars en marge.');
    expect(r.entities.where((e) => e.type == EntityType.rpps), hasLength(1));
  });
}
