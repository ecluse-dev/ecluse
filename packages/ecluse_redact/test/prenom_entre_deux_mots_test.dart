import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Un prénom entouré de deux mots en majuscule initiale (P2-70). La règle
/// bidirectionnelle prenait le mot qui précède et laissait celui qui suit :
/// « Appeler Pierre Dupont demain » donnait « [NOM_1] Dupont demain » — le
/// patronyme restait en clair dès qu'un mot capitalisé (début de phrase, titre,
/// « Patient », « Bilan »…) précédait « Prénom Nom ». Les deux voisins sont
/// maintenant couverts : en cas de doute on protège (le mot en trop est masqué,
/// mais le patronyme ne fuit plus).
void main() {
  const masques = {
    'Appeler Pierre Dupont demain.': 'Dupont',
    'Contacter Pierre Dupont': 'Dupont',
    'Bilan Pierre Dupont': 'Dupont',
    'Merci Pierre Dupont': 'Dupont',
    'Mardi Pierre Dupont viendra.': 'Dupont',
    'Rendez-vous Pierre Dupont jeudi.': 'Dupont',
    'Résident Pierre Dupont': 'Dupont',
    'Patient Pierre Dupont': 'Dupont',
    'Pièce jointe : Bilan Pierre Dupont.docx': 'Dupont',
    'Visite Marie Quenelle': 'Quenelle',
    'Dossier Jean Zxqvlorn': 'Zxqvlorn',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('patronyme masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('Pierre')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('même personne : « Pierre Dupont » plus loin garde le même jeton',
      () async {
    final r =
        await Ecluse.redact('Appeler Pierre Dupont. Pierre Dupont rappelle.');
    expect(r.mapping.length, 1, reason: r.maskedText);
    expect(RegExp(r'\[NOM_1\]').allMatches(r.maskedText).length, 2,
        reason: r.maskedText);
  });

  const inchanges = {
    // Un seul voisin : comportement d'avant.
    'Il faut appeler Pierre Dupont demain.': 'Il faut appeler [NOM_1] demain.',
    'Hier, Pierre Dupont est venu.': 'Hier, [NOM_1] est venu.',
    'Entretien avec Pierre Dupont': 'Entretien avec [NOM_1]',
    'Pierre Dupont est venu.': '[NOM_1] est venu.',
    'Dupont Pierre est venu.': '[NOM_1] est venu.',
  };
  for (final MapEntry(key: texte, value: attendu) in inchanges.entries) {
    test('inchangé : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, attendu);
    });
  }
}
