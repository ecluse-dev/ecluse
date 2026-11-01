import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Un chiffre suivi d'une longue suite de blancs rendait le détecteur
/// d'adresse quadratique (P2-85) : deux `[ \t]*` séparés par une virgule
/// facultative se répartissaient les blancs de toutes les façons possibles.
void main() {
  for (final blanc in [' ', '\t']) {
    test(
        'chiffre + 20 000 blancs (${blanc == ' ' ? 'espaces' : 'tabulations'}) '
        'en moins de 3 s', () async {
      final sw = Stopwatch()..start();
      final r = await Ecluse.redact('1${blanc * 20000}');
      expect(sw.elapsedMilliseconds, lessThan(3000));
      expect(Ecluse.restore(r.maskedText, r.mapping), '1${blanc * 20000}');
    });
  }

  test('chiffre + « clé » + 20 000 blancs en moins de 3 s', () async {
    final texte = '1 clé${' ' * 20000}';
    final sw = Stopwatch()..start();
    final r = await Ecluse.redact(texte);
    expect(sw.elapsedMilliseconds, lessThan(3000));
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('suite de 100 000 minuscules suivie d\'un point en moins de 3 s',
      () async {
    final texte = '${'a' * 100000}.';
    final sw = Stopwatch()..start();
    final r = await Ecluse.redact(texte);
    expect(sw.elapsedMilliseconds, lessThan(3000));
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('les points entre mots capitalisés restent des séparateurs', () async {
    for (final t in [
      'Bilan.Pierre.Dupont.pdf',
      'Pierre.Dupont.pdf',
      'envoyé à Jean.Zxqvlorn demain',
    ]) {
      final r = await Ecluse.redact(t);
      expect(r.maskedText, isNot(contains('Dupont')), reason: t);
      expect(r.maskedText, isNot(contains('Zxqvlorn')), reason: t);
    }
  });

  test('les adresses avec virgule et espaces multiples restent masquées',
      () async {
    for (final t in [
      '12, rue des Lilas, 75015 Paris',
      '12 ,  rue des Lilas, 75015 Paris',
      '12   rue des Lilas, 75015 Paris',
      '12 bis rue des Lilas 75015 Paris',
    ]) {
      final r = await Ecluse.redact(t);
      expect(r.maskedText, isNot(contains('Lilas')), reason: t);
    }
  });
}
