import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Chiffres et signes d'autres systèmes d'écriture dans un identifiant (P2-30) :
/// formes pleine chasse (« ０１ ９９ »), chiffres arabes orientaux, barre de
/// fraction. Comme pour P2-29, les détecteurs lisent une vue du texte à
/// longueur constante ; positions, valeur et restauration restent celles du
/// texte d'origine.
const _cas = <String, (String, EntityType)>{
  'téléphone pleine chasse': ('Tel ０１ ９９ ００ １２ ３４ fin', EntityType.telephone),
  'NIR pleine chasse': ('NIR １ ８８ ０５ ４４ ０５６ ００３ ２５ fin', EntityType.nir),
  'IBAN pleine chasse': (
    'IBAN ＦＲ４０ ３０００ ３０１５ ７０００ ０３７０ ８４５２ ４３２ fin',
    EntityType.iban
  ),
  'courriel avec arobase pleine chasse': (
    'Mail jean.dupont＠example.fr fin',
    EntityType.email
  ),
  'téléphone en chiffres arabes orientaux': (
    'Tel ٠١ ٩٩ ٠٠ ١٢ ٣٤ fin',
    EntityType.telephone
  ),
  'date avec barre de fraction': (
    'né le 12⁄03⁄1950 fin',
    EntityType.dateNaissance
  ),
};

void main() {
  for (final MapEntry(key: nom, value: (t, type)) in _cas.entries) {
    test(nom, () async {
      final es = await Ecluse.detect(t);
      final e = es.where((x) => x.type == type).toList();
      expect(e, isNotEmpty, reason: 'non détecté : "$t"');
      for (final x in e) {
        expect(t.substring(x.start, x.end), x.value);
      }
      final r = await Ecluse.redact(t);
      expect(r.maskedText, contains('[${entityTypeLabel(type)}_1]'));
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });
  }

  test('un texte pleine chasse sans identifiant reste intact', () async {
    const t = 'Ｒéunion ｄｕ ｓｅｒｖｉｃｅ ｒｅｐｏｒｔéｅ.';
    final r = await Ecluse.redact(t);
    expect(r.maskedText, t);
    expect(r.mapping, isEmpty);
  });
}
