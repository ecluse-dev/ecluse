import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Un texte qui contient déjà un jeton (`[NOM_1]`) ne doit pas être
/// confondu avec un jeton généré : sinon la restauration réinjecte la valeur
/// d'une personne à la place du texte d'origine.
void main() {
  Future<void> aller(String texte) async {
    final r = await Ecluse.redact(texte);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte,
        reason: 'aller-retour de "$texte" (masqué : ${r.maskedText})');
  }

  test('jeton littéral de même type', () async {
    const texte = 'Voir [NOM_1] et M. Jean Dupont.';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, contains('[NOM_1]')); // le littéral reste tel quel
    expect(r.mapping.keys, isNot(contains('[NOM_1]')));
    await aller(texte);
  });

  test('jeton littéral d\'un autre type', () async {
    await aller('Email: [EMAIL_1] puis jean.dupont@example.fr');
  });

  test('jeton littéral déformé (casse, espaces)', () async {
    await aller('Voir [ nom_1 ] et M. Jean Dupont.');
  });

  test('jetons littéraux 1 et 2 : numérotation sans trou ni collision',
      () async {
    const texte = '[NOM_1] [NOM_2] M. Jean Dupont et Mme Alice Martin';
    final r = await Ecluse.redact(texte);
    expect(r.mapping.keys.toSet(), {'[NOM_3]', '[NOM_4]'});
    await aller(texte);
  });

  test('sans jeton littéral, la numérotation ne change pas', () async {
    final r = await Ecluse.redact('M. Jean Dupont et Mme Alice Martin');
    expect(r.mapping.keys.toSet(), {'[NOM_1]', '[NOM_2]'});
  });
}
