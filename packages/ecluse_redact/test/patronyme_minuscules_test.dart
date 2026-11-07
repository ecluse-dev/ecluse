import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Patronyme seul en minuscules (P2-144) : « compte rendu : hautecoeur a
/// confirmé » après « mme aurélie hautecoeur ». La mesure P2-140 trouvait
/// 116 noms non détectés dans les dossiers en minuscules, tous de ce type.
void main() {
  test('dans un dossier : patronyme établi en minuscules, repris seul',
      () async {
    final dossier = Dossier();
    await Ecluse.redact(
        'pièces jointes au dossier de mademoiselle aurélie '
        'hautecoeur : attestation.',
        dossier: dossier);
    final r = await Ecluse.redact(
        'compte rendu : hautecoeur a confirmé la réception des pièces.',
        dossier: dossier);
    expect(r.maskedText, isNot(contains('hautecoeur')), reason: r.maskedText);
  });

  test('dans le même texte : seconde mention seule', () async {
    final r = await Ecluse.redact('rdv avec mme odile verdier ce matin. '
        'suite à l\'entretien avec verdier, le suivi est maintenu.');
    expect(r.maskedText, isNot(contains('verdier')), reason: r.maskedText);
    expect(r.maskedText, contains('[NOM_'));
  });

  test('prénom + nom établit aussi le patronyme', () async {
    final r = await Ecluse.redact('compte rendu : julien chevrier a appelé. '
        'rappeler chevrier demain.');
    expect(r.maskedText, isNot(contains('chevrier')), reason: r.maskedText);
  });

  test('aucun patronyme établi : un mot seul reste en clair', () async {
    const t = 'compte rendu : urbain a confirmé la réception.';
    final r = await Ecluse.redact(t);
    expect(r.maskedText, t);
  });

  test('casse ordinaire : inchangé', () async {
    const t = 'Le tissu urbain est dense. Mme Odile Verdier est venue.';
    final r = await Ecluse.redact(t);
    expect(r.maskedText, contains('tissu urbain'));
  });

  test('mot outil ou neutre jamais repris comme patronyme', () async {
    final r = await Ecluse.redact('rdv avec m. le directeur. le suivi est '
        'maintenu, le dossier est complet.');
    expect(r.maskedText, contains('le suivi'), reason: r.maskedText);
  });

  casseMixte();
}

/// Même identité citée en casses différentes dans un dossier (P2-145) :
/// « M. Antoine Lacombe » puis « m. antoine lacombe » recevaient deux jetons,
/// la civilité de genre comptant comme un segment du nom en minuscules.
void casseMixte() {
  test('même identité, casses différentes : un seul jeton', () async {
    final dossier = Dossier();
    final a = await Ecluse.redact('Rendez-vous avec M. Antoine Lacombe.',
        dossier: dossier);
    final b = await Ecluse.redact('rendez-vous avec m. antoine lacombe.',
        dossier: dossier);
    final c = await Ecluse.redact('RENDEZ-VOUS AVEC M. ANTOINE LACOMBE.',
        dossier: dossier);
    final jeton = RegExp(r'\[NOM_\d+\]');
    final ja = jeton.firstMatch(a.maskedText)?.group(0);
    expect(ja, isNotNull);
    expect(jeton.firstMatch(b.maskedText)?.group(0), ja, reason: b.maskedText);
    expect(jeton.firstMatch(c.maskedText)?.group(0), ja, reason: c.maskedText);
  });

  test('civilités de sexe différent : toujours deux jetons', () async {
    final dossier = Dossier();
    final a =
        await Ecluse.redact('M. Antoine Lacombe est venu.', dossier: dossier);
    final b =
        await Ecluse.redact('mme antoine lacombe est venue.', dossier: dossier);
    expect(a.maskedText, contains('[NOM_1]'));
    expect(b.maskedText, isNot(contains('[NOM_1]')), reason: b.maskedText);
  });
}
