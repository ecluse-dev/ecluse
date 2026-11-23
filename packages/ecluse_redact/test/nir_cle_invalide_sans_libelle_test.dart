import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-258 : un NIR à clé fausse, sans libellé, est masqué en entier par
/// `Ecluse.redact` (décision du 23 novembre : un NIR mal recopié reste celui
/// d'un patient). Cas synthétiques, clé calculée puis volontairement fausse ;
/// jamais une valeur réelle.
void main() {
  // Corps 2 85 05 78 006 084, clé juste 41 : on met 46.
  const compact = '285057800608446';
  const groupe = '2 85 05 78 006 084 46';
  // Même corps, clé fausse, lettre « O » à la place de deux zéros.
  const ocr = '2 85 O5 78 OO6 084 46';

  for (final (nom, nir) in [
    ('compact', compact),
    ('groupé', groupe),
    ('lettres d\'OCR', ocr),
  ]) {
    test('$nom : masqué en entier, type nir, confiance 0,3', () async {
      final r = await Ecluse.redact(
          'Attention, saisie erronée hier : $nir a été rejeté par le contrôle.');
      expect(r.entities, hasLength(1));
      expect(r.entities.single.type, EntityType.nir);
      expect(r.entities.single.value, nir);
      expect(r.entities.single.confidence, 0.3);
      expect(r.maskedText, isNot(contains('006')));
      expect(r.maskedText, isNot(contains('084')));
      expect(r.warnings.join(' '), contains('clé invalide'));
      // L'avertissement ne porte jamais la valeur.
      expect(r.warnings.join(' '), isNot(contains('084')));
    });

    test('$nom : restauration exacte', () async {
      final texte = 'Numéro $nir noté.';
      final r = await Ecluse.redact(texte);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('clé nommée à part fausse : reste intacte (P2-42)', () async {
    for (final t in [
      'NIR : 2550814168025 clé 39',
      'Page 1850397100123 clé 99',
      'Chambre 12 clé 38 remise',
    ]) {
      final r = await Ecluse.redact(t);
      expect(r.mapping.jetons, isNot(contains('[NIR_1]')), reason: t);
    }
  });

  test('RPPS suivi d\'un nombre : pas avalé en « NIR » (P2-174)', () async {
    final r = await Ecluse.redact('RPPS 10192209566 1250 places noté.');
    expect(r.entities.single.type, EntityType.rpps);
    expect(r.entities.single.value, '10192209566');
  });

  test('NIR valide : confiance 1,0, aucun avertissement de clé', () async {
    final r = await Ecluse.redact('NIR 2 85 05 78 006 084 41.');
    expect(r.entities.single.confidence, 1.0);
    expect(r.warnings.join(' '), isNot(contains('clé invalide')));
  });
}
