import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Préfixes de téléphone français hors forme courante (P2-44) : « (+33) » entre
/// parenthèses, et les indicatifs des départements d'outre-mer (+262, +590,
/// +594, +596), qui sont des numéros français. Les numéros étrangers restent
/// hors périmètre (documenté).
void main() {
  const masques = {
    'Tél : (+33) 6 12 34 56 78': 'TELEPHONE',
    'Tél : (+33)612345678': 'TELEPHONE',
    'Tél : (+33) (0)6 12 34 56 78': 'TELEPHONE',
    'Tél : +262 692 12 34 56': 'TELEPHONE',
    'Tél : +262692123456': 'TELEPHONE',
    'Tél : +590 690 12 34 56': 'TELEPHONE',
    'Tél : +594 694 12 34 56': 'TELEPHONE',
    'Tél : +596 696 12 34 56': 'TELEPHONE',
    'Tél : +262 (0)692 12 34 56': 'TELEPHONE',
    'Tél : +262.692.12.34.56': 'TELEPHONE',
  };
  for (final MapEntry(key: texte, value: type) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, 'Tél : [${type}_1]', reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'Réf. +262 692 12 34',
    'Code +262 69',
    'Total : (+33) 6 12 34',
    'Montant +590 690 12 34 567',
  ];
  for (final texte in intacts) {
    test('aucun téléphone : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }
}
