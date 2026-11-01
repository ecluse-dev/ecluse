import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Variantes de contexte d'une date de naissance (P2-76) : « DN », « D.N. »,
/// « Date nais. », « née 12/9/1938 » (sans « le »), « n. le », « âge : 87 ans
/// (12/09/1938) ». La date complète de naissance restait en clair.
void main() {
  const masques = {
    'Mme Quenelle - DN 12.09.1938': '12.09.1938',
    'DN : 12/09/1938': '12/09/1938',
    'D.N. : 12/09/1938': '12/09/1938',
    'Date nais. 12/09/1938': '12/09/1938',
    'Date nais : 12/09/1938': '12/09/1938',
    'Mme Quenelle née 12/9/1938': '12/9/1938',
    'M. Quenelle né 12/09/1938 à Lyon': '12/09/1938',
    'Mme Quenelle n. le 12 sept. 1938': '12 sept. 1938',
    'née à Lyon 12/09/1938': '12/09/1938',
    'âge : 87 ans (12/09/1938)': '12/09/1938',
    'Âgée de 87 ans (12/09/1938)': '12/09/1938',
    '87 ans (née le 12/09/1938)': '12/09/1938',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, contains('[DATE_NAISSANCE_'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'DN 12': 'DN 12',
    'Rendez-vous le 12/09/2026': '12/09/2026',
    'Visite du 12.09.2026 à 14h': '12.09.2026',
    'Né 3 fois de suite': 'Né 3',
    'née en France': 'France',
    'Le plan DN 2 est prêt': 'DN 2',
    'Date nais. inconnue': 'inconnue',
    '87 ans le 12/09/2026': '12/09/2026',
    'âge : 87 ans': '87 ans',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('[DATE_NAISSANCE_')),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
