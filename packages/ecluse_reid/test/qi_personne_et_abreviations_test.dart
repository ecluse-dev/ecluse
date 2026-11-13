import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Lieux extraits à tort et professions abrégées (P2-175).
///
/// 1. Un patronyme qui est aussi le nom d'une commune (« Chevrier »,
///    Haute-Savoie) était extrait comme lieu derrière une civilité ou un
///    métier : les 43 et 33 lieux à tort des corpus QI réaliste et
///    adversarial (`bench/ETAT.md`), tous de cette forme. Chemin :
///    `ecluse_reid` seul ; par `Ecluse.redact` le nom est masqué avant
///    l'évaluation, sauf derrière un métier sans civilité.
/// 2. « pneumo », « gynéco » et « pediatre » sans accent n'étaient pas lus
///    comme une profession (7 manquées sur 183 dans l'adversarial).
///
/// Noms de personnes synthétiques ; les communes sont celles de la référence
/// publique embarquée.
void main() {
  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  List<String> lieux(String texte) => [
        for (final s in extractQiSpans(ref, texte).spans)
          if (s.type == QiType.lieu) s.text,
      ];
  List<String> professions(String texte) => [
        for (final s in extractQiSpans(ref, texte).spans)
          if (s.type == QiType.profession) s.qi!.value,
      ];

  test('prémisse : « Chevrier » est bien une commune de la référence', () {
    expect(lieux('Elle habite à Chevrier.'), ['Chevrier']);
  });

  group('un patronyme homonyme d\'une commune n\'est pas un lieu', () {
    const cas = <(String, List<String>)>[
      ('Compte rendu. Monsieur Chevrier réside à Lille.', ['Lille']),
      ('Note de suivi. M. Chevrier réside à Nantes.', ['Nantes']),
      ('Note de suivi. Mme Chevrier, 83 ans, est suivie.', []),
      ('Madame Chevrier est sage-femme à Dole.', ['Dole']),
      ('Mademoiselle Chevrier est ophtalmologue à Vesoul.', ['Vesoul']),
      ('Le Dr Chevrier, ophtalmologue à Dijon.', ['Dijon']),
      ('Le Docteur Chevrier exerce à Dijon.', ['Dijon']),
      ('Mademoiselle Camille Chevrier, 42 ans, domiciliée à Dole.', ['Dole']),
      ('M. Marc Chevrier, 72 ans, domicilié à Vesoul.', ['Vesoul']),
      ('Mme Céline Chevrier, 48 ans.', []),
      ("L'aide-soignante Chevrier, 34 ans, travaille à Vesoul.", ['Vesoul']),
      ("L'ergothérapeute Chevrier, 41 ans, travaille à Dole.", ['Dole']),
      ('La diététicienne Chevrier travaille à Dole.', ['Dole']),
      ('Le directeur Chevrier a signé.', []),
    ];
    for (final (texte, attendus) in cas) {
      test(texte, () => expect(lieux(texte), attendus));
    }
  });

  group('une commune reste un lieu', () {
    const cas = <(String, List<String>)>[
      ('Mme Verdier habite Chevrier.', ['Chevrier']),
      ('Mme Verdier, née à Chevrier.', ['Chevrier']),
      ('Mme Verdier, Chevrier (74).', ['Chevrier']),
      ('M. Perrot. Chevrier est sa commune.', ['Chevrier']),
      ('Suivi par la commune de Chevrier.', ['Chevrier']),
      ('Il travaille dans la commune Chevrier.', ['Chevrier']),
      ('Il connaît le village Chevrier.', ['Chevrier']),
      ('Madame Verdier vit à Dijon.', ['Dijon']),
      ('Le Dr Perrot, Dijon.', ['Dijon']),
      ('Consultation à Vesoul puis Dole.', ['Vesoul', 'Dole']),
    ];
    for (final (texte, attendus) in cas) {
      test(texte, () => expect(lieux(texte), attendus));
    }
  });

  group('professions abrégées ou sans accent', () {
    const cas = <(String, String)>[
      ('Le Dr Perrot, pneumo à Rennes.', '11'),
      ('Le Dr Perrot, gynéco à Vesoul.', '09'),
      ('Le Dr Perrot, gyneco à Vesoul.', '09'),
      ('Le Dr Mérieux, pediatre à Poitiers.', '10'),
      ('Le Dr Mérieux, PEDIATRE à Poitiers.', '10'),
      ('Elle est generaliste à Dole.', '01'),
      ('Il est anesthesiste à Dole.', '05'),
      ('Elle est gynecologue à Dole.', '09'),
    ];
    for (final (texte, code) in cas) {
      test(texte, () => expect(professions(texte), [code]));
    }

    const sansProfession = [
      'Pneumonie traitée à Rennes.',
      'Suivi en pneumologie à Rennes.',
      'Une pneumopathie est suspectée.',
      'Consultation de gynécologie.',
      'Le service de pédiatrie de Dole.',
    ];
    for (final texte in sansProfession) {
      test('pas une profession : $texte',
          () => expect(professions(texte), isEmpty));
    }

    test('« pneumologue » ne compte qu\'une fois', () {
      expect(professions('Elle est pneumologue à Dole.'), ['11']);
    });
  });
}
