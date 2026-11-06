import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Adresses et établissements dans un texte sans aucune majuscule (P2-120).
/// Mesure P2-117 : 100 % de fuite des deux avant ce détecteur.
List<String> _trouve(MinusculesRecapitaliseDetector d, String texte) => [
      for (final e in d.detect(texte)) texte.substring(e.start, e.end),
    ];

const _adresse = MinusculesRecapitaliseDetector(AdresseDetector(),
    communesSeules: true, capitales: false);
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

  group('voie sans code postal après un indice (P2-131)', () {
    test('« située », « demeurant », « adresse … : »', () {
      for (final (texte, voie) in [
        (
          'la clinique, située 30 boulevard aristide briand, ouvre',
          '30 boulevard aristide briand'
        ),
        ('domicilié 3 route de vellexon depuis mai', '3 route de vellexon'),
        ('adresse du chantier :\n8 chemin des vignes', '8 chemin des vignes'),
      ]) {
        expect(_trouve(_adresse, texte).join(' | '), contains(voie),
            reason: texte);
      }
    });

    test('sans indice, « 3 chemin de fer » reste intact', () {
      expect(_trouve(_adresse, '3 chemin de fer'), isEmpty);
      expect(_trouve(_adresse, '12 place disponible'), isEmpty);
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

  group('texte entièrement en capitales (P2-122)', () {
    test('montant et référence : pas une adresse', () async {
      for (final texte in [
        "LE DEVIS S'ÉLÈVE À 70000 EUROS HORS TAXES.",
        "LA RÉFÉRENCE EST 75015 POUR L'ANTENNE PARISIENNE.",
      ]) {
        final r = await Ecluse.redact(texte);
        expect(r.entities, isEmpty, reason: texte);
      }
    });

    test('adresse en capitales : lue par AdresseDetector lui-même', () {
      const texte = '12 RUE DES LILAS, 75015 PARIS';
      expect(_adresse.detect(texte), isEmpty);
      expect(const AdresseDetector().detect(texte), hasLength(1));
      expect(const AdresseDetector().detect('70000 EUROS HORS TAXES'), isEmpty);
    });

    test('élision en tête de commune dans le texte d\'ombre', () {
      expect(
          MinusculesRecapitaliseDetector.ombre("25250 l'isle-sur-le-doubs",
              seulementCommunes: true),
          "25250 L'Isle-sur-le-Doubs");
    });

    test('établissement en capitales', () {
      expect(_trouve(_etab, "RÉUNION À L'EHPAD MARIE CURIE."),
          ['EHPAD MARIE CURIE']);
    });
  });

  test('Ecluse.redact masque adresse et établissement en minuscules', () async {
    final r = await Ecluse.redact(
        'visite à domicile au 7 impasse des charmilles, 70160 port sur saone, '
        "puis réunion à l'ehpad marie curie");
    expect(r.maskedText, isNot(contains('charmilles')));
    expect(r.maskedText, isNot(contains('marie curie')));
  });
}
