import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Commune de cinq mots ou plus et mots de liaison, **devant « CEDEX »**
/// (P2-181, tâche B de `agent/specs/P2-178.md` § 7).
///
/// Le motif de commune accepte un mot puis trois au plus : en écriture
/// postale (capitales, espaces) une commune de cinq mots laissait sa fin en
/// clair, et « CEDEX » et son numéro avec elle. Allonger le nom accepté
/// masquerait davantage le texte qui suit une commune (témoin
/// `bench/generate_corpus_commune_suivie.py`). La borne retenue ne dépend pas
/// d'une longueur : **ce qui sépare un code postal du mot « CEDEX », sur la
/// même ligne, est la localité**. Sans « CEDEX » derrière, rien ne change.
void main() {
  const casRouges = [
    // Longueur, écriture postale (exemples de `agent/specs/P2-178.md` § 5).
    '38590 SAINT MICHEL SAINT GEOIRS LE HAUT CEDEX 8',
    '07590 SAINT LAURENT LES BAINS LAVAL D AURELLE CEDEX 8',
    // Mot de liaison absent de la liste courante.
    '40660 Moliets et Maa CEDEX 3',
    '54700 Norroy lès Pont à Mousson Cedex 02',
    '70000 Fontenois lès Montbozon et Autres Lieux Voisins CEDEX 5',
  ];
  for (final texte in casRouges) {
    test('commune masquée en entier devant CEDEX : $texte', () async {
      final r = await Ecluse.redact('Courrier à adresser à :\n$texte\nMerci.');
      expect(r.maskedText, 'Courrier à adresser à :\n[ADRESSE_1]\nMerci.',
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), contains('\n$texte\n'));
    });
  }

  // Déjà masquée en entier avant P2-181 (ligne en capitales dont les mots
  // outils « DE », « LA », « DU » sont lus comme des liaisons) : le reste.
  test('déjà couverte, le reste : virgule devant CEDEX', () async {
    const texte = '42260 SAINT MARTIN DE LA PORTE DU BOIS, CEDEX 4';
    final r = await Ecluse.redact('Dépôt :\n$texte\nMerci.');
    expect(r.maskedText, 'Dépôt :\n[ADRESSE_1]\nMerci.');
  });

  // Sans « CEDEX » derrière, la sortie est celle d'avant P2-181 : le témoin
  // de sur-masquage ne doit pas bouger.
  const inchanges = {
    '25000 BESANÇON ET ENVIRONS DU GRAND EST': '[ADRESSE_1] GRAND EST',
    '70000 Vesoul et Besançon': '[ADRESSE_1] et Besançon',
    '70000 Vesoul à 9 h': '[ADRESSE_1] à 9 h',
    '07590 SAINT LAURENT LES BAINS LAVAL D AURELLE':
        '[ADRESSE_1] LAVAL D AURELLE',
    '70000 VESOUL SERVICE DES ADMISSIONS BATIMENT B': '[ADRESSE_1] BATIMENT B',
    // « CEDEX » sur la ligne suivante, ou après un mot en minuscules hors
    // liste : le nom n'est pas prolongé.
    '07590 SAINT LAURENT LES BAINS LAVAL D AURELLE\nCEDEX 8':
        '[ADRESSE_1] LAVAL D AURELLE\nCEDEX 8',
    '70000 Vesoul part au tri de Besançon Cedex 9':
        '[ADRESSE_1] part au tri de Besançon Cedex 9',
    // Une civilité annonce toujours un nom, même devant « CEDEX » (sortie
    // d'avant P2-181, « CEDEX » compris dans le nom : inchangée).
    '70000 VESOUL A B C D Mme Durand CEDEX 9': '[ADRESSE_1] D Mme [NOM_1] 9',
  };
  for (final MapEntry(key: texte, value: attendu) in inchanges.entries) {
    test('inchangé sans CEDEX accolé : ${texte.replaceAll('\n', '⏎')}',
        () async {
      final r = await Ecluse.redact('Dépôt :\n$texte\nMerci.');
      expect(r.maskedText, 'Dépôt :\n$attendu\nMerci.', reason: r.maskedText);
    });
  }

  test('code postal + mots en capitales répétés sans CEDEX : coût linéaire',
      () async {
    await expectCroissanceLineaire((n) async {
      final texte = '70000 ${'AB ' * n}fin.';
      final r = await Ecluse.redact(texte);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    }, n: 5000);
  });

  test('« 70000 A » répété, CEDEX à la fin seulement : coût linéaire',
      () async {
    await expectCroissanceLineaire((n) async {
      final texte = '${'70000 A B C D E F G H I J ' * n}CEDEX 9';
      final r = await Ecluse.redact(texte);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    }, n: 2000);
  });
}
