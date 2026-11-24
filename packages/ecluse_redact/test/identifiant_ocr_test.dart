import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_redact/src/heuristics/identifiant_ocr_detector.dart';
import 'package:test/test.dart';

/// P2-268 : un identifiant lu avec des lettres d'OCR (« O »/« o » pour 0,
/// « l »/« I » pour 1) est masqué en entier quand il redevient valide une fois
/// les lettres relues. Cas synthétiques : identifiants fabriqués par le
/// générateur du banc (clés calculées), jamais une valeur réelle.
void main() {
  const nbsp = ' ';
  const nir = '2 19 O7 84 O5O O75 88'; // 219078405007588, zéros lus « O »
  const iban =
      'FR62 7O23 9I23 3759 O83O B66I 372'; // FR627023912337590830B661372
  const rpps = '1139O996O38'; // 11390996038
  const finess = 'O68246289'; // 068246289
  const siren = 'l94821997'; // 194821997

  const detecteur = IdentifiantOcrDetector();

  group('détecteur seul', () {
    test('sans lettre d\'OCR : rien (les détecteurs stricts jugent)', () {
      expect(detecteur.detect('NIR : 2 19 07 84 050 075 88'), isEmpty);
      expect(detecteur.detect('Commande 11390996038 reçue.'), isEmpty);
    });

    test('NIR sans libellé : suite entière de 15 caractères', () {
      final r = detecteur.detect('Valeur relevée : $nir à vérifier.');
      expect(r, hasLength(1));
      expect(r.single.type, EntityType.nir);
      expect(r.single.value, nir);
      expect(r.single.confidence, 0.3);
      expect(r.single.provenance, Provenance.lectureOcr);
    });

    test('NIR : clé fausse une fois relu, jamais masqué', () {
      expect(
          detecteur.detect('Valeur : 2 19 O7 84 O5O O75 89 notée.'), isEmpty);
    });

    test('NIR : sous-suite d\'une suite plus longue sans libellé, rien', () {
      expect(detecteur.detect('Réf. 12 $nir 34 notée.'), isEmpty);
    });

    test('NIR derrière un libellé, suite prolongée : masqué', () {
      final r = detecteur.detect('NIR : $nir 12 ans');
      expect(r.single.value, nir);
    });

    test('séparateurs multiples : blancs insécables doublés, tabulations', () {
      final nbsp2 = nir.replaceAll(' ', '$nbsp$nbsp');
      expect(detecteur.detect('Relevé $nbsp2 noté').single.value, nbsp2);
      final tab = nir.replaceAll(' ', '\t');
      expect(detecteur.detect('NIR : $tab noté').single.value, tab);
    });

    test('une fin de ligne n\'est pas franchie sans libellé', () {
      expect(detecteur.detect('2 19 O7 84\nO5O O75 88'), isEmpty);
    });

    test('IBAN sans libellé : FR + 25 caractères, relu', () {
      final r = detecteur.detect('Compte $iban noté.');
      expect(r.single.type, EntityType.iban);
      expect(r.single.value, iban);
    });

    test('RPPS, FINESS, SIREN, ADELI : seulement derrière leur libellé', () {
      expect(detecteur.detect('Valeur $rpps notée.'), isEmpty);
      expect(detecteur.detect('Valeur $finess notée.'), isEmpty);
      expect(detecteur.detect('Valeur $siren notée.'), isEmpty);
      expect(detecteur.detect('RPPS : $rpps').single.type, EntityType.rpps);
      expect(
          detecteur.detect('FINESS : $finess').single.type, EntityType.finess);
      expect(detecteur.detect('SIREN : $siren').single.type, EntityType.siren);
    });

    test('libellé seul, ou suite qui n\'est pas un identifiant : rien', () {
      expect(detecteur.detect('RPPS : non communiqué'), isEmpty);
      // Luhn faux derrière « RPPS » : depuis P2-275, masqué quand même comme un
      // RPPS à clé invalide (confiance 0,3, sans `Provenance.lectureOcr`, donc
      // avec l'avertissement « clé invalide ») ; avant, rien à ce niveau, et
      // `IdentifiantCleInvalideDetector` ne couvrait que les séparateurs simples.
      final rppsFaux = detecteur.detect('RPPS : 1139O996O39');
      expect(rppsFaux, hasLength(1));
      expect(rppsFaux.single.provenance, isNull);
      expect(detecteur.detect('SIREN : l94821998'), isEmpty);
    });

    test('suites ordinaires denses en O/l/I : rien', () {
      for (final t in [
        'Lot OL10-IO1 reçu.',
        'Code produit OOIL-lOl0 en rayon 11.',
        'Référence de série ILIOOLI à saisir.',
        'Bon de commande 110 011 101 : vérifier.',
      ]) {
        expect(detecteur.detect(t), isEmpty, reason: t);
      }
    });
  });

  group('par Ecluse.redact', () {
    test('NIR sans libellé : masqué en entier, avertissement sans valeur',
        () async {
      final r = await Ecluse.redact('Valeur relevée : $nir à vérifier.');
      expect(r.entities, hasLength(1));
      expect(r.entities.single.type, EntityType.nir);
      expect(r.entities.single.value, nir);
      expect(r.maskedText, isNot(contains('84')));
      final avert = r.warnings.join(' ');
      expect(avert, contains("lettres d'OCR"));
      expect(avert, contains('à vérifier'));
      expect(avert, isNot(contains('O5O')));
      // Le texte d'origine est restitué à l'identique.
      expect(Ecluse.restore(r.maskedText, r.mapping),
          'Valeur relevée : $nir à vérifier.');
    });

    test('NIR derrière un libellé, séparateurs doublés : masqué en entier',
        () async {
      final nbsp2 = nir.replaceAll(' ', '$nbsp$nbsp');
      final r = await Ecluse.redact('NIR : $nbsp2 noté au dossier.');
      expect(r.entities.single.value, nbsp2);
      expect(r.maskedText, isNot(contains('075')));
    });

    test('IBAN sans libellé : masqué en entier', () async {
      final r = await Ecluse.redact('Compte relevé : $iban noté.');
      expect(r.entities.single.type, EntityType.iban);
      expect(r.entities.single.value, iban);
    });

    test('FINESS et SIREN derrière leur libellé : masqués', () async {
      final f = await Ecluse.redact('FINESS : $finess noté.');
      expect(f.entities.single.type, EntityType.finess);
      expect(f.maskedText, isNot(contains('68246')));
      final s = await Ecluse.redact('SIREN : $siren noté.');
      expect(s.entities.single.type, EntityType.siren);
      expect(s.maskedText, isNot(contains('94821')));
    });

    test('aperçu : l\'identifiant relu est proposé « à vérifier »', () async {
      final p = await Apercu.propose('Valeur relevée : $nir à vérifier.');
      expect(p.entites.single.aVerifier, isTrue);
      expect(p.entites.single.confiance, 0.3);
    });

    test('RPPS sans libellé : en clair, comme avant (clé faible)', () async {
      final r = await Ecluse.redact('Valeur relevée : $rpps à vérifier.');
      expect(r.entities.where((e) => e.type == EntityType.rpps), isEmpty);
    });

    test('suites ordinaires : aucun masquage, aucun avertissement OCR',
        () async {
      final r = await Ecluse.redact(
          'Lot OL10-IO1 reçu, code produit OOIL-lOl0 en rayon 11.');
      expect(r.entities, isEmpty);
      expect(r.warnings.join(' '), isNot(contains("lettres d'OCR")));
    });
  });
}
