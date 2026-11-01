import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Forme « Nom, Prénom » (P2-74), usuelle dans les listes, les fiches et les
/// états d'effectifs. Le patronyme qui précède la virgule restait en clair :
/// « Marchetti, Odette (née Rossi) » donnait « Marchetti, [NOM_1] (née [NOM_2]) ».
/// Le mot capitalisé avant la virgule est couvert si le prénom est suivi d'une
/// ponctuation, d'une parenthèse, d'un chiffre ou de la fin de ligne ; jamais
/// derrière une formule d'adresse (« Bonjour, Odette ») ni si une phrase continue
/// en minuscules (« Rappel, Odette doit venir »).
void main() {
  const masques = {
    'Marchetti, Odette (née Rossi)': 'Marchetti',
    'Dossier n° 2024-18 : Marchetti, Odette': 'Marchetti',
    'MARCHETTI, Odette': 'MARCHETTI',
    'Marchetti, Odette, 83 ans': 'Marchetti',
    'Marchetti, Odette\nDurand, Marie': 'Durand',
    'Liste : Dupont, Pierre ; Durand, Marie ; Rey, Léa.': 'Dupont',
    'Fabre, Corinne - chambre 12': 'Fabre',
    'Fabre, Corinne 1958': 'Fabre',
    'Marchetti, Odette': 'Marchetti',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('« Marchetti, Odette » et « Odette Marchetti » : une seule personne',
      () async {
    final r = await Ecluse.redact(
        'Marchetti, Odette (83 ans). Odette Marchetti a signé.');
    expect(r.mapping.length, 1, reason: r.maskedText);
  });

  const intacts = {
    'Bonjour, Odette.': 'Bonjour',
    'Merci, Odette, pour votre retour.': 'Merci',
    'Cordialement, Odette': 'Cordialement',
    'Rappel, Odette doit venir demain.': 'Rappel',
    'Oui, Pierre est là.': 'Oui',
    'Alors, Marie arrive.': 'Alors',
    'Paris, Pierre est venu hier.': 'Paris',
    'Bien, Pierre viendra': 'Bien',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
