import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-191 : un NIR, un IBAN FR ou un RPPS annoncé par un libellé fort, lu par
/// OCR (O pour 0, l ou I pour 1, ligne vide entre deux groupes) restait en
/// clair : le candidat de P2-188 n'acceptait que des chiffres et un séparateur
/// simple. Ces tolérances valent **derrière un libellé fort seulement** ; les
/// détecteurs stricts de `ecluse_core` ne bougent pas.
///
/// Fixtures synthétiques : NIR `185057800608491`, RPPS `10001234565`, IBAN
/// `FR7630006000011234567890189` (clés justes, établies dans `ecluse_core`) et
/// `FR13 3000 6000 0100 0000 0001 189` (clé juste, calculée pour ce test, dont
/// la clé « 13 » se prête aux confusions). Jamais une valeur réelle.
void main() {
  // (texte, type, valeur attendue masquée : tout après le libellé)
  const positifs = <String, (String, EntityType, String)>{
    'NIR : O pour 0 dans le corps': (
      'NIR : 1 85 05 78 OO6 084 91 à vérifier',
      EntityType.nir,
      '1 85 05 78 OO6 084 91',
    ),
    'NIR : o minuscule pour 0': (
      'NIR : 1 85 o5 78 006 084 91.',
      EntityType.nir,
      '1 85 o5 78 006 084 91',
    ),
    'NIR : l pour 1 en tête': (
      'NIR : l 85 05 78 006 084 91.',
      EntityType.nir,
      'l 85 05 78 006 084 91',
    ),
    'NIR : I majuscule pour 1 dans la clé': (
      'NIR : 1 85 05 78 006 084 9I',
      EntityType.nir,
      '1 85 05 78 006 084 9I',
    ),
    'NIR : ligne vide entre deux groupes': (
      'NIR : 1 85 05 78\n\n006 084 91 fin',
      EntityType.nir,
      '1 85 05 78\n\n006 084 91',
    ),
    'NIR : clé fausse et ligne vide': (
      'N° de sécurité sociale : 185057800608490\n\n',
      EntityType.nir,
      '185057800608490',
    ),
    'IBAN : l pour 1 dans la clé': (
      'IBAN : FRl3 3000 6000 0100 0000 0001 189.',
      EntityType.iban,
      'FRl3 3000 6000 0100 0000 0001 189',
    ),
    'IBAN : I pour 1 dans la clé': (
      'IBAN FRI3 3000 6000 0100 0000 0001 189',
      EntityType.iban,
      'FRI3 3000 6000 0100 0000 0001 189',
    ),
    'IBAN : ligne vide entre deux groupes': (
      'IBAN : FR76 3000 6000\n\n0112 3456 7890 189 merci',
      EntityType.iban,
      'FR76 3000 6000\n\n0112 3456 7890 189',
    ),
    'IBAN : ligne vide avec blancs et retour chariot': (
      'IBAN : FR76 3000 6000 \r\n \r\n 0112 3456 7890 189',
      EntityType.iban,
      'FR76 3000 6000 \r\n \r\n 0112 3456 7890 189',
    ),
    'RPPS : l pour 1': (
      'RPPS : 1000l234565',
      EntityType.rpps,
      '1000l234565',
    ),
    'RPPS : O pour 0': (
      'RPPS 10OO1234565.',
      EntityType.rpps,
      '10OO1234565',
    ),
    'RPPS : ligne vide': (
      'RPPS : 1000\n\n1234565',
      EntityType.rpps,
      '1000\n\n1234565',
    ),
    // P2-199 : ADELI (9 chiffres, clé de Luhn). Fixture synthétique
    // `810012344`, clé calculée pour ce test, jamais une valeur réelle.
    'ADELI : O pour 0': (
      'ADELI : 81O012344 noté.',
      EntityType.adeli,
      '81O012344',
    ),
    'ADELI : l pour 1, groupes': (
      'ADELI : 8l0 0l2 344 noté.',
      EntityType.adeli,
      '8l0 0l2 344',
    ),
    'ADELI : ligne vide entre deux groupes': (
      'ADELI 810\n\n012 344 noté.',
      EntityType.adeli,
      '810\n\n012 344',
    ),
    'ADELI : O pour 0 et ligne vide': (
      'ADELI : 81O 012\n\n344.',
      EntityType.adeli,
      '81O 012\n\n344',
    ),
  };

  group('témoin positif : libellé fort + lecture OCR, masqué en entier', () {
    for (final entry in positifs.entries) {
      test(entry.key, () async {
        final (texte, type, valeur) = entry.value;
        final r = await Ecluse.redact(texte);
        final e = r.entities.where((e) => e.type == type).toList();
        expect(e, hasLength(1), reason: 'non masqué : ${entry.key}');
        expect(e.single.value, valeur);
        expect(r.maskedText, isNot(contains(valeur)));
        expect(Ecluse.restore(r.maskedText, r.mapping), texte);
        expect(
          r.warnings.any((w) => w.contains('identifiant à clé invalide')),
          isTrue,
          reason: 'avertissement « à vérifier » absent',
        );
        // Jamais la valeur dans un avertissement.
        for (final w in r.warnings) {
          expect(w, isNot(contains(valeur)));
        }
      });
    }
  });

  test(
      'ADELI lu par OCR dont les cinq derniers chiffres + un mot ressemblent '
      'à une adresse : masqué en entier, rien en clair', () async {
    const texte = 'ADELI 209l73939 noté au dossier.';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, isNot(contains('209l')));
    expect(r.maskedText, isNot(contains('73939')));
    expect(r.entities.where((e) => e.type == EntityType.adeli), hasLength(1));
    expect(r.entities.single.value, '209l73939');
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  group('témoin négatif : libellé seul ou suivi d\'autre chose, intact', () {
    const phrases = [
      'IBAN : voir pièce jointe',
      'NIR : non communiqué',
      'RPPS : non renseigné',
      'NIR : à compléter',
      'IBAN : FRANCE',
      'RPPS : 10OO1234',
      'ADELI : de l\'infirmière',
      'ADELI : 81O01234',
      'ADELI : à renseigner',
      'NIR : l\'ordre du jour',
      'NIR : 450 euros',
      'IBAN : le 12/03/2026',
      // Sans libellé fort, ces formes ne sont jamais acceptées.
      'Dossier 1 85 05 78 OO6 084 91',
      'Réf. 10OO1234565',
      'Compte FRl3 3000 6000 0100 0000 0001 189',
      'Référence interne 81O 012 344 noté au dossier.',
    ];
    for (final texte in phrases) {
      test(texte, () async {
        final r = await Ecluse.redact(texte);
        expect(r.maskedText, texte);
        expect(r.mapping, isEmpty);
      });
    }
  });

  test('les détecteurs stricts de ecluse_core restent stricts', () {
    expect(const NirDetector().detect('1 85 05 78 OO6 084 91'), isEmpty);
    expect(const RppsDetector().detect('10OO1234565'), isEmpty);
    expect(
      const IbanFrDetector().detect('FRl3 3000 6000 0100 0000 0001 189'),
      isEmpty,
    );
  });

  test('forme ordinaire à clé juste : toujours le détecteur strict seul',
      () async {
    final r = await Ecluse.redact('NIR : 1 85 05 78 006 084 91.');
    expect(r.entities.single.confidence, 1.0);
    expect(
      r.warnings.any((w) => w.contains('identifiant à clé invalide')),
      isFalse,
    );
  });

  test('IBAN valide, clé en chiffres, corps en lettres : pas de doublon',
      () async {
    final r = await Ecluse.redact('IBAN : FR13 3000 6000 0100 0000 0001 189');
    expect(r.entities.where((e) => e.type == EntityType.iban), hasLength(1));
    expect(r.entities.single.confidence, 1.0);
  });
}
