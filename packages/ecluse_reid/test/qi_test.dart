import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

void main() {
  group('Qi', () {
    test('level par défaut == 0', () {
      const qi = Qi(QiType.age, '89');
      expect(qi.level, 0);
    });

    test('égalité de valeur pour deux Qi construits avec les mêmes arguments',
        () {
      const a = Qi(QiType.lieu, '57001', level: 1);
      const b = Qi(QiType.lieu, '57001', level: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('inégalité si le niveau diffère', () {
      const a = Qi(QiType.lieu, '57001');
      const b = Qi(QiType.lieu, '57001', level: 1);
      expect(a == b, isFalse);
    });
  });

  test('les valeurs sentinelles sont distinctes', () {
    final sentinels = {
      qiRetraitValue,
      professionToutesSpecialites,
      professionnelDeSante,
      lieuFrance,
    };
    expect(sentinels, hasLength(4));
  });
}
