import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-300 (décision du 26 novembre, points 0 et 1) : la garde `iban_g45`
/// retire le masquage d'un IBAN à clé fausse écrit en groupes inhabituels (de
/// trois par exemple) ; une garde ne rend jamais une donnée silencieuse, donc
/// `Ecluse.redact` le signale « à vérifier », sans la valeur. Tous les textes
/// sont synthétiques, clé volontairement fausse.
void main() {
  const trois = 'FR2 427 142 872 699 64N 177 449 410';
  const quatre = 'FR24 2714 2872 6996 4N17 7449 410';
  final motif = RegExp(r'IBAN à clé fausse.*non masqué.*à vérifier');

  Iterable<String> avertissements(RedactResult r) =>
      r.warnings.where(motif.hasMatch);

  test('groupes de trois : non masqué, avertissement sans la valeur', () async {
    final texte = 'Merci de recopier $trois dans la case prévue.';
    final r = await Ecluse.redact(texte);
    expect(r.entities.where((e) => e.type == EntityType.iban), isEmpty);
    final a = avertissements(r).toList();
    expect(a, hasLength(1));
    expect(a.single, contains('1 occurrence'));
    for (final morceau in trois.split(' ')) {
      expect(a.single, isNot(contains(morceau)));
    }
  });

  test('compte et positions de plusieurs occurrences', () async {
    final r = await Ecluse.redact('Pièce $trois puis pièce $trois.');
    final a = avertissements(r).toList();
    expect(a, hasLength(1));
    expect(a.single, contains('2 occurrences'));
  });

  test('groupes de quatre : masqué en entier, pas d\'avertissement de garde',
      () async {
    final r = await Ecluse.redact("L'IBAN $quatre a été refusé.");
    expect(r.entities.where((e) => e.type == EntityType.iban), hasLength(1));
    expect(avertissements(r), isEmpty);
  });

  test('texte sans IBAN : rien', () async {
    final r = await Ecluse.redact('Réunion lundi à 14 h, salle 3.');
    expect(avertissements(r), isEmpty);
  });

  test('même avec un libellé (« IBAN : »), le passage reste signalé', () async {
    // Limite écrite dans `LIMITES.md` : la garde ne regarde pas le libellé. Un
    // IBAN à clé fausse en groupes de trois derrière « IBAN : » n'est plus masqué
    // en entier ; l'avertissement est ce qui reste.
    final r = await Ecluse.redact('IBAN : $trois');
    expect(r.maskedText, contains(trois.substring(0, 8)));
    expect(avertissements(r), hasLength(1));
  });
}
