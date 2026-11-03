import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import '../bin/run_dossiers_bench.dart';

/// Le programme de mesure des dossiers rattache chaque entité à son jeton par
/// position. Si cette association se trompait, `bench/score_dossiers.py`
/// mesurerait autre chose que le moteur : on la vérifie contre la table de
/// restauration, qui est la vérité.
void main() {
  Future<void> verifie(String texte) async {
    final r = await Ecluse.redact(texte);
    final mentions = mentionsAvecJeton(r.maskedText, r.entities);
    expect(mentions, hasLength(r.entities.length), reason: texte);
    for (var i = 0; i < mentions.length; i++) {
      final e = r.entities[i];
      expect(mentions[i]['start'], e.start);
      expect(mentions[i]['end'], e.end);
      expect(r.maskedText, contains(mentions[i]['jeton'] as String));
      // Le jeton de la mention restaure la valeur de l'entité.
      expect(r.mapping[mentions[i]['jeton']], isNotNull, reason: texte);
    }
  }

  test('plusieurs entités de types différents dans un document', () async {
    await verifie('Contact : sophie.verdier@example.fr / 01 99 00 12 34\n'
        'Mme Sophie Verdier confirme. Mme Verdier rappelle.');
  });

  test('un jeton littéral du texte n\'est pas pris pour un jeton produit',
      () async {
    const texte = 'Brouillon : « [NOM_1] a confirmé ». Mme Sophie Verdier '
        'confirme.';
    final r = await Ecluse.redact(texte);
    final mentions = mentionsAvecJeton(r.maskedText, r.entities);
    expect(mentions, hasLength(r.entities.length));
    for (final m in mentions) {
      expect(m['jeton'], isNot('[NOM_1]'),
          reason: 'le jeton littéral est évité par le moteur');
    }
  });

  test('texte sans entité', () async {
    final r = await Ecluse.redact('Rien à signaler.');
    expect(mentionsAvecJeton(r.maskedText, r.entities), isEmpty);
  });
}
