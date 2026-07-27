import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

void main() {
  group('normName — parité obligatoire avec build_reference_assets.py', () {
    test("L'Abergement-Clémenciat -> L ABERGEMENT CLEMENCIAT", () {
      expect(normName("L'Abergement-Clémenciat"), 'L ABERGEMENT CLEMENCIAT');
    });

    test('Hélène -> HELENE', () {
      expect(normName('Hélène'), 'HELENE');
    });
  });
}
