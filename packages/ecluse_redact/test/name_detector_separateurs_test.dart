import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Durcissement preventif du decoupage interne de `name_detector.dart`.
///
/// Contexte : l'audit du 31/07 a montre qu'une seule occurrence de `\s`
/// subsiste dans les detecteurs heuristiques (name_detector.dart ligne 252) :
///
///     final words = entity.value.trim().split(RegExp(r'\s+'));
///
/// Elle decoupe une valeur DEJA detectee. Depuis que le span de nom ne peut
/// plus contenir de saut de ligne, `\s+` y est equivalent a `[ \t]+` — donc
/// inoffensive AUJOURD'HUI.
///
/// Le risque est l'evolution : le span d'adresse, lui, contient un `\n`
/// depuis le correctif du meme jour. Si ce decoupage venait a traiter un
/// autre type d'entite, le comportement changerait silencieusement.
///
/// Ces tests figent le comportement attendu pour que le changement ne passe
/// pas inapercu. Ils doivent etre VERTS avant comme apres le remplacement de
/// `\s+` par `[ \t]+` — c'est precisement leur role : prouver que la
/// correction est sans effet de bord.
void main() {
  Future<void> expectRoundTrip(String original) async {
    final r = await Ecluse.redact(original);
    expect(Ecluse.restore(r.maskedText, r.mapping), equals(original),
        reason: 'La restauration doit etre byte-exacte');
  }

  group('decoupage interne du detecteur de noms', () {
    test('espaces multiples entre prenom et patronyme', () async {
      const texte = 'Madame Nathalie   Reynaud a signe le devis.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Reynaud')));
      await expectRoundTrip(texte);
    });

    test('tabulation entre prenom et patronyme', () async {
      const texte = 'Monsieur Marc\tChevrier preside la seance.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Chevrier')));
      await expectRoundTrip(texte);
    });

    test('espace insecable entre prenom et patronyme', () async {
      // NBSP (U+00A0) : frequent dans les documents issus de traitements
      // de texte. Comportement a constater, pas necessairement a garantir.
      const texte = 'Madame Sophie\u00A0Aubry a valide le compte rendu.';
      await expectRoundTrip(texte);
    });

    test('le nom en fin de document sans ponctuation finale', () async {
      const texte = 'Referent : Monsieur Antoine Vasseur';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Vasseur')));
      await expectRoundTrip(texte);
    });

    test('deux noms separes par une virgule sur la meme ligne', () async {
      const texte = 'Presents : Madame Laure Perrot, Monsieur Julien Aubry.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Perrot')));
      expect(r.maskedText, isNot(contains('Aubry')));
      await expectRoundTrip(texte);
    });
  });
}
