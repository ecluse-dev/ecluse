import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('bandForF', () {
    test('9.99 -> eleve', () => expect(bandForF(9.99), RiskBand.eleve));
    test('10 -> moyen', () => expect(bandForF(10), RiskBand.moyen));
    test('49.99 -> moyen', () => expect(bandForF(49.99), RiskBand.moyen));
    test('50 -> faible', () => expect(bandForF(50), RiskBand.faible));
  });

  test('seuils nommés', () {
    expect(thresholdStandard, 10);
    expect(thresholdRenforce, 20);
    expect(thresholdStrict, 50);
  });
}
