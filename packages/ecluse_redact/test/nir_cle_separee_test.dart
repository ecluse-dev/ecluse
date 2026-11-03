import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Clé du NIR nommée à part (P2-42) : « 2550814168025 clé 38 ». Le détecteur
/// attend la clé collée au numéro ; avec le mot « clé » entre les deux, les 13
/// chiffres restaient en clair. Le mot est neutralisé dans la vue de détection
/// seulement : la validation de la clé reste celle du détecteur existant, donc
/// une clé fausse n'est jamais acceptée.
void main() {
  const valides = [
    'NIR : 2550814168025 clé 38.',
    'NIR : 2 55 08 14 168 025 clé 38.',
    'NIR : 2550814168025 (clé 38)',
    'NIR : 2550814168025 Clé : 38',
    'NIR : 2550814168025 CLÉ 38',
    'NIR : 2550814168025 cle 38',
    'NIR : 2550814168025 clef 38',
    'NIR : 185122A004123 clé 71.',
    'NIR : 280012B004123 clé 20.',
    'NIR : 1850397100123 clé 82.',
  ];
  for (final texte in valides) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, contains('[NIR_1]'), reason: r.maskedText);
      expect(r.maskedText, isNot(contains(RegExp(r'\d{6}'))),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'NIR : 2550814168025 clé 39',
    'NIR : 2550814168025 clé 3',
    'Chambre 12 clé 38 remise',
    'Page 1850397100123 clé 99',
  ];
  for (final texte in intacts) {
    test('aucun NIR : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, isNot(contains('[NIR_1]')), reason: r.maskedText);
    });
  }
}
