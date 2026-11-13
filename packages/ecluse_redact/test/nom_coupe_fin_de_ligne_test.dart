import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Nom d'établissement ou de commune coupé par une fin de ligne (P2-173).
///
/// Un traitement de texte ou l'extraction d'un PDF coupent une ligne à
/// l'espace : « Centre⏎Hospitalier de Dole », « 70180 DAMPIERRE SUR⏎SALON ».
/// Les détecteurs d'établissement et d'adresse s'arrêtent au saut de ligne
/// (deux lignes sans rapport ne doivent pas fusionner), donc la suite du nom
/// restait en clair : 44 établissements à 90 colonnes et 13 communes à
/// 60 colonnes sur le corpus flou réaliste recoupé (`bench/ETAT.md`).
///
/// La fin de ligne n'est neutralisée que dans la vue de détection, et
/// seulement là où le nom continue visiblement : derrière un mot de liaison
/// (« de », « La », « SUR »), devant un mot de liaison en minuscules, ou entre
/// un mot-clé d'établissement et un nom propre qui n'ouvre pas une phrase.
/// Toutes les valeurs sont synthétiques.
void main() {
  String vis(String s) => s.replaceAll('\r', '\\r').replaceAll('\n', '⏎');

  /// (texte, ce qui doit avoir disparu du texte masqué)
  const etablissements = <(String, List<String>)>[
    // Coupure derrière un mot de liaison.
    ('Suivi au Centre Hospitalier de\nDole depuis mars.', ['Dole']),
    ('Accueil à la MAS des\nCoteaux ce jour.', ['MAS', 'Coteaux']),
    ('Admis à l\'IME La\nSource en 2019.', ['IME', 'Source']),
    ('Vu au SSIAD de\nGray hier.', ['SSIAD', 'Gray']),
    ('Travaille à l\'ESAT du\nVal depuis 2020.', ['ESAT', 'Val']),
    // Coupure juste après le mot-clé, la suite commence par une liaison.
    ('Transfert au CH\nde Vesoul demain.', ['Vesoul']),
    ('Travaille à l\'ESAT\ndu Val depuis 2020.', ['ESAT', 'Val']),
    ('Vu au SSIAD\nde Gray hier.', ['SSIAD', 'Gray']),
    ('Accueil à la MAS\ndes Coteaux ce jour.', ['MAS', 'Coteaux']),
    ('Opéré à la Clinique\ndu Parc en mai.', ['Clinique', 'Parc']),
    // Coupure juste après le mot-clé, la suite est un nom propre.
    ('Réside à l\'EHPAD\nLes Tilleuls depuis 2021.', ['EHPAD', 'Tilleuls']),
    ('Admis à l\'IME\nLa Source en 2019.', ['IME', 'Source']),
    ('Réside à la Résidence\nBellevue depuis 2021.', ['Bellevue']),
    // Coupure à l'intérieur d'un mot-clé de plusieurs mots.
    (
      'Suivi au Centre\nHospitalier de Dole depuis mars.',
      ['Hospitalier', 'Dole']
    ),
    (
      'Suivi au centre\nhospitalier de Dole depuis mars.',
      ['hospitalier', 'Dole']
    ),
    ('Entrée en Maison de\nretraite Les Lilas en juin.', ['retraite', 'Lilas']),
    ('Entrée en Maison\nde retraite Les Lilas en juin.', ['retraite', 'Lilas']),
    // Blancs autour de la fin de ligne, fin de ligne Windows.
    ('Transfert au CH \n de Vesoul demain.', ['Vesoul']),
    ('Transfert au CH\r\nde Vesoul demain.', ['Vesoul']),
    // Coupure plus loin dans le nom.
    ('Réside à la Résidence Les\nTilleuls depuis 2021.', ['Tilleuls']),
  ];

  group('établissement coupé par une fin de ligne', () {
    for (final (texte, absents) in etablissements) {
      test(vis(texte), () async {
        final r = await Ecluse.redact(texte);
        for (final mot in absents) {
          expect(r.maskedText, isNot(contains(mot)), reason: vis(r.maskedText));
        }
        expect(r.mapping.keys, contains('[ETABLISSEMENT_1]'));
        expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      });
    }
  });

  const communes = <(String, List<String>)>[
    (
      'Adresse : 45 Avenue du Général Leclerc, 70180 DAMPIERRE SUR\nSALON.',
      ['DAMPIERRE', 'SALON']
    ),
    (
      'Adresse : 7 Impasse des Charmilles, 70160 PORT SUR\nSAONE.',
      ['PORT', 'SAONE']
    ),
    ('Domicile : 70160 Port sur\nSaône.', ['Port', 'Saône']),
    ('Domicile : 70000 NOIDANS LES\nVESOUL.', ['NOIDANS', 'VESOUL']),
    ('Domicile : 25000 SAINT\nVIT.', ['VIT']),
    ('Domicile : 70180 DAMPIERRE SUR \r\n SALON.', ['DAMPIERRE', 'SALON']),
  ];

  group('commune coupée par une fin de ligne derrière un mot de liaison', () {
    for (final (texte, absents) in communes) {
      test(vis(texte), () async {
        final r = await Ecluse.redact(texte);
        for (final mot in absents) {
          expect(r.maskedText, isNot(contains(mot)), reason: vis(r.maskedText));
        }
        expect(r.mapping.keys, contains('[ADRESSE_1]'));
        expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      });
    }
  });

  group('contre-exemples : la ligne suivante reste en clair', () {
    /// (texte, ce qui doit rester visible dans le texte masqué)
    const intacts = <(String, List<String>)>[
      // La ligne suivante ouvre une phrase.
      ('Transfert au CH\nIl faudra prévoir un transport.', ['Il faudra']),
      ('Retour à l\'EHPAD\nLes résidents déjeunent à midi.', ['Les résidents']),
      ('Réunion au Foyer\nLa séance est levée à 17 h.', ['La séance']),
      ('Visite à la Clinique\nNous reprendrons demain.', ['Nous']),
      ('Courrier du CH\nCe document est confidentiel.', ['Ce document']),
      // Une ligne vide sépare deux paragraphes.
      ('Transfert au CH\n\nde nombreux Patients attendent.', ['Patients']),
      ('Entrée à l\'EHPAD\n\nLes Tilleuls sont en fleurs.', ['Tilleuls']),
      // Commune complète en fin de ligne : la ligne suivante est autre chose.
      ('Domicile : 70000 VESOUL\nSALON de coiffure fermé.', ['SALON']),
      ('Domicile : 39100 DOLE\nRendez-vous lundi.', ['Rendez-vous']),
      // « sur » hors d'un nom de commune.
      ('Total 70000 euros sur\nSalon et foire.', ['Salon']),
      // Mot-clé absent : rien à recoller.
      ('Il se rend de\nDole à Gray en train.', ['Dole', 'Gray']),
      ('Le centre de\nTri est fermé.', ['Tri']),
    ];
    for (final (texte, visibles) in intacts) {
      test(vis(texte), () async {
        final r = await Ecluse.redact(texte);
        for (final mot in visibles) {
          expect(r.maskedText, contains(mot), reason: vis(r.maskedText));
        }
        expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      });
    }

    test('une civilité en tête de ligne garde son jeton de nom', () async {
      const texte = 'Retour à l\'EHPAD\nMadame Odile Verdier est attendue.';
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, contains('[NOM_1]'));
      expect(r.maskedText, isNot(contains('Verdier')));
      expect(
          r.mapping.keys.where((k) => k.startsWith('[ETABLISSEMENT')), isEmpty);
    });
  });

  test('texte sans établissement ni code postal : sortie inchangée', () async {
    const texte = 'Première ligne de\nTexte ordinaire sur\nTrois lignes.';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, texte);
    expect(r.mapping, isEmpty);
  });

  test('coût linéaire : des milliers de lignes finissant par un mot-clé', () {
    // Meilleur de trois essais, deux tailles dans un rapport 4, seuil 8
    // (méthode de P2-100) : aucune borne absolue en millisecondes.
    Future<int> duree(int n) async {
      final texte = List.filled(n, 'Vu au CH de\nla ville voisine').join('\n');
      var meilleur = 1 << 62;
      for (var i = 0; i < 3; i++) {
        final sw = Stopwatch()..start();
        await Ecluse.detect(texte);
        sw.stop();
        if (sw.elapsedMicroseconds < meilleur) {
          meilleur = sw.elapsedMicroseconds;
        }
      }
      return meilleur;
    }

    return () async {
      await duree(200); // mise en route
      final petit = await duree(1000);
      final grand = await duree(4000);
      expect(grand / petit, lessThan(8),
          reason: 'petit $petit µs, grand $grand µs');
    }();
  });
}
