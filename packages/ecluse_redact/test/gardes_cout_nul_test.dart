import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-276 : trois gardes à coût nul contre des masquages à tort hérités
/// (mesure de P2-272, chemin `Ecluse.redact`, témoin durci de P2-268). Chaque
/// cas « à tort » est une phrase ordinaire synthétique du témoin ; chaque
/// témoin « garde » prouve que ce que la garde ne vise pas reste masqué.
/// Valeurs fabriquées, jamais reprises d'une source réelle.
void main() {
  group('NIR à clé fausse sans libellé : suite abîmée par l\'OCR', () {
    test('« 19226.71o31.753o6.26I » (numéro de commande) : rien masqué',
        () async {
      final r = await Ecluse.redact(
          'Bon de commande n° 19226.71o31.753o6.26I à rapprocher de la facture.');
      expect(r.entities.where((e) => e.type == EntityType.nir), isEmpty);
    });

    test('même NIR à clé fausse, suite faite de chiffres seuls : masqué',
        () async {
      final r =
          await Ecluse.redact('Saisie : 2.85.05.78.006.084.46 12 pièces.');
      expect(r.entities.where((e) => e.type == EntityType.nir), hasLength(1));
    });

    test('même NIR à clé fausse, sans suite : masqué', () async {
      final r = await Ecluse.redact('Saisie erronée : 2.85.05.78.006.084.46.');
      expect(r.entities.where((e) => e.type == EntityType.nir), hasLength(1));
    });

    test(
        'NIR à clé fausse derrière un libellé fort : masqué même suivi d\'une '
        'lettre', () async {
      final r = await Ecluse.redact('NIR : 2.85.05.78.006.084.46 I1 noté.');
      expect(r.entities.where((e) => e.type == EntityType.nir), isNotEmpty);
    });
  });

  group('FINESS neuf chiffres sans contexte : suite abîmée par l\'OCR', () {
    test('« 697 296 556 I1 » (identifiant machine) : rien masqué', () async {
      final r = await Ecluse.redact(
          "Identifiant machine 697 296 556 I1 à saisir dans l'inventaire.");
      expect(r.entities.where((e) => e.type == EntityType.finess), isEmpty);
    });

    test('même neuf chiffres, sans suite : masqué à 0,5', () async {
      final r = await Ecluse.redact('Identifiant machine 697 296 556 reçu.');
      final f = r.entities.where((e) => e.type == EntityType.finess);
      expect(f, hasLength(1));
      expect(f.single.confidence, 0.5);
    });

    test('neuf chiffres suivis d\'un nombre court en chiffres : masqué',
        () async {
      final r = await Ecluse.redact('Rattaché au 284404969 12 lits ouverts.');
      expect(
          r.entities.where((e) => e.type == EntityType.finess), hasLength(1));
    });

    test('avec le mot FINESS, la suite ne compte pas : masqué à 0,9', () async {
      final r = await Ecluse.redact('FINESS 697 296 556 I1 de la structure.');
      final f = r.entities.where((e) => e.type == EntityType.finess);
      expect(f, hasLength(1));
      expect(f.single.confidence, 0.9);
    });
  });

  group('adresse « code postal + commune » : mot fait de confusables', () {
    test('« 05214 oo1l » (pièce détachée) : rien masqué', () async {
      final r = await Ecluse.redact(
          'Pièce détachée 05214 oo1l commandée auprès du fournisseur.');
      expect(r.entities.where((e) => e.type == EntityType.adresse), isEmpty);
    });

    test('« 43751 o8669 » (poste) : rien masqué', () async {
      final r = await Ecluse.redact(
          'Poste 88933 43751 o8669 4 redémarré après la mise à jour.');
      expect(r.entities.where((e) => e.type == EntityType.adresse), isEmpty);
    });

    test('un vrai nom fait de lettres seules (« OO ») reste masqué', () async {
      final r = await Ecluse.redact('Domicile : 31110 OO, depuis 2019.');
      expect(r.entities.where((e) => e.type == EntityType.adresse), isNotEmpty);
      expect(r.maskedText, isNot(contains('31110')));
    });

    test('une vraie commune reste masquée', () async {
      final r = await Ecluse.redact('Domicile : 25000 Besançon, depuis 2019.');
      expect(r.entities.where((e) => e.type == EntityType.adresse), isNotEmpty);
    });
  });
}
