import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Noms aux accents décomposés (NFD : lettre + diacritique combinant), forme
/// courante des noms de fichiers macOS et de certains copier-coller de PDF
/// (P2-32). Avant ce correctif, « Élodie » écrit E + U+0301 était coupé après le
/// « E » : le reste du nom restait en clair dans le texte envoyé.
const _cas = <String, String>{
  'accent aigu sur la majuscule initiale': 'Mme Élodie Dupont',
  'accent grave dans le patronyme': 'Mme Sophie Lefèvre',
  'cédille': 'M. François Dupont',
  'tréma': 'Mme Zoë Martin',
  'accent sur la dernière lettre': 'M. Jean Dupré',
  'plusieurs accents': 'Mme Élodie Lefèvre-Rémy',
};

void main() {
  for (final MapEntry(key: nom, value: personne) in _cas.entries) {
    test(nom, () async {
      final t = 'Rendez-vous avec $personne demain.';
      final r = await Ecluse.redact(t);
      expect(r.maskedText,
          matches(RegExp(r'^Rendez-vous avec (Mme |M\. )\[NOM_1\] demain\.$')),
          reason: 'nom coupé : "${r.maskedText}"');
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
      final es = await Ecluse.detect(t);
      for (final e in es) {
        expect(t.substring(e.start, e.end), e.value);
      }
    });
  }

  test('la forme composée (NFC) est détectée comme avant', () async {
    const t = 'Rendez-vous avec Mme Élodie Lefèvre demain.';
    final r = await Ecluse.redact(t);
    expect(r.maskedText, 'Rendez-vous avec Mme [NOM_1] demain.');
  });

  test('un diacritique combinant hors nom ne crée aucune entité', () async {
    const t = 'Le résultat est arrivé hier.';
    final r = await Ecluse.redact(t);
    expect(r.maskedText, t);
    expect(r.mapping, isEmpty);
  });
}
