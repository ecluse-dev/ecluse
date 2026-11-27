import 'package:ecluse_core/ecluse_core.dart' show EntityType;
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// SIRET nommé (P2-259) : quatorze chiffres après le mot « SIRET » sont masqués
/// en entier, type `siren` (le SIRET contient le SIREN, qui désigne une
/// personne pour un entrepreneur individuel : décision du 23 novembre). Nombres
/// fabriqués : 73282932000124 a une clé de Luhn juste, 73282932000127 une clé
/// fausse. Avant la tâche, ces quatorze chiffres partaient en clair.
void main() {
  const juste = '73282932000124';
  const fausse = '73282932000127';
  const groupe = '732 829 320 00124';

  for (final (nom, siret) in [
    ('compact', juste),
    ('groupé', groupe),
    ('blancs insécables', '732 829 320 00124'),
  ]) {
    test('$nom : masqué en entier, type siren, aucun chiffre en clair',
        () async {
      final texte = "Le SIRET de l'établissement est $siret.";
      final r = await Ecluse.redact(texte);
      expect(r.entities, hasLength(1));
      expect(r.entities.single.type, EntityType.siren);
      expect(r.entities.single.value, siret);
      expect(r.entities.single.confidence, greaterThan(0.5));
      expect(r.maskedText, "Le SIRET de l'établissement est [SIREN_1].");
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      expect(r.warnings.join(' '), isNot(contains('clé invalide')));
    });
  }

  test('clé de Luhn fausse : masqué quand même, 0,3, « à vérifier »', () async {
    final r = await Ecluse.redact('SIRET : $fausse noté.');
    expect(r.entities.single.type, EntityType.siren);
    expect(r.entities.single.value, fausse);
    expect(r.entities.single.confidence, 0.3);
    expect(r.maskedText, isNot(contains('0012')));
    expect(r.warnings.join(' '), contains('clé invalide'));
    expect(r.warnings.join(' '), isNot(contains(fausse)));
  });

  test('le mot après le nombre, dans la fenêtre de 40 caractères', () async {
    final r = await Ecluse.redact('Numéro $juste (SIRET) noté.');
    expect(r.entities.single.type, EntityType.siren);
    expect(r.entities.single.value, juste);
  });

  test('sans le mot SIRET, clé juste : masqués à 0,5 (P2-323)', () async {
    final r = await Ecluse.redact('Référence interne $juste notée.');
    expect(r.entities.single.type, EntityType.siren);
    expect(r.entities.single.confidence, 0.5);
    expect(r.maskedText, 'Référence interne [SIREN_1] notée.');
  });

  test('sans le mot SIRET, clé fausse : quatorze chiffres non masqués',
      () async {
    final r = await Ecluse.redact('Référence interne $fausse notée.');
    expect(r.entities, isEmpty);
    expect(r.maskedText, 'Référence interne $fausse notée.');
  });

  test('mot SIRET trop loin (plus de 40 caractères) : rien', () async {
    final loin =
        'SIRET ${' ' * 5}voir plus bas dans ce long texte sans rapport '
        'avec le numéro de référence $juste.';
    final r = await Ecluse.redact(loin);
    // Le mot est trop loin : pas de confiance 0,9, mais depuis P2-323 la clé
    // juste est masquée quand même, à 0,5.
    expect(r.entities.single.confidence, 0.5);
  });

  test('SIRET suivi d\'un nombre : le nombre voisin reste lisible', () async {
    final r = await Ecluse.redact('SIRET $groupe 1250 places.');
    expect(r.entities.single.value, groupe);
    expect(r.maskedText, 'SIRET [SIREN_1] 1250 places.');
  });

  test('SIREN de neuf chiffres derrière « SIRET » : inchangé (P2-248)',
      () async {
    final r = await Ecluse.redact('SIRET 732829320.');
    expect(r.entities.single.type, EntityType.siren);
    expect(r.entities.single.value, '732829320');
  });
}
