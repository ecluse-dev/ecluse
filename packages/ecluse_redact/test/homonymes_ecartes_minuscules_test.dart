import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-315 (principe du 26 novembre, point 0) : en texte **sans majuscule**
/// (dictée, transcription, courriel pressé), les chemins « civilité » et « le
/// dossier de » de `NameDetector.homonymesEcartes` exigeaient une majuscule : 243
/// des 607 patronymes homonymes laissés en clair par les quatre listes d'exclusion
/// n'étaient pas signalés (mesure P2-314). Ces chemins signalent désormais aussi
/// le mot écrit en minuscules, avec le même avertissement (compte et positions,
/// **jamais la valeur**). **Aucun masquage ne change.**
void main() {
  final motif = RegExp(r'mot pris pour un nom commun.*non masqué : à vérifier');

  Future<void> signale(String texte, String mot) async {
    final r = await Ecluse.redact(texte);
    final a = r.warnings.where(motif.hasMatch).toList();
    expect(a, hasLength(1), reason: texte);
    expect(a.single, contains('1 occurrence'), reason: texte);
    final debut = texte.indexOf(mot);
    expect(a.single, contains('position $debut)'), reason: texte);
    expect(a.single.toLowerCase(), isNot(contains(mot.toLowerCase())),
        reason: 'la valeur ne figure pas dans l\'avertissement');
    // Le mot reste en clair : aucun masquage ne change.
    expect(
        r.entities.where((e) => e.start < debut + mot.length && e.end > debut),
        isEmpty,
        reason: texte);
  }

  group('« le dossier de » sans majuscule', () {
    test('statut',
        () => signale('le dossier de marié a été transmis hier.', 'marié'));
    test('mois',
        () => signale('le dossier de avril a été transmis hier.', 'avril'));
    test('jour',
        () => signale('le dossier de lundi a été transmis hier.', 'lundi'));
    test('mot de rôle',
        () => signale('le dossier de maitre a été transmis hier.', 'maitre'));
    test('verbe conjugué',
        () => signale('le dossier de serre a été transmis hier.', 'serre'));
    test('« à la demande de »',
        () => signale('à la demande de avril, le dossier a suivi.', 'avril'));
    test('« l\'entretien avec »',
        () => signale('l\'entretien avec avril est fixé à demain.', 'avril'));
  });

  group('civilité sans majuscule', () {
    test('adverbe de temps',
        () => signale('madame demain est venue ce matin.', 'demain'));
    test('verbe conjugué',
        () => signale('madame fait est venue ce matin.', 'fait'));
  });

  group('pas de signal', () {
    for (final texte in [
      'le dossier de presse est prêt.',
      'le dossier de zorglub quenelle a été transmis.',
      'madame dupont est venue ce matin.',
      'réunion lundi à 14 h, salle 3.',
      'le dossier est prêt demain matin.',
      'rdv avec marc laurent ce matin.',
      // Le mot est un titre devant un nom déjà masqué : rien n'est en clair.
      'le dossier de monsieur pelletan a été transmis.',
      'suite à l\'entretien avec monsieur kerlo, le service rappelle.',
      'à la demande de monsieur camille pelletan, le rdv est reporté.',
    ]) {
      test(texte, () async {
        final r = await Ecluse.redact(texte);
        expect(r.warnings.where(motif.hasMatch), isEmpty);
      });
    }
  });

  test('casse ordinaire : inchangé (le mot capitalisé est signalé une fois)',
      () async {
    final r = await Ecluse.redact('Le dossier de Avril a été transmis hier.');
    expect(r.warnings.where(motif.hasMatch), hasLength(1));
  });
}
