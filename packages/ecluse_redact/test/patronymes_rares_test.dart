import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Patronymes rares, absents de toute liste de noms courants. Un vrai dossier
/// contient beaucoup de noms qu'aucun dictionnaire ne connaît : après une
/// civilité, ils doivent être masqués comme un nom courant, et restaurés à
/// l'identique. Noms inventés pour ces tests.
const _cas = <String, String>{
  'patronyme rare après Mme': 'Mme Solène Brimagault',
  'patronyme rare après M.': 'M. Anatole Crespinviel',
  'patronyme rare composé': 'Mme Maëlys Vandrecourt-Ostal',
};

void main() {
  for (final MapEntry(key: nom, value: personne) in _cas.entries) {
    test(nom, () async {
      final t = 'Rendez-vous avec $personne demain.';
      final r = await Ecluse.redact(t);
      expect(r.maskedText,
          matches(RegExp(r'^Rendez-vous avec (Mme |M\. )\[NOM_1\] demain\.$')),
          reason: 'nom rare non masqué : "${r.maskedText}"');
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
      final es = await Ecluse.detect(t);
      for (final e in es) {
        expect(t.substring(e.start, e.end), e.value);
      }
    });
  }
}
