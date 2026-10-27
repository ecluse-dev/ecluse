import 'dart:math';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// IBAN de l'espace SEPA (P2-62). Les IBAN d'essai sont **générés** : BBAN
/// pseudo-aléatoire de graine fixe, clé de contrôle calculée (ISO 7064 mod 97-10),
/// jamais copiés d'une source réelle.
const _longueurs = {
  'AD': 24, 'AT': 20, 'BE': 16, 'BG': 22, 'CH': 21, 'CY': 28, 'CZ': 24,
  'DE': 22, 'DK': 18, 'EE': 20, 'ES': 24, 'FI': 18, 'FO': 18, 'FR': 27,
  'GB': 22, 'GI': 23, 'GR': 27, 'HR': 21, 'HU': 28, 'IE': 22, 'IS': 26,
  'IT': 27, 'LI': 21, 'LT': 20, 'LU': 20, 'LV': 21, 'MC': 27, 'MT': 31,
  'NL': 18, 'NO': 15, 'PL': 28, 'PT': 25, 'RO': 24, 'SE': 24, 'SI': 19,
  'SK': 24, 'SM': 27, 'VA': 22, //
};

int _mod97(String s) {
  var r = 0;
  for (final u in s.codeUnits) {
    r = u >= 0x41 ? (r * 100 + u - 0x37) % 97 : (r * 10 + u - 0x30) % 97;
  }
  return r;
}

String _iban(String pays, Random rnd, {bool alpha = false}) {
  final n = _longueurs[pays]! - 4;
  final bban = StringBuffer();
  for (var i = 0; i < n; i++) {
    bban.write(
      alpha && i < 4
          ? String.fromCharCode(0x41 + rnd.nextInt(26))
          : rnd.nextInt(10),
    );
  }
  final cle = 98 - _mod97('$bban${pays}00');
  return '$pays${cle.toString().padLeft(2, '0')}$bban';
}

String _groupes(String iban) =>
    RegExp('.{1,4}').allMatches(iban).map((m) => m.group(0)).join(' ');

void main() {
  const detector = IbanDetector();
  final rnd = Random(2026);

  group('IbanDetector — pays de l\'espace SEPA', () {
    for (final pays in _longueurs.keys) {
      test('$pays : compact et groupé par 4', () {
        final iban = _iban(pays, rnd, alpha: pays == 'GB' || pays == 'NL');
        for (final forme in [iban, _groupes(iban)]) {
          final texte = 'Virement vers $forme effectué.';
          final e = detector.detect(texte);
          expect(e, hasLength(1), reason: forme);
          expect(e.single.type, EntityType.iban);
          expect(e.single.confidence, 1.0);
          expect(e.single.value, forme);
          expect(texte.substring(e.single.start, e.single.end), forme);
        }
      });
    }

    test('minuscules et tirets', () {
      final iban = _iban('DE', rnd);
      final forme = iban.toLowerCase();
      expect(detector.detect('iban $forme.'), hasLength(1));
      final tirets =
          RegExp('.{1,4}').allMatches(iban).map((m) => m.group(0)).join('-');
      expect(detector.detect('iban $tirets.'), hasLength(1));
    });
  });

  group('IbanDetector — rejets', () {
    test('clé de contrôle fausse', () {
      final iban = _iban('BE', rnd);
      final faux =
          '${iban.substring(0, 2)}${(int.parse(iban.substring(2, 4)) % 97 + 1).toString().padLeft(2, '0')}${iban.substring(4)}';
      expect(detector.detect(faux), isEmpty);
    });

    test('longueur incorrecte pour le pays', () {
      final iban = _iban('BE', rnd);
      expect(detector.detect('${iban}1'), isEmpty);
      expect(detector.detect(iban.substring(0, iban.length - 1)), isEmpty);
    });

    test('pays hors espace SEPA (États-Unis)', () {
      expect(detector.detect('US64SVBKUS6S3300958879'), isEmpty);
    });

    test('enchâssé dans une suite alphanumérique', () {
      final iban = _iban('ES', rnd);
      expect(detector.detect('X$iban'), isEmpty);
      expect(detector.detect('${iban}X'), isEmpty);
    });

    test('mot de deux lettres suivi de chiffres sans clé valide', () {
      expect(detector.detect('Réf DE12 3456 7890 1234 5678 90'), isEmpty);
    });
  });
}
