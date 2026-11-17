import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Mots neutres écrits sans accent (P2-212). `mots_neutres.dart` n'a que les
/// formes accentuées (« à », « numéro », « numéros », « salariés »,
/// « résidents »). Un courrier, un export ou une dictée perd souvent
/// l'accent, surtout en capitales : « 39314 NUMEROS EN ATTENTE » était masqué
/// en adresse (P2-211 : 628 / 1 000 phrases à la forme sans accent). Un
/// masquage en trop, pas une fuite. Aucun des cinq mots, sans accent, n'est un
/// premier mot de commune du référentiel versionné.
void main() {
  const intacts = [
    '39314 NUMEROS EN ATTENTE',
    '39314 NUMERO EN ATTENTE',
    '70000 A TRAITER',
    '12345 SALARIES CONCERNES',
    '12345 RESIDENTS ACCUEILLIS',
    'Reste 39314 numeros en attente.',
    'Reste 39314 a traiter.',
    'Total : 12345 salaries concernes.',
    'Soit 12345 residents accueillis.',
  ];
  for (final texte in intacts) {
    test('inchangé : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }

  // Garde : une vraie commune reste masquée, et les formes accentuées aussi
  // restent neutres.
  test('une commune en capitales reste masquée', () async {
    final r = await Ecluse.redact('COURRIER :\n39100 LES MAILLYS\nMERCI.');
    expect(r.maskedText, contains('[ADRESSE_1]'), reason: r.maskedText);
  });
  test('forme accentuée toujours neutre', () async {
    final r = await Ecluse.redact('39314 NUMÉROS EN ATTENTE');
    expect(r.maskedText, '39314 NUMÉROS EN ATTENTE');
  });
}
