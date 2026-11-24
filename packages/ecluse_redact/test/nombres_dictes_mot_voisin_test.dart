import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-282 : un mot voisin (« code », « digicode », « mot de passe », « mdp »,
/// « pin ») dans les 100 caractères avant une suite dictée coupe le
/// signalement « nombre dicté non reconnu », sauf si un libellé d'identifiant
/// (« iban », « nir », « compte »…) l'accompagne dans la même fenêtre.
///
/// Pourquoi : un code d'accès dicté chiffre par chiffre ressemble, mot à mot,
/// à un identifiant abîmé ; mesure P2-280, 49 phrases ordinaires signalées à
/// tort sur 630. Le libellé garde le signalement de « code IBAN … » : un
/// identifiant ne doit jamais passer sans avertissement (règle 4). Tous les
/// textes sont synthétiques.
void main() {
  bool signale(RedactResult r) =>
      r.warnings.any((m) => m.contains('nombre dicté non reconnu'));

  const suite = 'six zéro cinq six un six sept six sept';

  test("code d'accès dicté : pas de signalement", () async {
    for (final t in [
      "Le code d'accès du local technique a changé, c'est maintenant $suite.",
      'Pour entrer, composez le code de la commande : $suite.',
      'Le digicode de la grille est $suite.',
      'Le mot de passe provisoire est $suite.',
      'Le PIN de la carte est $suite.',
      'Le mdp du wifi est $suite.',
    ]) {
      expect(signale(await Ecluse.redact(t)), isFalse, reason: t);
    }
  });

  test('sans mot voisin, la même suite reste signalée', () async {
    expect(signale(await Ecluse.redact('Le tarif est de $suite.')), isTrue);
  });

  test('un libellé d\'identifiant garde le signalement', () async {
    for (final t in [
      'code IBAN fr $suite refusé',
      'Le code du compte bancaire est $suite.',
      'Mot de passe oublié, numéro de sécu : $suite.',
    ]) {
      expect(signale(await Ecluse.redact(t)), isTrue, reason: t);
    }
  });

  test('mot voisin à plus de 100 caractères : signalement conservé', () async {
    final loin = 'Le code est noté ailleurs. ${'Merci de votre aide. ' * 5}'
        'Le numéro est $suite.';
    expect(signale(await Ecluse.redact(loin)), isTrue);
  });

  test('mot voisin à moins de 100 caractères, suite non recouverte', () async {
    final t = 'Le code est noté ailleurs. Merci de votre aide. '
        'Le numéro est $suite.';
    expect(signale(await Ecluse.redact(t)), isFalse);
  });

  test('« pin » dans un mot plus long ne compte pas', () async {
    expect(
        signale(await Ecluse.redact('Les épinards coûtent $suite.')), isTrue);
  });
}
