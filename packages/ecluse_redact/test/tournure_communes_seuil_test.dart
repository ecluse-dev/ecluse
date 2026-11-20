import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Seuil des communes écartées derrière « à la demande de » (P2-239, décision
/// du 20 novembre). Jusqu'ici toute commune de 10 000 habitants et plus y était
/// lue comme un lieu : les patronymes qui sont aussi une telle commune
/// (« Gaillard », « Thiers », « Laval ») restaient en clair (24 fuites sur 96 au
/// témoin de P2-226). Désormais seules les communes de 100 000 habitants et plus
/// (et celles sans population dans le référentiel : Paris, Lyon, Marseille) sont
/// écartées. Coût assumé et écrit dans `LIMITES.md` : « à la demande de Vesoul »
/// est masqué (60 sur 60 villes de 10 000 à 100 000 habitants au témoin de
/// P2-238).
///
/// Noms de communes publiques (référentiel INSEE), aucune donnée réelle.
void main() {
  const masques = <String, String>{
    // Communes de 10 000 à 100 000 habitants : lues comme un patronyme.
    'Rendez-vous reporté à la demande de Gaillard ; date à proposer.':
        'Gaillard',
    'Rendez-vous reporté à la demande de Thiers ; date à proposer.': 'Thiers',
    'Rendez-vous reporté à la demande de Laval ; date à proposer.': 'Laval',
    'Rendez-vous reporté à la demande de Vesoul ; date à proposer.': 'Vesoul',
  };
  for (final MapEntry(key: texte, value: nom) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(nom)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = <String, String>{
    // 100 000 habitants et plus.
    'Rendez-vous reporté à la demande de Toulouse ; date à proposer.':
        'Toulouse',
    'Rendez-vous reporté à la demande de Bordeaux ; date à proposer.':
        'Bordeaux',
    'Rendez-vous reporté à la demande de Besançon ; date à proposer.':
        'Besançon',
    // Population absente du référentiel (arrondissements).
    'Rendez-vous reporté à la demande de Paris ; date à proposer.': 'Paris',
    'Rendez-vous reporté à la demande de Lyon ; date à proposer.': 'Lyon',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('les autres tournures ne dépendent pas du seuil', () async {
    for (final nom in ['Gaillard', 'Toulouse', 'Paris']) {
      final r = await Ecluse.redact('Pièces jointes au dossier de $nom.');
      expect(r.maskedText, isNot(contains(nom)), reason: r.maskedText);
    }
  });
}
