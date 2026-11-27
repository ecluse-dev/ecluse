import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// P2-305 : `NirCleInvalideDetector.ecartesCoupures` rend les bornes des NIR à
/// clé fausse que la garde `nir_coupures` écarte (jamais la valeur). Valeurs
/// synthétiques : corps 2 85 05 78 006 084 (clé juste 41, on met 46).
void main() {
  const detecteur = NirCleInvalideDetector();
  const parQuatre = '2850 5780 0608 446';

  test('groupes de quatre, clé fausse : écarté, bornes exactes, rien masqué',
      () {
    const texte = 'Réf. $parQuatre notée.';
    final e = detecteur.ecartesCoupures(texte);
    expect(e, hasLength(1));
    expect(texte.substring(e.single.start, e.single.end), parQuatre);
    expect(detecteur.detect(texte), isEmpty);
    expect(detecteur.ecartes(texte), isEmpty);
  });

  test('groupes d\'un NIR ou cinq groupes de trois : rien d\'écarté', () {
    for (final nir in ['2 85 05 78 006 084 46', '285.057.800.608.446']) {
      expect(detecteur.ecartesCoupures('Réf. $nir notée.'), isEmpty,
          reason: nir);
    }
  });

  test('clé juste (NirDetector décide) : rien d\'écarté', () {
    expect(
        detecteur.ecartesCoupures('Réf. 2850 5780 0608 441 notée.'), isEmpty);
  });

  test('coupures libres : la garde ne s\'applique pas, rien d\'écarté', () {
    const libres = NirCleInvalideDetector(coupuresLibres: true);
    expect(libres.ecartesCoupures('Réf. $parQuatre notée.'), isEmpty);
  });
}
