import 'dart:math';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Caractères invisibles et séparateurs typographiques dans un identifiant
/// (P2-29). Un copier-coller depuis le web ou un PDF glisse souvent un espace
/// sans chasse (U+200B), un trait d'union conditionnel ou un tiret demi-cadratin
/// dans un numéro : il doit être détecté et masqué en entier, **sans que les
/// positions ni la valeur d'origine changent** (invariant : le texte n'est jamais
/// réécrit, la table garde la valeur exacte pour la restauration).
String _nir(String s) => '1${s}88${s}05${s}44${s}056${s}003${s}25';
String _tel(String s) => '01${s}99${s}00${s}12${s}34';
String _iban(String s) => 'FR40${s}3000${s}3015${s}7000${s}0370${s}8452${s}432';

const _separateurs = {
  'U+200B espace sans chasse': '​',
  'U+200C': '‌',
  'U+2060 lien de mots': '⁠',
  'U+FEFF': '﻿',
  'U+00AD trait d\'union conditionnel': '­',
  'U+2009 espace fine': ' ',
  'U+2011 trait d\'union insécable': '‑',
  'U+2013 tiret demi-cadratin': '–',
  'U+2212 signe moins': '−',
};

void main() {
  final formes = <(String, String Function(String), EntityType)>[
    ('NIR', _nir, EntityType.nir),
    ('téléphone', _tel, EntityType.telephone),
    ('IBAN', _iban, EntityType.iban),
  ];

  for (final MapEntry(key: nom, value: sep) in _separateurs.entries) {
    for (final (type, forme, entite) in formes) {
      test('$type avec $nom', () async {
        final valeur = forme(sep);
        final t = 'Valeur $valeur fin.';
        final es = await Ecluse.detect(t);
        final e = es.where((x) => x.type == entite).toList();
        expect(e, hasLength(1), reason: 'non détecté : "$t"');
        expect(e.single.value, valeur, reason: 'valeur d\'origine conservée');
        expect(t.substring(e.single.start, e.single.end), valeur);
        final r = await Ecluse.redact(t);
        expect(r.maskedText, 'Valeur [${entityTypeLabel(entite)}_1] fin.');
        expect(Ecluse.restore(r.maskedText, r.mapping), t);
      });
    }
  }

  test('invisible en bordure : masqué, jamais de chiffre laissé', () async {
    final t = 'A ​${_nir(' ')}​ B';
    final r = await Ecluse.redact(t);
    expect(r.maskedText, isNot(contains('88')));
    expect(Ecluse.restore(r.maskedText, r.mapping), t);
  });

  test('séquence ZWJ d\'émojis : détection et restauration inchangées',
      () async {
    const t = '👩‍⚕️ M. Jean Dupont, 🇫🇷 tel 01 99 00 12 34.';
    final r = await Ecluse.redact(t);
    expect(r.maskedText, contains('[TELEPHONE_1]'));
    expect(r.maskedText, contains('👩‍⚕️'));
    expect(Ecluse.restore(r.maskedText, r.mapping), t);
  });

  test('propriété : positions et valeurs cohérentes (graine 42)', () async {
    final rng = Random(42);
    const inv = ['​', '‌', '⁠', '﻿', '­', '–'];
    for (var i = 0; i < 400; i++) {
      final base = [
        'Mme Sophie Verdier ',
        _nir(' '),
        ' ',
        _tel(' '),
        ' sophie@example.fr ',
        _iban(' '),
        ' fin'
      ].join();
      final b = StringBuffer();
      for (final c in base.runes) {
        b.writeCharCode(c);
        if (rng.nextInt(12) == 0) b.write(inv[rng.nextInt(inv.length)]);
      }
      final t = b.toString();
      final es = await Ecluse.detect(t);
      for (var j = 0; j < es.length; j++) {
        expect(t.substring(es[j].start, es[j].end), es[j].value);
        if (j > 0) expect(es[j - 1].end <= es[j].start, isTrue);
      }
      final r = await Ecluse.redact(t);
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    }
  });
}
