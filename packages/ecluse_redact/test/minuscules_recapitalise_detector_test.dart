import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Adresses et établissements dans un texte sans aucune majuscule (P2-120).
/// Mesure P2-117 : 100 % de fuite des deux avant ce détecteur.
List<String> _trouve(MinusculesRecapitaliseDetector d, String texte) => [
      for (final e in d.detect(texte)) texte.substring(e.start, e.end),
    ];

const _adresse =
    MinusculesRecapitaliseDetector(AdresseDetector(), communesSeules: true);
const _etab = MinusculesRecapitaliseDetector(EtablissementDetector());

void main() {
  group('texte d\'ombre', () {
    test('même longueur, mots capitalisés, mots outils et sigles', () {
      const texte = "l'ehpad marie curie, 70160 port sur saone";
      final ombre = MinusculesRecapitaliseDetector.ombre(texte)!;
      expect(ombre.length, texte.length);
      expect(ombre, "l'EHPAD Marie Curie, 70160 Port sur Saone");
    });
  });

  test('adresses : seule la commune après un code postal', () {
    expect(
        MinusculesRecapitaliseDetector.ombre('3 chemin de fer, 70000 vesoul',
            seulementCommunes: true),
        '3 chemin de fer, 70000 Vesoul');
  });

  group('adresses', () {
    test('voie et code postal + commune, positions exactes', () {
      const texte = 'demeurant 12 rue des quatre vents, 70000 vesoul, depuis';
      expect(
          _trouve(_adresse, texte), ['12 rue des quatre vents, 70000 vesoul']);
      final e = _adresse.detect(texte).single;
      expect(e.value, texte.substring(e.start, e.end));
    });

    test('montant et référence : pas une adresse', () {
      expect(_trouve(_adresse, "le devis s'élève à 70000 euros hors taxes"),
          isEmpty);
      expect(
          _trouve(_adresse, "la référence est 75015 pour l'antenne"), isEmpty);
      expect(_trouve(_adresse, 'environ 21000 dossiers et 39100 numéros'),
          isEmpty);
    });
  });

  group('établissements', () {
    test('mot-clé suivi de son nom', () {
      expect(_trouve(_etab, "réunion tenue à l'ehpad marie curie. à revoir"),
          ['ehpad marie curie']);
    });
  });

  test('texte avec une majuscule : rien, les détecteurs habituels suffisent',
      () {
    expect(
        _trouve(_adresse, 'Demeurant 12 rue des Lilas, 70000 Vesoul'), isEmpty);
    expect(_trouve(_etab, "Réunion à l'EHPAD Marie Curie"), isEmpty);
  });

  test('Ecluse.redact masque adresse et établissement en minuscules', () async {
    final r = await Ecluse.redact(
        'visite à domicile au 7 impasse des charmilles, 70160 port sur saone, '
        "puis réunion à l'ehpad marie curie");
    expect(r.maskedText, isNot(contains('charmilles')));
    expect(r.maskedText, isNot(contains('marie curie')));
  });
}
