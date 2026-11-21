import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Communes en capitales sans « CEDEX », écrites **hors de la forme du
/// référentiel** (P2-244, option 1 de `agent/specs/P2-215.md`, décision du
/// 21 novembre) : « ST » et « STE » lus « SAINT » et « SAINTE », puis noms
/// comparés collés (apostrophe ou tiret perdu sans espace). Table réduite
/// seulement : pas de distance d'édition (option 2 reportée).
///
/// Noms de communes publics du référentiel, codes postaux fabriqués.
void main() {
  const avant = 'COURRIER À ADRESSER À :\n';
  const apres = '\nMERCI DE VOTRE RETOUR.';

  Future<String> masque(String ligne) async {
    final texte = '$avant$ligne$apres';
    final r = await Ecluse.redact(texte);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    expect(r.maskedText, startsWith(avant), reason: r.maskedText);
    expect(r.maskedText, endsWith(apres), reason: r.maskedText);
    return r.maskedText
        .substring(avant.length, r.maskedText.length - apres.length);
  }

  group('masquée en entier', () {
    const lignes = [
      // « ST » pour « SAINT ».
      '12345 LA CHAPELLE ST MARTIN EN PLAINE',
      '12345 COISE ST JEAN PIED GAUTHIER',
      '12345 BONNEVILLE ET ST AVIT DE FUMADIERES',
      '02087 ST ERME OUTRE ET RAMECOURT',
      '08139 ST LAMBERT ET MONT DE JEUX',
      '07236 ST LAURENT LES BAINS LAVAL D AURELLE',
      // Apostrophe perdue, mots collés.
      '07676 SAINT LAURENT LES BAINS LAVAL DAURELLE',
      '12913 SAINT GENIEZ D OLT ET DAUBRAC',
      '27459 VERNEUIL DAVRE ET D ITON',
      '12345 CASTILLON CANTON DARTHEZ DE BEARN',
      // Les deux à la fois.
      '12345 CHENAC ST SEURIN DUZET',
      // Tiret perdu, mots collés.
      '58120 CHATEAUCHINON (VILLE)',
      '02902 LA VILLE AUXBOIS LES DIZY',
      '02892 LA VILLE AUX BOISLES PONTAVERT',
      '07697 SAINTLAURENT LES BAINS LAVAL D AURELLE',
      '12345 SARROUX-SAINT JULIEN',
      // Forme du référentiel : toujours couverte.
      '12345 LA CHAPELLE SAINT MARTIN EN PLAINE',
      '12345 CHENAC SAINT SEURIN D UZET',
    ];
    for (final ligne in lignes) {
      test(ligne, () async {
        expect(await masque(ligne), '[ADRESSE_1]');
      });
    }

    test('le nom s\'arrête à sa fin : la suite de la ligne reste lisible',
        () async {
      expect(await masque('12345 LA CHAPELLE ST MARTIN EN PLAINE, BATIMENT B'),
          '[ADRESSE_1], BATIMENT B');
    });
  });

  group('inchangé', () {
    const lignes = {
      // Texte ordinaire derrière une commune : pas un nom du référentiel.
      '70000 VESOUL - SERVICE DES ADMISSIONS':
          '[ADRESSE_1] - SERVICE DES ADMISSIONS',
      // Un début de nom long sans sa fin n'est pas un nom, avec ou sans « ST ».
      '12345 LA CHAPELLE ST MARTIN EN ATTENTE': '[ADRESSE_1] EN ATTENTE',
      // Mot neutre en tête : la règle de la forme B reste.
      '70000 EUROS HORS TAXES': '70000 EUROS HORS TAXES',
    };
    for (final MapEntry(key: ligne, value: attendu) in lignes.entries) {
      test(ligne, () async {
        expect(await masque(ligne), attendu);
      });
    }

    test('texte avec minuscules : la règle ne s\'applique pas (comme avant)',
        () async {
      final sans = await Ecluse.redact(
          'Courrier : 12345 La Chapelle St Martin en Plaine, bâtiment B.');
      // Hors capitales, le motif seul décide ; on ne fige que l'absence de
      // changement par rapport au nom exact : aucun jeton de plus qu'une
      // adresse.
      expect('[ADRESSE_'.allMatches(sans.maskedText).length, lessThan(2));
    });
  });
}
