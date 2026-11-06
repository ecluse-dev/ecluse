import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Avertissement sur un texte sans aucune majuscule (P2-118).
///
/// Mesure P2-117 : sur un texte mis en minuscules, la fuite des noms, des
/// adresses et des établissements passe à 100 %, parce que ces détecteurs
/// reposent sur la majuscule initiale. Le résultat ressemblait alors à un
/// texte sans donnée nominative : échec silencieux (règle 4).
bool _averti(RedactResult r) =>
    r.warnings.any((w) => w.contains('aucune majuscule'));

void main() {
  test('texte en minuscules : avertissement', () async {
    final r = await Ecluse.redact(
        'rdv avec m. julien chevrier au ssiad de gray demain matin');
    expect(_averti(r), isTrue);
  });

  test('texte ordinaire : aucun avertissement', () async {
    final r = await Ecluse.redact(
        'Rendez-vous avec M. Julien Chevrier au SSIAD de Gray demain.');
    expect(_averti(r), isFalse);
  });

  test('texte très court ou sans mots : aucun avertissement', () async {
    for (final texte in ['ok merci', '', '06 12 34 56 78', '12/03/2026']) {
      expect(_averti(await Ecluse.redact(texte)), isFalse, reason: texte);
    }
  });

  test('l\'avertissement ne change ni le texte masqué ni la table', () async {
    const texte = 'appeler le 06 12 34 56 78 pour la suite du dossier';
    final r = await Ecluse.redact(texte);
    expect(_averti(r), isTrue);
    expect(r.maskedText, isNot(contains('06 12 34 56 78')));
    expect(r.mapping.values, contains('06 12 34 56 78'));
  });

  test('le message ne prétend plus que rien n\'est détecté (P2-133)', () async {
    final r = await Ecluse.redact(
        'rdv avec m. julien chevrier au ssiad de gray demain matin');
    final w = r.warnings.firstWhere((w) => w.contains('aucune majuscule'));
    expect(w, contains('moins sûre'));
    expect(w, isNot(contains('ne sont pas détectés')));
    expect(r.maskedText, isNot(contains('chevrier')));
  });
}
