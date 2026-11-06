import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Casse de phrase (P2-138) : seule la première lettre de la phrase est en
/// majuscule. Mesure avant : fuite globale 61,9 % (réaliste) et 81,3 %
/// (adversarial) ; après : 0,6 % et 13,0 %.
void main() {
  test('noms, adresse et établissement masqués', () async {
    final r = await Ecluse.redact('Rdv avec m. julien chevrier au 7 impasse '
        'des charmilles, 70160 port sur saone. Puis visite au ssiad de gray.');
    expect(r.maskedText, isNot(contains('chevrier')));
    expect(r.maskedText, isNot(contains('charmilles')));
    expect(r.warnings.join(), contains('ne portent pas de majuscule'));
  });

  test('sigle et puce de liste : toujours casse de phrase', () async {
    final r = await Ecluse.redact('Participants :\n- m. julien chevrier, '
        'référent SSIAD\n- mme claire roux');
    expect(r.maskedText, isNot(contains('chevrier')));
    expect(r.maskedText, isNot(contains('roux')));
    expect(r.warnings.join(), contains('ne portent pas de majuscule'));
  });

  test('majuscule après « M. » : nom propre, casse ordinaire', () async {
    for (final texte in [
      'M. J. est venu.',
      'M. Bénéficiaire du RSA.',
      'M. Dupont est venu.',
    ]) {
      final r = await Ecluse.redact(texte);
      expect(r.warnings, isEmpty, reason: texte);
    }
  });

  test('phrase sans nom propre : aucun avertissement', () async {
    final r = await Ecluse.redact('Le patient va bien aujourd\'hui.');
    expect(r.warnings, isEmpty);
  });

  test('casse ordinaire : comportement inchangé, aucun avertissement',
      () async {
    final r = await Ecluse.redact(
        'Rendez-vous avec M. Julien Chevrier au SSIAD de Gray demain.');
    expect(r.maskedText, isNot(contains('Chevrier')));
    expect(r.warnings, isEmpty);
  });

  test('texte sans aucune majuscule : message d\'origine', () async {
    final r = await Ecluse.redact('rdv avec m. julien chevrier demain matin');
    expect(r.warnings.join(), contains('aucune majuscule'));
    expect(r.warnings.join(), isNot(contains('ne portent pas')));
  });
}
