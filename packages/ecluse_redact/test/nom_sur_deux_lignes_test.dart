import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Nom coupé par un retour à la ligne (P2-73). Un texte extrait d'un PDF ou copié
/// d'une mise en page coupe les lignes n'importe où : « Mme Marie⏎Dupont »,
/// « Mme⏎Dupont », « Nom :⏎Quenelle » laissaient le nom ou le patronyme en
/// clair. Un **seul** saut de ligne (jamais une ligne vide) est maintenant admis
/// entre une civilité et son nom, entre « née » et son nom, et entre une
/// étiquette « Nom : » et sa valeur ; un nom n'est jamais prolongé au-delà de
/// sa ligne (garde-fou ancien : « Dr Martin⏎Secretaire de séance ») ; un mot qui ouvre
/// ordinairement une phrase (« Le », « Il », « Dans »…) n'est jamais pris pour un
/// nom après un saut de ligne.
void main() {
  const masques = {
    'Mme\nDupont est venue.': ['Dupont'],
    'Le Dr\nQuenelle': ['Quenelle'],
    'Nom :\nQuenelle\nPrénom :\nZorglub': ['Quenelle', 'Zorglub'],
    'Nom :\r\nQuenelle\r\nPrénom :\r\nZorglub': ['Quenelle', 'Zorglub'],
    'Nom de naissance :\nDupont': ['Dupont'],
    'Patient :\nZorglub Quenelle': ['Quenelle'],
    'Prénom :  \n  Zorglub\nNom : Quenelle': ['Zorglub', 'Quenelle'],
    'née\nDupont': ['Dupont'],
  };
  for (final MapEntry(key: texte, value: restes) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      for (final v in restes) {
        expect(r.maskedText, isNot(contains(v)), reason: r.maskedText);
      }
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Merci à Mme\nLe rapport est prêt.': 'rapport',
    'Voir M.\nIl viendra demain.': 'Il viendra',
    'Mme\n\nDupont': 'Dupont',
    'Nom :\n\nQuenelle': 'Quenelle',
    'Nom :\nAspirine\nDose : 100 mg': 'Aspirine',
    'Mme Dupont\nLe lendemain': 'Le lendemain',
    'Dr Martin\nSecretaire de séance.': 'Secretaire',
    // Un nom n'est jamais prolongé au-delà de la fin de sa ligne : « Mme Marie⏎Dupont »
    // masque « Marie » (limite documentée, voir LIMITES.md).
    'Mme Marie\nDupont est venue.': 'Dupont',
    'Dr\nDans le service': 'Dans le service',
    'Prénom :\nNom :': 'Nom',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
