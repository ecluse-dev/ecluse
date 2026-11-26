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

  // P2-299 (décision du 26 novembre, point 3) : quand le mot voisin coupe le
  // signalement ordinaire, un avertissement distinct, moins pressant, le
  // remplace. Une garde ne rend jamais une donnée silencieuse.
  bool averti(RedactResult r) =>
      r.warnings.any((m) => m.contains("précédée d'un mot comme"));

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

  test("code d'accès dicté : avertissement distinct, jamais la valeur",
      () async {
    for (final t in [
      "Le code d'accès du local technique a changé, c'est maintenant $suite.",
      'Pour entrer, composez le code de la commande : $suite.',
      'Le digicode de la grille est $suite.',
      'Le mot de passe provisoire est $suite.',
      'Le PIN de la carte est $suite.',
      'Le mdp du wifi est $suite.',
    ]) {
      final r = await Ecluse.redact(t);
      expect(averti(r), isTrue, reason: t);
      final m = r.warnings.firstWhere((m) => m.contains("précédée d'un mot"));
      expect(m, contains('non masquée'), reason: t);
      expect(m, contains('à vérifier'), reason: t);
      // « un » est aussi l'article du message : seuls les autres mots comptent.
      for (final mot in suite.split(' ').where((m) => m != 'un')) {
        expect(m.toLowerCase(), isNot(contains(mot)), reason: t);
      }
    }
  });

  test('un seul avertissement distinct par texte, avec le compte', () async {
    final t = "Le code d'accès est $suite. Plus tard, le digicode est $suite.";
    final r = await Ecluse.redact(t);
    final m = r.warnings.where((m) => m.contains("précédée d'un mot comme"));
    expect(m.length, 1);
    expect(m.single, contains('2 passages'));
  });

  test(
      'sans mot voisin, la même suite reste signalée, sans avertissement '
      'distinct', () async {
    final r = await Ecluse.redact('Le tarif est de $suite.');
    expect(signale(r), isTrue);
    expect(averti(r), isFalse);
  });

  test('un libellé d\'identifiant garde le signalement', () async {
    for (final t in [
      'code IBAN fr $suite refusé',
      'Le code du compte bancaire est $suite.',
      'Mot de passe oublié, numéro de sécu : $suite.',
    ]) {
      final r = await Ecluse.redact(t);
      expect(signale(r), isTrue, reason: t);
      expect(averti(r), isFalse, reason: t);
    }
  });

  test('mot voisin à plus de 100 caractères : signalement conservé', () async {
    final loin = 'Le code est noté ailleurs. ${'Merci de votre aide. ' * 5}'
        'Le numéro est $suite.';
    final r = await Ecluse.redact(loin);
    expect(signale(r), isTrue);
    expect(averti(r), isFalse);
  });

  test('mot voisin à moins de 100 caractères, suite non recouverte', () async {
    final t = 'Le code est noté ailleurs. Merci de votre aide. '
        'Le numéro est $suite.';
    final r = await Ecluse.redact(t);
    expect(signale(r), isFalse);
    expect(averti(r), isTrue);
  });

  test('« pin » dans un mot plus long ne compte pas', () async {
    expect(
        signale(await Ecluse.redact('Les épinards coûtent $suite.')), isTrue);
  });
}
