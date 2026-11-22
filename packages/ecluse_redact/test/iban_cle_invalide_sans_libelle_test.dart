import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-252 : un IBAN de forme française à clé invalide est masqué en entier par
/// `Ecluse.redact`, avec ou sans libellé « IBAN » devant (celui de P2-188 ne
/// couvrait que les séparateurs simples). Avant, une fenêtre FINESS ou
/// téléphone au milieu masquait une partie du numéro et laissait le reste en
/// clair. Cas synthétiques (clé fausse fabriquée), jamais une valeur réelle.
void main() {
  const nbsp = ' ';
  // Fenêtre de 9 chiffres Luhn-valide (FINESS) à l'intérieur : cas du corpus
  // d'identifiants, graine 42.
  const finess = 'FR24 2714 2872 6996 4N17 7449 410';
  // Fenêtre de 12 chiffres lue comme téléphone, blancs insécables.
  final telephone = 'FR09${nbsp}4803${nbsp}3596${nbsp}3322${nbsp}8160'
      '${nbsp}5C60${nbsp}553';

  for (final (nom, iban) in [
    ('FINESS au milieu', finess),
    ('blancs insécables', telephone)
  ]) {
    test('$nom : masqué en entier, rien du numéro en clair', () async {
      final r = await Ecluse.redact("L'IBAN $iban a été refusé par la banque.");
      expect(r.entities, hasLength(1));
      expect(r.entities.single.type, EntityType.iban);
      expect(r.entities.single.value, iban);
      expect(r.maskedText, isNot(contains('2714')));
      expect(r.maskedText, isNot(contains('4803')));
      expect(r.maskedText, isNot(contains('7449')));
      expect(r.maskedText, isNot(contains('5C60')));
      expect(r.warnings.join(' '), contains('clé invalide'));
      // Le message d'avertissement ne porte jamais la valeur.
      expect(r.warnings.join(' '), isNot(contains('2714')));
      expect(r.maskedText.contains('IBAN'), isTrue);
    });

    test('$nom : sans le mot IBAN devant, masqué aussi', () async {
      final r = await Ecluse.redact('Virement refusé : $iban hier.');
      expect(r.entities, hasLength(1));
      expect(r.entities.single.type, EntityType.iban);
      expect(r.entities.single.value, iban);
    });

    test('$nom : restauration exacte', () async {
      final texte = "L'IBAN $iban a été refusé.";
      final r = await Ecluse.redact(texte);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('IBAN valide : confiance 1,0, aucun avertissement de clé', () async {
    final r = await Ecluse.redact('IBAN FR76 3000 6000 0112 3456 7890 189.');
    expect(r.entities.single.confidence, 1.0);
    expect(r.warnings.join(' '), isNot(contains('clé invalide')));
  });
}
