import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Noms réalistes qui restaient en clair (relecture d'octobre 2026, P1-24).
/// Le test vérifie que chaque fragment sensible est **couvert** par une
/// entité `nom` ; la forme exacte du span (civilité ou non) est une
/// décision de `NameDetector`, testée ailleurs.
void main() {
  const d = NameDetector();

  void couvre(String texte, List<String> sensibles) {
    final entities = d.detect(texte);
    for (final s in sensibles) {
      final start = texte.indexOf(s);
      expect(start, isNonNegative, reason: 'fragment "$s" absent de "$texte"');
      final end = start + s.length;
      final couvert =
          entities.any((DetectedEntity e) => e.start <= start && e.end >= end);
      expect(couvert, isTrue,
          reason: '"$s" resté en clair dans "$texte" '
              '(entités : ${entities.map((e) => e.value).toList()})');
    }
  }

  group('prénoms accentués (gazetteer sans accents)', () {
    const cas = {
      'Stéphane Durand a appelé.': ['Stéphane', 'Durand'],
      'Amélie Dupont et Cécile Moreau.': ['Amélie Dupont', 'Cécile Moreau'],
      'Agnès Petit est venue.': ['Agnès', 'Petit'],
      'Kévin Moreau part demain.': ['Kévin', 'Moreau'],
      'Éric Zola arrive.': ['Éric', 'Zola'],
      'Hélène est venue.': ['Hélène'],
      'Jérôme est venu.': ['Jérôme'],
    };
    cas.forEach((texte, sensibles) {
      test(texte, () => couvre(texte, sensibles));
    });
  });

  group('civilités supplémentaires', () {
    const cas = {
      'Maître Dupont plaide.': ['Dupont'],
      'Mrs Dupont est là.': ['Dupont'],
      'Mr Pierre Dubois est là.': ['Pierre Dubois'],
      'Mlle Claire Martin est là.': ['Claire Martin'],
    };
    cas.forEach((texte, sensibles) {
      test(texte, () => couvre(texte, sensibles));
    });
  });

  group('particules et apostrophes', () {
    const cas = {
      'Mme Anne-Sophie de la Fontaine est là.': ['Anne-Sophie de la Fontaine'],
      'Madame de la Tour est là.': ['de la Tour'],
      "Mme Claire d'Angelo est là.": ["Claire d'Angelo"],
      'Mme Marie O’Connor est là.': ['Marie O’Connor'],
      'Pierre de la Fontaine est là.': ['Pierre de la Fontaine'],
      'Pierre de Montmorency est là.': ['Pierre de Montmorency'],
      'Pierre Van Der Berg est là.': ['Pierre Van Der Berg'],
      'Sophie Le Gall est là.': ['Sophie Le Gall'],
    };
    cas.forEach((texte, sensibles) {
      test(texte, () => couvre(texte, sensibles));
    });
  });

  group('espaces insécables', () {
    test('prénom + nom séparés par une espace insécable', () {
      couvre('Pierre Dupont est là.', ['Pierre Dupont']);
    });
    test('civilité + nom séparés par une espace insécable', () {
      couvre('M. Jean Dupont est là.', ['Jean Dupont']);
    });
  });

  group('rejets : pas de sur-masquage', () {
    test('mot capitalisé de début de phrase sans prénom', () {
      expect(d.detect('Le Mans est une ville.'), isEmpty);
    });
    test('particule seule', () {
      expect(d.detect('Il parle de la ville.'), isEmpty);
    });
    test('prénom suivi de texte courant ne prend pas le mot suivant', () {
      final entities = d.detect('Pierre est parti hier.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Pierre');
    });
  });
}
