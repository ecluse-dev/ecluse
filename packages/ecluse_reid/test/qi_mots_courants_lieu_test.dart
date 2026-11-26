import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Mots courants lus comme une commune (P2-302, décision du 26 novembre,
/// point 6 ; mesure : `agent/specs/P2-287.md`).
///
/// « Son numéro… » était lu comme la commune de Son (F = 89) et un seul mot
/// courant de ce genre en tête de phrase faisait passer un rapport de
/// `evalue` à `nonEvaluable`. Chemin : `ecluse_reid` seul ; le chiffre
/// `Ecluse.redact` est dans la description de la PR et dans `bench/ETAT.md`.
///
/// Textes et noms synthétiques ; les communes sont celles de la référence
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

  // Les 15 mots de la sonde de P2-287 qui étaient lus comme un lieu.
  const sonde = [
    'Aucun', 'Contre', 'Cours', 'Doux', 'Fontaine', 'Grand', 'Long', 'Mont', //
    'Place', 'Rue', 'Salles', 'Son', 'Vaux', 'Vers', 'Vieux',
  ];
  // Les autres mots observés dans les corpus du dépôt (P2-287 § 3).
  const observes = [
    'ARS',
    'Avril',
    'Linge',
    'Le Plan',
    'La Réunion',
  ];

  group('prémisse : ces mots sont bien des communes de la référence', () {
    for (final m in [...sonde, ...observes]) {
      test(m, () => expect(ref.geo.communesByName(m), isNotEmpty));
    }
  });

  group('un mot courant en tête de phrase n\'est pas un lieu', () {
    for (final m in [...sonde, ...observes]) {
      test('« $m »', () {
        expect(
            lieux('$m numéro de sécurité sociale doit être vérifié.'), isEmpty);
        expect(lieux('Le dossier est complet. $m était à jour hier.'), isEmpty);
        // Casse de titre et capitales, comme dans les corpus du dépôt.
        expect(lieux('PLANNING DES ${m.toUpperCase()} du mois'), isEmpty);
      });
    }

    test('au milieu d\'un titre en casse de titre', () {
      expect(lieux('Compte Rendu De La Réunion'), isEmpty);
      expect(lieux('Planning Des Salles'), isEmpty);
      expect(lieux('Contacter ARS pour la suite.'), isEmpty);
    });

    test('la forme minuscule n\'est jamais lue (inchangé)', () {
      expect(lieux('Elle vérifie son numéro.'), isEmpty);
    });
  });

  group('un vrai lieu reste un lieu', () {
    const cas = <(String, List<String>)>[
      ('Mme Camille Faure, 45 ans, infirmière à Rioz.', ['Rioz']),
      ('Elle habite à Dijon.', ['Dijon']),
      // Le mot de la liste, derrière un locatif en minuscules : un lieu.
      ('Il est né à La Réunion.', ['La Réunion']),
      ('Elle habite à Fontaine.', ['Fontaine']),
      ('Ils vivent en Mont.', ['Mont']),
      ('Originaire de Salles.', ['Salles']),
      // Hors liste : une vraie commune lue comme telle (P2-175).
      ('Mme Verdier, Chevrier (74).', ['Chevrier']),
    ];
    for (final (texte, attendus) in cas) {
      test(texte, () => expect(lieux(texte), attendus));
    }
  });

  group('rapport : un mot courant ne fait plus perdre l\'évaluation', () {
    const base = 'Mme Camille Faure, 45 ans, infirmière à Rioz.';
    test('prémisse : sans phrase, le rapport est évalué', () {
      expect(evaluateText(ref, base).statut, EvaluationStatut.evalue);
    });
    for (final m in [
      'Son',
      'Aucun',
      'Mont',
      'Cours',
      'Salles',
      'Vers',
      'Contre'
    ]) {
      test('avec une phrase commençant par « $m »', () {
        final e = evaluateText(
            ref, '$base $m numéro de sécurité sociale doit être vérifié.');
        expect(e.statut, EvaluationStatut.evalue);
        expect([
          for (final s in e.spans)
            if (s.type == QiType.lieu) s.text,
        ], [
          'Rioz'
        ]);
      });
    }
  });

  test('la liste est une constante documentée et extensible', () {
    expect(motsCourantsSansLieu, containsAll(['son', 'aucun', 'la réunion']));
    expect(motsCourantsSansLieu.every((m) => m == m.toLowerCase()), isTrue);
  });
}
