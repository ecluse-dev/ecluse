import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Nom de naissance ou d'épouse derrière « née », « épouse », « veuve »…
/// (P2-45). « Mme Quenelle née Dupont » masquait le nom d'usage mais laissait le
/// nom de naissance en clair, sauf par hasard quand il figurait au gazetteer des
/// prénoms (« épouse Martin »). L'indice est le mot lui-même (« née », « épouse »
/// suivis d'un nom en majuscule initiale) ; aucun mot en minuscule n'est touché.
void main() {
  const masques = {
    'Mme Quenelle née Dupont': 'Dupont',
    'Mme Zorglub Quenelle née Dupont': 'Dupont',
    'Zorglub Quenelle, née Dupont, 45 ans': 'Dupont',
    'Mme Quenelle épouse Dupont': 'Dupont',
    'Mme Quenelle, épouse Dupont': 'Dupont',
    'Mme Quenelle ép. Dupont': 'Dupont',
    'Mme Quenelle veuve Dupont': 'Dupont',
    'Mme Quenelle (née Dupont)': 'Dupont',
    'Mme Quenelle née DUPONT': 'DUPONT',
    'Mme Quenelle née de la Fontaine': 'Fontaine',
    'Mme Quenelle née Dupont-Zorglub': 'Zorglub',
    'née Dupont le 12/03/1950': 'Dupont',
    'Mme Quenelle divorcée Dupont': 'Dupont',
    'Née Dupont en 1950': 'Dupont',
    'Épouse Dupont, secrétaire': 'Dupont',
    'Nom de jeune fille : Dupont': 'Dupont',
    'Mme Quenelle, nom de jeune fille Dupont': 'Dupont',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'née le 12/03/1950': 'née le',
    'née à Lyon': 'Lyon',
    'Elle est née Lundi': 'Lundi',
    'Elle est née Janvier': 'Janvier',
    'née en France': 'France',
    "épouse de l'intéressé": 'épouse',
    'sa veuve est présente': 'veuve',
    'Mme Quenelle épouse': 'épouse',
    'ép. 12': 'ép.',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
    });
  }
}
