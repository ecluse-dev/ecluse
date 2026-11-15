import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Texte tout en capitales : une commune dont le premier mot est un
/// déterminant (« 01097 LA BOISSE », « 93310 LE PRÉ SAINT GERVAIS ») était
/// écartée en entier par le filtre des mots neutres (P2-122) : ni la commune,
/// ni le code postal, ni le CEDEX n'étaient masqués (P2-183 : 2 222 communes,
/// 6,4 % du référentiel). Un déterminant **seul** (« 70000 LA ») ou suivi d'un
/// mot neutre reste refusé. Noms de communes publics, numéros fabriqués.
void main() {
  const adresses = {
    '01097 LA BOISSE CEDEX 1': '[ADRESSE_1]',
    '93310 LE PRÉ SAINT GERVAIS CEDEX 2': '[ADRESSE_1]',
    '39100 LES MAILLYS': '[ADRESSE_1]',
    "25250 L'ISLE-SUR-LE-DOUBS": '[ADRESSE_1]',
    "25250 L'ISLE SUR LE DOUBS CEDEX 4": '[ADRESSE_1]',
  };
  for (final MapEntry(key: adresse, value: masque) in adresses.entries) {
    test('masquée : $adresse', () async {
      final texte = 'COURRIER À ADRESSER À :\n$adresse\nMERCI DE VOTRE RETOUR.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText,
          'COURRIER À ADRESSER À :\n$masque\nMERCI DE VOTRE RETOUR.',
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Contre-exemples : une phrase en capitales qui commence par un déterminant
  // après un nombre à cinq chiffres n'est pas une adresse.
  const intacts = [
    "LE DEVIS S'ÉLÈVE À 70000 EUROS HORS TAXES.",
    'COMMANDE DE 70000 LA',
    'LISTE DE 70000 LES 3 PREMIERS ARTICLES.',
    'TOTAL 54321 LES DOSSIERS DU MOIS.',
  ];
  for (final texte in intacts) {
    test('inchangé : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }

  // Coût assumé (décision du 15 novembre, P2-187 ; `DECISIONS.md`, « dans le
  // doute, le côté qui protège ») : un nombre à cinq chiffres suivi d'un
  // déterminant et d'un mot ordinaire non neutre est masqué comme une adresse,
  // en capitales comme en casse ordinaire. Un masquage en trop coûte de la
  // lisibilité, une commune en clair est une fuite. Ces tests figent le
  // comportement pour qu'un changement soit vu, pas pour le recommander.
  // En capitales, la « commune » avale tous les mots à majuscule qui suivent
  // (aucune minuscule ne l'arrête) : le reste de la phrase disparaît aussi.
  const masquesEnTrop = {
    'VOIR 12345 LE SERVICE DES ADMISSIONS.': 'VOIR [ADRESSE_1].',
    'REÇU 70000 LA SUITE EST ATTENDUE.': 'REÇU [ADRESSE_1].',
  };
  for (final MapEntry(key: texte, value: attendu) in masquesEnTrop.entries) {
    test('masqué en trop (coût assumé) : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, attendu, reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Même chose en casse ordinaire : l'essai aligne les capitales dessus.
  test('casse ordinaire : même masquage en trop, même restauration', () async {
    const texte = 'Voir 12345 Le Service des admissions.';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, 'Voir [ADRESSE_1] des admissions.',
        reason: r.maskedText);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });
}
