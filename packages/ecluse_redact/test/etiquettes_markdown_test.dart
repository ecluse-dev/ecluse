import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Étiquettes décorées en Markdown ou en HTML (P2-51) : « **Date de naissance :**
/// 12/03/1950 » n'était pas détectée, les marques de gras ou d'italique séparant
/// l'étiquette de sa valeur. Les marques sont neutralisées dans la vue de
/// détection seulement (le texte n'est jamais réécrit).
void main() {
  const masques = {
    '**Date de naissance :** 12/03/1950': '1950',
    '**Date de naissance** : 12/03/1950': '1950',
    '__Date de naissance :__ 12/03/1950': '1950',
    '*Date de naissance* : 12/03/1950': '1950',
    '`Date de naissance` : 12/03/1950': '1950',
    '<b>Date de naissance :</b> 12/03/1950': '1950',
    '<strong>Né le</strong> 12/03/1950': '1950',
    '**Né le** 12/03/1950': '1950',
    '_Née le_ 12 mars 1950': '1950',
    '**Nom :** Quenelle\n**Prénom :** Zorglub': 'Quenelle',
    '**Nom** : Quenelle\n**Prénom** : Zorglub': 'Zorglub',
    '* **Nom** : Quenelle ; **Prénom** : Zorglub': 'Quenelle',
    '__Nom :__ Quenelle  __Prénom :__ Zorglub': 'Zorglub',
    '<b>Nom :</b> Quenelle <b>Prénom :</b> Zorglub': 'Quenelle',
    '**Nom de naissance :** Quenelle': 'Quenelle',
    '**Mme** Zorglub Quenelle': 'Quenelle',
    '**Téléphone :** 01 99 00 12 34': '12 34',
    '**IBAN :** FR76 3000 6000 0112 3456 7890 189': '3456',
    '**Date de naissance :** **12/03/1950**': '1950',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Le fichier jean_dupont_2024.txt': 'jean_dupont_2024',
    'Calcul : 3 * 4 = 12': '3 * 4',
    'Une **phrase** en gras': '**phrase**',
    'Voir __init__ et snake_case_name': '__init__',
    '[NOM_1] puis [TELEPHONE_1]': '[NOM_1]',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('inchangé : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
    });
  }

  // Une première version de l'expression (alternatives `\*\*|\*` répétées) avait un
  // retour arrière exponentiel : 50 000 étoiles prenaient 51 s (0,1 s sans la
  // règle). Coût mesuré par rapport de tailles (P2-100) : voir
  // `support/cout.dart`.
  for (final marque in ['*', '_', '`', '*_`', '**a ', 'a** ']) {
    test('« $marque » répété : coût linéaire', () async {
      await expectCroissanceLineaire((n) async {
        await Ecluse.redact(marque * n);
      }, n: 25000, raison: marque);
    });
  }
}
