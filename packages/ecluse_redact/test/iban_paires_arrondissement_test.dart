import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-277 : deux trous vus par la sonde de P2-272 (`Ecluse.redact`, valeurs
/// synthétiques) : un IBAN de forme française à clé fausse écrit en paires de
/// chiffres (« FR 07 76 41 … », 0 / 40 couverts) et une adresse « code postal
/// + commune » dont le numéro d'arrondissement restait en clair
/// (« 69003 Lyon 3e », 0 / 140 couverts en entier).
void main() {
  group('IBAN à clé fausse écrit en paires', () {
    for (final iban in [
      'FR 07 76 41 89 28 08 9R 53 87 58 42 81 6',
      'FR 12 72 46 59 35 88 63 53 65 41 95 10 6',
      'FR-33-29-84-10-47-55-62-18-90-31-27-45-8',
    ]) {
      test('masqué en entier : $iban', () async {
        final texte = 'Pièce jointe 3 : $iban puis signature.';
        final r = await Ecluse.redact(texte);
        final c = r.entities.where((e) => e.type == EntityType.iban).toList();
        expect(c, hasLength(1));
        expect(c.single.value, iban);
        expect(r.entities, hasLength(1));
        expect(r.maskedText, endsWith(' puis signature.'));
      });
    }

    test(
        '« FR » suivi de groupes de trois ou de quatre : pas pris pour des '
        'paires', () async {
      for (final code in [
        'FR-567-333-112-009-073-102-391-644-0',
        'FR 873I 9221 9836 91l5 73O7 6l71 l',
      ]) {
        final r = await Ecluse.redact('Code produit $code en rayon.');
        expect(r.entities.where((e) => e.type == EntityType.iban), isEmpty,
            reason: code);
      }
    });

    test('« FR » suivi de quelques paires : pas un IBAN', () async {
      final r = await Ecluse.redact('Ligne FR 07 76 41 89 28 au dossier.');
      expect(r.entities.where((e) => e.type == EntityType.iban), isEmpty);
    });

    test('forme en groupes de quatre : inchangée', () async {
      final r = await Ecluse.redact(
          'À recopier FR95 1383 3568 2257 2628 4987 793 ici.');
      final c = r.entities.where((e) => e.type == EntityType.iban);
      expect(c, hasLength(1));
      expect(c.single.value, 'FR95 1383 3568 2257 2628 4987 793');
    });
  });

  group('adresse « code postal + commune » avec arrondissement', () {
    for (final (adresse, suite) in [
      ('69003 Lyon 3e', '.'),
      ('13001 Marseille 1er', '.'),
      ('75015 Paris 15', '.'),
      ('69002 Lyon 2', '.'),
      ('75008 Paris 8e', ', merci.'),
      ('13008 Marseille 8ème', '.'),
    ]) {
      test('masquée en entier : $adresse', () async {
        final r = await Ecluse.redact('Courrier à renvoyer à $adresse$suite');
        final a = r.entities.where((e) => e.type == EntityType.adresse);
        expect(a, hasLength(1));
        expect(a.single.value, adresse);
        expect(r.maskedText, endsWith(suite));
        expect(r.maskedText, isNot(contains('Lyon')));
      });
    }

    test('adresse avec voie : arrondissement couvert aussi', () async {
      final r =
          await Ecluse.redact('Écrire au 12 rue des Lilas, 69003 Lyon 3e svp.');
      final a = r.entities.where((e) => e.type == EntityType.adresse);
      expect(a, hasLength(1));
      expect(a.single.value, endsWith('Lyon 3e'));
    });

    test('sans arrondissement : inchangée', () async {
      final r = await Ecluse.redact('Courrier à renvoyer à 69003 Lyon.');
      final a = r.entities.where((e) => e.type == EntityType.adresse);
      expect(a.single.value, '69003 Lyon');
    });

    test('nombre ordinaire derrière la commune : n\'est pas pris', () async {
      final r = await Ecluse.redact('Rendez-vous à 69003 Lyon 3 fois par an.');
      final a = r.entities.where((e) => e.type == EntityType.adresse);
      expect(a.single.value, '69003 Lyon');
    });

    test('numéro hors de la ville (« Paris 25 ») : n\'est pas pris', () async {
      final r = await Ecluse.redact('Courrier à renvoyer à 75008 Paris 25.');
      final a = r.entities.where((e) => e.type == EntityType.adresse);
      expect(a.single.value, '75008 Paris');
    });

    test('autre commune (« Besançon 3 ») : n\'est pas prise', () async {
      final r = await Ecluse.redact('Courrier à renvoyer à 25000 Besançon 3.');
      final a = r.entities.where((e) => e.type == EntityType.adresse);
      expect(a.single.value, '25000 Besançon');
    });
  });
}
