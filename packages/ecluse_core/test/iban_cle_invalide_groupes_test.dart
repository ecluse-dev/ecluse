import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// P2-300 (décision du 26 novembre, point 1) : garde `iban_g45` de P2-272. Un
/// IBAN de forme française à clé fausse, écrit avec des séparateurs, n'est
/// masqué par `IbanCleInvalideDetector` que s'il est groupé comme un IBAN : 4-4-4-4-4-4-3,
/// RIB 4-5-5-11-2 ou 4-5-5-5-5-3. Sans séparateur, ou en paires derrière
/// « FR » + séparateur (P2-277), rien ne change. Pourquoi : « FR » + 25
/// caractères en groupes de trois, c'est surtout un code de pièce (10 des 14
/// masquages à tort du témoin durci de P2-268) ; le coût mesuré est de 40 IBAN
/// sur 40 de la sonde écrits ainsi, d'où l'avertissement de `Ecluse.redact`
/// (testé dans `ecluse_redact`). Les identifiants sont synthétiques, clé fausse.
void main() {
  const detecteur = IbanCleInvalideDetector();
  // Un même corps de 27 caractères, clé fausse, écrit de cinq façons.
  const quatre = 'FR24 2714 2872 6996 4N17 7449 410';
  const compact = 'FR242714287269964N177449410';
  const rib = 'FR24 27142 87269 964N1774494 10';
  const cinq = 'FR24 27142 87269 964N1 77449 410';
  const trois = 'FR2 427 142 872 699 64N 177 449 410';
  const paires = 'FR 24 27 14 28 72 69 96 4N 17 74 49 41 0';

  List<DetectedEntity> detecte(String iban) =>
      detecteur.detect("L'IBAN $iban a été refusé.");

  test('groupes usuels, compact, paires : masqués en entier à 0,3', () {
    for (final iban in [quatre, compact, rib, cinq, paires]) {
      final e = detecte(iban);
      expect(e, hasLength(1), reason: iban);
      expect(e.single.confidence, 0.3, reason: iban);
      expect(e.single.value, iban, reason: iban);
    }
  });

  test('groupes de trois : non masqué (garde iban_g45)', () {
    expect(detecte(trois), isEmpty);
  });

  test('autres séparateurs, mêmes groupes de trois : non masqué', () {
    for (final sep in ['-', '.', '/']) {
      expect(detecte(trois.replaceAll(' ', sep)), isEmpty, reason: sep);
    }
  });

  test('ecartes : le groupé en trois est rendu, avec ses bornes, pas la valeur',
      () {
    final texte = "L'IBAN $trois a été refusé.";
    final e = detecteur.ecartes(texte);
    expect(e, hasLength(1));
    expect(e.single.start, texte.indexOf(trois));
    expect(e.single.end, texte.indexOf(trois) + trois.length);
    expect(detecteur.ecartes("L'IBAN $quatre a été refusé."), isEmpty);
    expect(detecteur.ecartes("L'IBAN $compact a été refusé."), isEmpty);
  });
}
