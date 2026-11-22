import 'package:ecluse_core/ecluse_core.dart' show EntityType;
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// SIREN nommé (P2-248) : un nombre de neuf chiffres que le texte appelle
/// « SIREN » ou « SIRET » est typé `siren`, pas `finess`, et reste masqué
/// (le SIREN d'un entrepreneur individuel désigne une personne). Nombres
/// fabriqués : 732829320 a une clé de Luhn juste.
void main() {
  test('jeton [SIREN_1], valeur absente du texte masqué, restauration exacte',
      () async {
    const texte = 'Le SIREN de la société est 732829320.';
    final r = await Ecluse.redact(texte);
    expect(r.entities.map((e) => e.type), [EntityType.siren]);
    expect(r.maskedText, 'Le SIREN de la société est [SIREN_1].');
    expect(r.maskedText, isNot(contains('732829320')));
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('même SIREN deux fois : même jeton', () async {
    final r = await Ecluse.redact('SIREN 732829320, puis SIRET 732829320.');
    expect(r.maskedText, 'SIREN [SIREN_1], puis SIRET [SIREN_1].');
  });

  test('sans le mot : FINESS inchangé, toujours masqué', () async {
    final r = await Ecluse.redact('Société 732829320 immatriculée.');
    expect(r.entities.single.type, EntityType.finess);
    expect(r.maskedText, contains('[FINESS_1]'));
  });

  test('aucune valeur du texte dans les avertissements', () async {
    final r = await Ecluse.redact('Le SIREN est 732829320.');
    for (final w in r.warnings) {
      expect(w, isNot(contains('732829320')));
    }
  });
}
