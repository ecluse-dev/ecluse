import 'dart:math';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_redact/src/tokenizer.dart' show tolerantTokenPattern;
import 'package:test/test.dart';

/// Les avertissements « jeton littéral » d'un dossier (P2-25) doivent rester
/// ceux de la définition de référence : un jeton déjà attribué est signalé si
/// et seulement si `tolerantTokenPattern` le retrouve dans le texte. Le test
/// compare à cet oracle sur des variantes choisies et sur des textes tirés au
/// hasard (graine 42), pour pouvoir optimiser la recherche sans changer le
/// résultat.
const _tokens = ['[NOM_1]', '[NOM_2]', '[TELEPHONE_1]', '[EMAIL_1]'];

Future<Dossier> _dossierAvecJetons() async {
  final d = Dossier();
  await Ecluse.redact(
      'Mme Sophie Verdier et M. Jean Dupont, tél 01 99 00 12 34, '
      'mail s.verdier@example.fr',
      dossier: d);
  return d;
}

Set<String> _signales(RedactResult r) => {
      for (final w in r.warnings)
        for (final t in _tokens)
          if (w.contains('en clair $t (')) t
    };

Set<String> _oracle(String texte) => {
      for (final t in _tokens)
        if (tolerantTokenPattern(t).hasMatch(texte)) t
    };

void main() {
  const variantes = [
    'Rien ici.',
    'Voir [NOM_1] seul.',
    'Voir [ nom_1 ] déformé.',
    'Voir [NOM 1] et [NOM__2].',
    'Voir [NOM1] sans soulignement.',
    'Voir [NOM_10] : pas [NOM_1].',
    'Ouvert [NOM_1 jamais fermé',
    'Fermé seulement NOM_1] ici.',
    'Imbriqué [[NOM_1]] et [ [EMAIL_1] ].',
    'Sur\n[TELE\nPHONE_1] plusieurs lignes, [\nEMAIL_1\n] aussi.',
    '[TELEPHONE_1][EMAIL_1][NOM_2]',
    'Crochets sans jeton [a] [] [ ] [1] et [NOM_X].',
    '',
  ];

  for (final texte in variantes) {
    test('variante « ${texte.replaceAll('\n', '⏎')} »', () async {
      final d = await _dossierAvecJetons();
      final r = await Ecluse.redact(texte, dossier: d);
      expect(_signales(r), _oracle(texte));
    });
  }

  test('textes aléatoires (graine 42)', () async {
    final rng = Random(42);
    const morceaux = [
      '[',
      ']',
      '[NOM_1]',
      '[ Nom 2 ]',
      '[EMAIL_1]',
      '[TELEPHONE',
      '_1]',
      ' ',
      '\n',
      'NOM',
      '_',
      '1',
      '2',
      'mot',
      '[ ]',
      '[[',
      ']]',
      '[nom1]',
    ];
    final d = await _dossierAvecJetons();
    for (var i = 0; i < 300; i++) {
      final texte = [
        for (var k = 0; k < 1 + rng.nextInt(12); k++)
          morceaux[rng.nextInt(morceaux.length)]
      ].join();
      final r = await Ecluse.redact(texte, dossier: d);
      expect(_signales(r), _oracle(texte), reason: 'texte : $texte');
    }
  });
}
