import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Variantes réalistes relevées à la relecture d'octobre 2026 (P1-25) : chacune
/// laissait l'information en clair. Chaque test vérifie le span exact.
void main() {
  String masque(EntityDetector d, String texte) {
    final entities = d.detect(texte);
    expect(entities, hasLength(1), reason: texte);
    return texte.substring(entities.single.start, entities.single.end);
  }

  group('dates de naissance', () {
    const d = DateNaissanceDetector();
    const cas = {
      'né le 1er mars 1985': '1er mars 1985',
      'née le 1er janvier 1985': '1er janvier 1985',
      'Né le : 12/03/1985': '12/03/1985',
      'né le: 12/03/1985': '12/03/1985',
      'né à Paris le 12/03/1985': '12/03/1985',
      'née à Saint-Denis le 3 mai 1990': '3 mai 1990',
      'né le 12/03/85': '12/03/85',
      'Naissance : 12/03/1985': '12/03/1985',
      'DOB 12/03/1985': '12/03/1985',
      'DOB: 12/03/1985': '12/03/1985',
      'né le 1985-03-12': '1985-03-12',
      'né le 12 mars 1985': '12 mars 1985',
      'né le 12/03/1985': '12/03/1985',
    };
    cas.forEach((texte, attendu) {
      test(texte.replaceAll(' ', '<NBSP>'), () {
        expect(masque(d, 'Patient $texte, suivi.'), attendu);
      });
    });

    test('date sans contexte de naissance -> non détectée', () {
      expect(d.detect('Réunion le 12/03/1985 à 10 h.'), isEmpty);
      expect(d.detect('Rapport du 1985-03-12.'), isEmpty);
    });

    test('« né » à la fin d\'un autre mot -> non détecté', () {
      expect(d.detect('Document donné le 12/03/1985 au greffe.'), isEmpty);
    });

    test('« naissance » sans deux-points ni date -> non détecté', () {
      expect(d.detect('La naissance du projet date de 2020.'), isEmpty);
    });
  });

  group('établissements', () {
    const d = EtablissementDetector();
    const cas = {
      'CHU de Nantes': 'CHU de Nantes',
      'CHU Nantes': 'CHU Nantes',
      'CHRU de Lille': 'CHRU de Lille',
      'Maison de retraite Les Lilas': 'Maison de retraite Les Lilas',
      'centre hospitalier de Nantes': 'centre hospitalier de Nantes',
      "Foyer d'accueil médicalisé Les Pins":
          "Foyer d'accueil médicalisé Les Pins",
      'EHPAD "Les Tilleuls"': 'EHPAD "Les Tilleuls"',
      'Résidence « Les Pins »': 'Résidence « Les Pins »',
      'Institut Médico-Éducatif Les Pins': 'Institut Médico-Éducatif Les Pins',
    };
    cas.forEach((texte, attendu) {
      test(texte, () {
        expect(masque(d, 'Hébergé au $texte depuis 2019.'), attendu);
      });
    });

    test('mots courants en minuscules -> non détectés', () {
      expect(d.detect('Le centre de la ville est fermé.'), isEmpty);
      expect(d.detect('Une maison de retraite agréable.'), isEmpty);
    });
  });

  group('téléphones', () {
    const d = TelephoneDetector();
    const cas = {
      '(06) 12 34 56 78': '(06) 12 34 56 78',
      '06/12/34/56/78': '06/12/34/56/78',
      '0612 345 678': '0612 345 678',
      '00 33 6 12 34 56 78': '00 33 6 12 34 56 78',
    };
    cas.forEach((texte, attendu) {
      test(texte, () {
        expect(masque(d, 'Tel : $texte, merci.'), attendu);
      });
    });

    test('dates et montants proches -> non détectés', () {
      expect(d.detect('Le 12/03/2024 à 10 h, soit 1 234 567 euros.'), isEmpty);
    });
  });

  group('adresses', () {
    const d = AdresseDetector();
    const cas = {
      '12 bis rue des Lilas, 75015 Paris': '12 bis rue des Lilas, 75015 Paris',
      '12bis rue des Lilas, 75015 Paris': '12bis rue des Lilas, 75015 Paris',
      '5 av. Foch, 75116 Paris': '5 av. Foch, 75116 Paris',
      '5 bd Victor Hugo, 06000 Nice': '5 bd Victor Hugo, 06000 Nice',
      "12 chaussée d'Antin, 75009 Paris": "12 chaussée d'Antin, 75009 Paris",
      '3 faubourg Saint-Honoré, 75008 Paris':
          '3 faubourg Saint-Honoré, 75008 Paris',
      'rue des Lilas, 75015 Paris': 'rue des Lilas, 75015 Paris',
      '12 rue des Lilas, 75015 Paris': '12 rue des Lilas, 75015 Paris',
    };
    cas.forEach((texte, attendu) {
      test(texte.replaceAll(' ', '<NBSP>'), () {
        expect(masque(d, 'Habite $texte et travaille.'), attendu);
      });
    });

    test('« rue » dans une phrase sans code postal -> non détecté', () {
      expect(d.detect('Il traverse la rue des Lilas.'), isEmpty);
    });
  });
}
