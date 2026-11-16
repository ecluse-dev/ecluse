import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_redact/src/heuristics/communes_nom_exact.dart';
import 'package:ecluse_redact/src/heuristics/mots_neutres.dart';
import 'package:test/test.dart';

/// Communes en capitales **sans « CEDEX »** : règle « nom exact du
/// référentiel » (P2-214, décision du 16 novembre, `DECISIONS.md`). Le
/// balayage de P2-206 laissait 309 adresses sur 139 500 en partie en clair,
/// en quatre formes ; un cas par forme ici. La forme B (mot neutre en tête)
/// est laissée de côté par la même décision.
///
/// Noms de communes publics du référentiel versionné, codes postaux
/// fabriqués, aucune donnée réelle.
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
      // Forme A : cinq mots ou plus.
      '02213 DHUYS ET MORIN EN BRIE',
      '02411 FLAVIGNY LE GRAND ET BEAURAIN',
      '70621 VILLERS CHEMIN ET MONT LES ETRELLES',
      '26123 LA ROCHE SUR LE BUIS',
      // Forme C : parenthèse, tiret isolé, blancs multiples.
      '58120 CHATEAU CHINON (VILLE)',
      '58120 CHÂTEAU-CHINON (VILLE)',
      '64350 CASTILLON (CANTON DE LEMBEYE)',
      '12345 SARROUX - SAINT JULIEN',
      '12345 SAINT PATERNE   LE CHEVAIN',
      // Forme D : déterminant puis mot neutre.
      '12345 LES PLACES',
    ];
    for (final ligne in lignes) {
      test(ligne, () async {
        expect(await masque(ligne), '[ADRESSE_1]');
      });
    }

    test('le nom s\'arrête à sa fin : la suite de la ligne reste lisible',
        () async {
      expect(await masque('02213 DHUYS ET MORIN EN BRIE, BATIMENT B'),
          '[ADRESSE_1], BATIMENT B');
    });
  });

  group('inchangé', () {
    const lignes = {
      // Forme B, laissée de côté : mot neutre en tête, la règle P2-122 reste.
      '46090 VERS': '46090 VERS',
      '09230 SOUS PARSAT': '09230 SOUS PARSAT',
      '70000 EUROS HORS TAXES': '70000 EUROS HORS TAXES',
      // Texte ordinaire derrière une commune : pas un nom du référentiel.
      '70000 VESOUL - SERVICE DES ADMISSIONS':
          '[ADRESSE_1] - SERVICE DES ADMISSIONS',
      '70000 VESOUL (VOIR PAGE 3)': '[ADRESSE_1] (VOIR PAGE 3)',
      // Un début de nom long sans sa fin n'est pas un nom exact.
      '02213 DHUYS ET MORIN EN ATTENTE': '[ADRESSE_1] ATTENTE',
      // Déterminant puis mot neutre qui n'est pas « LES PLACES ».
      '70000 LES DOSSIERS': '70000 LES DOSSIERS',
    };
    for (final MapEntry(key: ligne, value: attendu) in lignes.entries) {
      test(ligne, () async {
        expect(await masque(ligne), attendu);
      });
    }

    test('casse ordinaire : la règle ne vaut que pour un texte en capitales',
        () async {
      const texte = 'Total : 12345 Les Places restantes sont à réserver.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte);
    });
  });

  test('coût connu : « LES PLACES » en tête d\'une phrase en capitales',
      () async {
    // Seul nom de la table qui se lit aussi comme du texte ordinaire.
    // Masquage en trop assumé (`LIMITES.md`), pas une fuite.
    expect(await masque('70000 LES PLACES RESTANTES'), '[ADRESSE_1] RESTANTES');
  });

  group('table embarquée', () {
    test('identique à ce que donne le référentiel versionné', () {
      // Même sélection que `tools/build_communes_nom_exact.py` : si le
      // référentiel ou `mots_neutres.dart` change, ce test dit de régénérer.
      final octets = File('../ecluse_reference/assets/geo_communes.csv.gz')
          .readAsBytesSync();
      final lignes = const LineSplitter()
          .convert(utf8.decode(gzip.decode(octets)))
          .skip(1);
      const determinants = {'le', 'la', 'les', 'l'};
      final attendus = <String>{};
      for (final ligne in lignes) {
        final champs = ligne.split(';');
        if (champs.length < 6 || champs[4].isEmpty) continue;
        final cle = champs[4]
            .replaceAll(RegExp('[^A-Z0-9]+'), ' ')
            .trim()
            .replaceAll(RegExp(' +'), ' ');
        final mots = cle.toLowerCase().split(' ');
        final premierNeutre = motsNeutres.contains(mots[0]);
        final determinant = determinants.contains(mots[0]);
        if (premierNeutre && !determinant) continue; // forme B
        final libelle = champs[5];
        final d =
            determinant && mots.length > 1 && motsNeutres.contains(mots[1]);
        final c = libelle.contains('(') ||
            libelle.contains(' - ') ||
            libelle.contains('  ');
        if (d || c || mots.length >= 5) attendus.add(cle);
      }
      expect(communesNomExact, attendus,
          reason: 'relancer tools/build_communes_nom_exact.py');
      expect(
          communesNomExactMotsMax,
          attendus
              .map((n) => n.split(' ').length)
              .reduce((a, b) => a > b ? a : b));
    });

    test('aucun nom de la forme B', () {
      for (final nom in communesNomExact) {
        final premier = nom.split(' ').first.toLowerCase();
        expect(
            motsNeutres.contains(premier) &&
                !{'le', 'la', 'les', 'l'}.contains(premier),
            isFalse,
            reason: nom);
      }
    });
  });
}
