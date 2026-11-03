import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Mois français abrégés après un contexte de naissance (P2-83) : « janv. »,
/// « févr. », « fév. », « avr. », « juil. », « déc. ». Seuls « sept. », « oct. »
/// et « nov. » étaient masqués, par coïncidence avec la liste des mois anglais.
void main() {
  const masques = {
    'Patient né le 12 janv. 1950 suivi.': '12 janv. 1950',
    'Mme Quenelle née le 1er févr. 1950': '1er févr. 1950',
    'Mme Quenelle née le 3 fév. 1950': '3 fév. 1950',
    'M. Quenelle né le 7 févr 1950': '7 févr 1950',
    'M. Quenelle né le 9 avr. 1950': '9 avr. 1950',
    'M. Quenelle né le 9 avr 1950': '9 avr 1950',
    'M. Quenelle né le 14 juil. 1950': '14 juil. 1950',
    'M. Quenelle né le 14 juil 1950': '14 juil 1950',
    'M. Quenelle né le 25 déc. 1950': '25 déc. 1950',
    'M. Quenelle né le 25 DÉC. 1950': '25 DÉC. 1950',
    'DDN : 4 janv 1950': '4 janv 1950',
    // Libellés abrégés ou suivis de « le » / « du » (P2-83).
    'Naiss. 12/03/1950': '12/03/1950',
    'Naiss : 12/03/1950': '12/03/1950',
    'Mme Quenelle - naiss. 12/03/1950': '12/03/1950',
    'Naissance le 12 mars 1950 à Nantes': '12 mars 1950',
    'Naissance du 12/03/1950': '12/03/1950',
    // Date compacte à huit chiffres après un contexte de naissance.
    'DDN : 12031950': '12031950',
    'Né le 12031950': '12031950',
    'ddn 12031950': '12031950',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, contains('[DATE_NAISSANCE_'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Sans contexte de naissance, une date abrégée reste du texte ordinaire.
  const intacts = {
    'Rendez-vous le 12 janv. 2027': '12 janv. 2027',
    'Visite du 25 déc. 2026': '25 déc. 2026',
    'Le 14 juil. 2026, réunion': '14 juil. 2026',
    'Naissance du projet le 12 mars 2027': 'projet',
    'Naiss. du produit': 'produit',
    'DDN : 99999999': '99999999',
    'DDN : 31132000': '31132000',
    'Réf. 12031950': '12031950',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
    });
  }
}
