import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-271 : un FINESS dicté en lettres derrière un nom d'établissement est
/// couvert en entier. Avant, le nom d'établissement, détecté plus long (il
/// avalait les premiers mots-nombres), l'emportait au tri des chevauchements
/// et laissait la fin du numéro dicté en clair (6 à 9 FINESS sur 129 selon la
/// variante de dictée). Cas synthétiques du corpus transcrit, graine 42.
void main() {
  // (nom, texte, mots du numéro dicté)
  const cas = [
    (
      'chiffre par chiffre',
      'établissement ch de metz finess deux huit sept trois cinq un six zéro cinq',
      'deux huit sept trois cinq un six zéro cinq',
    ),
    (
      'par groupes',
      'établissement ch de metz finess soixante-treize trois cent '
          'soixante-dix-huit cinq cent quarante-sept un',
      'soixante-treize trois cent soixante-dix-huit cinq cent quarante-sept un',
    ),
    (
      'le zéro dit « o »',
      'établissement ch de metz finess o neuf o o deux trois un un o',
      'o neuf o o deux trois un un o',
    ),
    (
      'régional',
      'établissement ch de metz finess vingt-cinq quarante-deux trente-quatre '
          'soixante et un zéro',
      'vingt-cinq quarante-deux trente-quatre soixante et un zéro',
    ),
  ];

  for (final (nom, texte, numero) in cas) {
    test('FINESS dicté couvert en entier derrière un établissement : $nom',
        () async {
      final r = await Ecluse.redact(texte);
      final debut = texte.indexOf(numero);
      final finess = r.entities.where((e) => e.type == EntityType.finess);
      expect(finess, hasLength(1));
      expect(finess.single.start, debut);
      expect(finess.single.end, debut + numero.length);
      // Aucune entité ne laisse un mot du numéro en clair ; le nom de
      // l'établissement reste masqué avant le numéro.
      for (final mot in numero.split(' ')) {
        expect(r.maskedText.contains(' $mot'), isFalse, reason: nom);
      }
      expect(r.entities.where((e) => e.type == EntityType.etablissement),
          hasLength(1));
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('un nom d\'établissement sans numéro dicté : inchangé', () async {
    final r = await Ecluse.redact('établissement ch de metz finess est fermé');
    expect(r.entities.where((e) => e.type == EntityType.finess), isEmpty);
  });
}
