import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Communes en capitales **devant « CEDEX »** (P2-201). Le balayage de
/// P2-196 (`agent/specs/P2-196.md`) laissait 95 adresses sur 139 500 en partie
/// en clair, en cinq classes ; ces cas en prennent un par classe. Décision du
/// 15 novembre : lever ce qui bloque **seulement quand « CEDEX » suit sur la
/// même ligne**, « dans le doute, le côté qui protège » (`DECISIONS.md`).
/// Noms de communes publics du référentiel versionné, numéros de CEDEX
/// fabriqués, aucune donnée réelle.
void main() {
  // Chaque adresse tient sur sa ligne, entre deux lignes de texte ordinaire.
  const masquees = {
    // Classe 1 : premier mot de la commune = mot neutre (VERS, SOUS, SON…).
    '46090 VERS CEDEX 2': '[ADRESSE_1]',
    '09230 SOUS PARSAT CEDEX 1': '[ADRESSE_1]',
    '12345 SON CEDEX 4': '[ADRESSE_1]',
    // Classe 2 : complément entre parenthèses dans le nom officiel.
    '58120 CHATEAU CHINON (VILLE) CEDEX 1': '[ADRESSE_1]',
    '64350 CASTILLON (CANTON DE LEMBEYE) CEDEX 1': '[ADRESSE_1]',
    // Classe 3 : tiret isolé, ou blancs multiples quand le tiret est retiré.
    '12345 SARROUX - SAINT JULIEN CEDEX 1': '[ADRESSE_1]',
    '12345 SAINT-PATERNE - LE CHEVAIN CEDEX 3': '[ADRESSE_1]',
    '12345 SAINT PATERNE   LE CHEVAIN CEDEX 3': '[ADRESSE_1]',
    '12345 SARROUX   SAINT JULIEN CEDEX 1': '[ADRESSE_1]',
    // Classe 4 : déterminant puis mot neutre.
    '12345 LES PLACES CEDEX 1': '[ADRESSE_1]',
  };
  for (final MapEntry(key: adresse, value: masque) in masquees.entries) {
    test('masquée en entier : $adresse', () async {
      final texte = 'COURRIER À ADRESSER À :\n$adresse\nMERCI DE VOTRE RETOUR.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText,
          'COURRIER À ADRESSER À :\n$masque\nMERCI DE VOTRE RETOUR.',
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Sans « CEDEX » derrière, rien ne change : la règle du mot neutre (P2-122)
  // et le motif d'avant restent entiers.
  const intacts = [
    'LE DEVIS S\'ÉLÈVE À 70000 EUROS HORS TAXES.',
    'VIREMENT DE 70000 EUROS (TTC).',
    'VIREMENT DE 70000 EUROS - HT.',
    'COMMANDE DE 70000 LES 3 PREMIERS ARTICLES.',
    'TOTAL 54321 PLACES.',
  ];
  for (final texte in intacts) {
    test('inchangé sans CEDEX : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte, reason: r.maskedText);
    });
  }

  // Coût assumé (décision du 15 novembre) : un nombre à cinq chiffres, un mot
  // neutre et « CEDEX » à la suite sont masqués comme une adresse. Mieux vaut
  // un masquage en trop qu'une commune en clair ; ces tests figent le
  // comportement pour qu'un changement soit vu, pas pour le recommander.
  // Mesure du pire cas : `bench/generate_corpus_neutre_cedex.py` (P2-200).
  const masquesEnTrop = {
    'VIREMENT DE 70000 EUROS CEDEX 3.': 'VIREMENT DE [ADRESSE_1].',
    'VIREMENT DE 70000 EUROS (TTC) CEDEX 3.': 'VIREMENT DE [ADRESSE_1].',
  };
  for (final MapEntry(key: texte, value: attendu) in masquesEnTrop.entries) {
    test('masqué en trop (coût assumé) : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, attendu, reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Les tournures de quantité (« total de », « lot », « réf. ») protègent
  // toujours le nombre, CEDEX ou non (P2-167).
  test('inchangé : tournure de quantité devant le nombre', () async {
    const texte = 'TOTAL DE 70000 EUROS CEDEX 3.';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, texte, reason: r.maskedText);
  });

  // « CEDEX » sur la ligne suivante n'est pas « à la suite » : la règle du mot
  // neutre tient (un span ne traverse jamais un saut de ligne, LIMITES § 5.2).
  test('inchangé : CEDEX sur la ligne suivante', () async {
    const texte = 'VIREMENT DE 70000 EUROS\nCEDEX 3.';
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, texte, reason: r.maskedText);
  });
}
