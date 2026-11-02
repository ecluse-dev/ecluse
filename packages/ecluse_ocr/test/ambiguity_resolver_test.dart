import 'package:ecluse_ocr/ecluse_ocr.dart';
import 'package:test/test.dart';

void main() {
  const resolver = AmbiguityResolver();

  group('AmbiguityResolver', () {
    test('inclut la string originale dans les variantes', () {
      final variants = resolver.variantsOf('ABC');
      expect(variants, contains('ABC'));
    });

    test('substitution simple O↔0 aller-retour', () {
      final variants = resolver.variantsOf('O');
      expect(variants, containsAll(['O', '0']));
    });

    test('ne produit rien pour une string sans caractère ambigu', () {
      final variants = resolver.variantsOf('xyz');
      expect(variants, {'xyz'});
    });

    test('substitutions multi-caractères se combinent', () {
      final variants = resolver.variantsOf('OI');
      // Attend au moins : OI, 0I, Ol, O1, 0l, 01, ...
      expect(variants, contains('OI'));
      expect(variants, contains('01'));
    });

    test('borne dure sur maxVariants', () {
      const bounded = AmbiguityResolver(maxVariants: 5);
      final variants = bounded.variantsOf('OOOOOOOO');
      expect(variants.length, lessThanOrEqualTo(5));
    });

    test('digrammes rn↔m détectés', () {
      final variants = resolver.variantsOf('rn');
      expect(variants, contains('m'));
    });

    test('diffChars produit le trace attendu', () {
      final d = AmbiguityResolver.diffChars('O1234', '01234');
      expect(d, hasLength(1));
      expect(d.first.from, 'O');
      expect(d.first.to, '0');
      expect(d.first.index, 0);
    });

    test('vide retourne singleton vide', () {
      expect(resolver.variantsOf(''), {''});
    });
  });
}
