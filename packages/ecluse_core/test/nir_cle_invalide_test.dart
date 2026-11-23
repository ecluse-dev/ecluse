import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// P2-258 : NIR à clé fausse, ou lu avec « O » pour « 0 ». Valeurs
/// synthétiques : corps 2 85 05 78 006 084 (clé juste 41), corps corse
/// 1 85 2A 123 456 (clé calculée plus bas).
void main() {
  const detecteur = NirCleInvalideDetector();

  group('NirCleInvalideDetector', () {
    test('clé fausse : une entité nir, confiance 0,3, empan entier', () {
      const nir = '2 85 05 78 006 084 46';
      final texte = 'Saisie erronée : $nir rejetée.';
      final e = detecteur.detect(texte);
      expect(e, hasLength(1));
      expect(e.single.type, EntityType.nir);
      expect(e.single.confidence, NirCleInvalideDetector.confidence);
      expect(texte.substring(e.single.start, e.single.end), nir);
    });

    test('clé fausse, séparateurs variés et espaces insécables', () {
      for (final nir in [
        '285057800608446',
        '2.85.05.78.006.084.46',
        '2-85-05-78-006-084-46',
        '2 85 05 78 006 084 46',
      ]) {
        final e = detecteur.detect('n° $nir.');
        expect(e, hasLength(1), reason: nir);
        expect(e.single.value, nir);
      }
    });

    test('NIR valide : rien (déjà couvert à confiance 1,0)', () {
      expect(detecteur.detect('NIR 2 85 05 78 006 084 41'), isEmpty);
      expect(const NirDetector().detect('NIR 2 85 05 78 006 084 41'),
          hasLength(1));
    });

    test('lettre O à la place d\'un zéro : clé fausse masquée, clé juste non',
        () {
      expect(detecteur.detect('2 85 O5 78 OO6 084 46'), hasLength(1));
      // Clé juste (41) avec lettres : jamais émis ici ni par le détecteur
      // strict, comme avant (P2-191 : « sans libellé, jamais accepté »).
      expect(const NirDetector().detect('2 85 O5 78 OO6 084 41'), isEmpty);
      expect(detecteur.detect('2 85 O5 78 OO6 084 41'), isEmpty);
      expect(detecteur.detect('2 85 o5 78 oo6 084 4l'), isEmpty,
          reason: 'la lettre l n\'est pas admise à la place de 1');
    });

    test('Corse 2A / 2B avec clé fausse', () {
      expect(detecteur.detect('1 85 05 2A 123 456 00'), hasLength(1));
      expect(detecteur.detect('1 85 05 2B 123 456 00'), hasLength(1));
    });

    test('rejets : sexe 3 à 8, mois 13, département 00, ordre 000', () {
      for (final texte in [
        '3 85 05 78 006 084 46',
        '8 85 05 78 006 084 46',
        '2 85 13 78 006 084 46',
        '2 85 05 00 006 084 46',
        '2 85 05 78 006 000 46',
      ]) {
        expect(detecteur.detect(texte), isEmpty, reason: texte);
      }
    });

    test('rejets : nombre plus long ou plus court, collé à un chiffre', () {
      expect(detecteur.detect('2850578006084461'), isEmpty);
      expect(detecteur.detect('28505780060844'), isEmpty);
      expect(detecteur.detect('12285057800608446'), isEmpty);
    });

    test('un RPPS suivi d\'un nombre n\'est pas avalé en « NIR » (P2-174)', () {
      for (final texte in [
        'RPPS 10192209566 1250 places',
        'Prescripteur 17931 83997 5 1250 séances',
      ]) {
        expect(detecteur.detect(texte), isEmpty, reason: texte);
      }
    });

    test('coupures hors des groupes d\'un NIR : refusées, collé : accepté', () {
      expect(detecteur.detect('2850 5780 0608 446'), isEmpty);
      expect(detecteur.detect('285057800608446'), hasLength(1));
      expect(detecteur.detect('2 850578006084 46'), hasLength(1));
    });

    test('positions exactes dans le texte d\'origine', () {
      const avant = 'Dossier ';
      const nir = '2 85 05 78 006 084 46';
      final e = detecteur.detect('$avant$nir et la suite');
      expect(e.single.start, avant.length);
      expect(e.single.end, avant.length + nir.length);
    });

    test('aucune valeur du texte dans la représentation de l\'entité', () {
      final e = detecteur.detect('2 85 05 78 006 084 46');
      expect(e.single.confidence, 0.3);
    });

    test('P2-263 : cinq groupes de trois, séparateurs . - / ou espaces', () {
      for (final nir in [
        '285.057.800.608.446',
        '285-057-800-608-446',
        '285/057/800/608/446',
        '285 057 800 608 446',
      ]) {
        final e = detecteur.detect('n° $nir.');
        expect(e, hasLength(1), reason: nir);
        expect(e.single.value, nir);
      }
    });

    test(
        'P2-263 : 3 × 5 seulement si les quatre coupures sont aux rangs 3, 6, 9, 12',
        () {
      for (final t in [
        '285.057.800.60.8446', // coupures à 3, 6, 9, 11
        '285.057800.608.446', // trois coupures
        '2850.578.006.084.46', // coupure à 4
      ]) {
        expect(detecteur.detect('n° $t.'), isEmpty, reason: t);
      }
    });

    test(
        'P2-263 : coupures libres, sauf après un identifiant court de Luhn juste',
        () {
      const libre = NirCleInvalideDetector(coupuresLibres: true);
      // Coupure à 8 chiffres : refusée à coupures strictes, admise ici.
      expect(detecteur.detect('n° 28505780 0608446.'), isEmpty);
      expect(libre.detect('n° 28505780 0608446.'), hasLength(1));
      // RPPS de Luhn juste (onze chiffres) puis quatre chiffres : jamais un NIR.
      expect(libre.detect('RPPS 10192209566 1250 places'), isEmpty);
    });
  });
}
