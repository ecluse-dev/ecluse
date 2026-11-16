import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// `EtablissementDetector` : mot-clé à une frontière de mot, étendue limitée au
/// nom (P2-207).
///
/// Deux défauts relevés par `agent/specs/P2-205.md` § E sur le balayage des
/// communes en capitales sans CEDEX (`Ecluse.redact`) :
///
/// 1. `\b` ne connaît pas les lettres accentuées : « CH » est trouvé au
///    milieu de « BUËCH » (« Ë » n'est pas un caractère de mot pour `\b`), et
///    « VAL BUË » restait en clair ;
/// 2. le recollage d'une fin de ligne derrière un mot-clé
///    (`coupures_de_nom.dart`, cas 3) ne connaît les débuts de phrase qu'en
///    casse de titre : « MERCI » en capitales passait pour la suite du nom, et
///    la ligne suivante entière était masquée avec lui.
///
/// Toutes les valeurs sont synthétiques ou des noms du référentiel public.
void main() {
  const detector = EtablissementDetector();

  group('mot-clé à une frontière de mot, accents compris', () {
    for (final t in [
      'VAL BUËCH MÉOUGE',
      '05140 VAL BUËCH MÉOUGE',
      'Le Buëch Moyen',
      'ÉCH Bleu', // « CH » derrière une lettre accentuée majuscule
      'Bâmas Rouge', // « mas » derrière une lettre accentuée minuscule
    ]) {
      test('aucun établissement dans « $t »', () {
        expect(detector.detect(t), isEmpty);
      });
    }

    test('un vrai mot-clé en tête, après une apostrophe ou une ponctuation',
        () {
      expect(
          detector.detect('L\'IME Beauséjour.').single.value, 'IME Beauséjour');
      expect(detector.detect('Vu : CH Vesoul').single.value, 'CH Vesoul');
      expect(detector.detect('« MAS Grenier »').single.value, 'MAS Grenier');
    });
  });

  group('Ecluse.redact : « VAL BUËCH MÉOUGE »', () {
    test('rien de la commune ne reste en clair, la ligne suivante non plus',
        () async {
      const t =
          'COURRIER À ADRESSER À :\n05140 VAL BUËCH MÉOUGE\nMERCI DE VOTRE RETOUR.';
      final r = await Ecluse.redact(t);
      for (final reste in ['VAL', 'BUË', 'MÉOUGE', '05140']) {
        expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      }
      expect(r.maskedText, contains('MERCI DE VOTRE RETOUR.'));
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });
  });

  group('étendue limitée au nom, fin de ligne en capitales', () {
    const ouvertures = [
      'MERCI DE VOTRE RETOUR.',
      'BONJOUR A TOUS.',
      'CORDIALEMENT.',
      'IL EST PARTI.',
      'POUR INFORMATION.',
    ];
    for (final suite in ouvertures) {
      test('« MAS GRENIER⏎$suite » : la ligne suivante reste lisible',
          () async {
        final t = 'COURRIER À ADRESSER À :\n82110 MAS GRENIER\n$suite';
        final r = await Ecluse.redact(t);
        expect(r.maskedText, contains(suite), reason: r.maskedText);
        expect(r.maskedText, isNot(contains('GRENIER')));
        expect(Ecluse.restore(r.maskedText, r.mapping), t);
      });
    }

    test('un nom coupé en capitales est toujours recollé', () async {
      const t = 'Suivi à l\'EHPAD\nBELLEVUE depuis mars.';
      final r = await Ecluse.redact(t);
      expect(r.maskedText, isNot(contains('BELLEVUE')), reason: r.maskedText);
      expect(r.maskedText, contains('depuis mars.'));
    });

    test('la casse de titre garde son comportement', () async {
      const t = 'Suivi à la Résidence\nBellevue depuis mars.';
      final r = await Ecluse.redact(t);
      expect(r.maskedText, isNot(contains('Bellevue')), reason: r.maskedText);
      const u = 'Suivi à la Résidence Bellevue\nMerci de votre retour.';
      final s = await Ecluse.redact(u);
      expect(s.maskedText, contains('Merci de votre retour.'));
    });
  });
}
