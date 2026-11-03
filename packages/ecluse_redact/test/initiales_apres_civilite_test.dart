import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Initiale entre une civilité et un patronyme (P2-75). « Dr A. Faure a prescrit »
/// donnait « [NOM_1]. Faure a prescrit » : l'initiale était masquée, le patronyme
/// restait en clair (inversion). C'est la forme usuelle des soignants cités
/// (« Dr M. Dupont », « M. J. Dupuis », « Mme M.-C. Roux »).
void main() {
  const masques = {
    'Dr A. Faure a prescrit': 'Faure',
    'Signé : Dr M. Dupont, médecin coordonnateur': 'Dupont',
    'M. J. Dupuis, kiné': 'Dupuis',
    'Mme R. Lefebvre-Garnier': 'Lefebvre',
    'Mme M.-C. Roux': 'Roux',
    'Dr J.-P. Faure': 'Faure',
    'Docteur P. Martin': 'Martin',
    'Pr J.-L. Zxqvlorn': 'Zxqvlorn',
    'Mme A. B. Quenelle': 'Quenelle',
    'Madame C. de la Fontaine': 'Fontaine',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('patronyme masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, contains('[NOM_'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('« Dr A. Faure » puis « Dr Faure » : une seule personne', () async {
    final r =
        await Ecluse.redact('Dr A. Faure a prescrit. Le Dr Faure rappelle.');
    expect(r.mapping.length, 1, reason: r.maskedText);
  });

  const commeAvant = {
    // Initiale seule : comportement d'avant (l'initiale est le nom connu).
    'Mme B. a refusé': 'Mme [NOM_1]. a refusé',
    'M. J. est venu': 'M. [NOM_1]. est venu',
    'Dr Faure a prescrit': '[NOM_1] a prescrit',
  };
  for (final MapEntry(key: texte, value: attendu) in commeAvant.entries) {
    test('inchangé : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, attendu);
    });
  }
}
