import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Cas de non-regression pour les correctifs « adresse multiligne » et
/// « patronyme en casse de titre ».
///
/// Voir docs/adresse-multiligne.md pour la specification complete.
///
/// ETAT ATTENDU AVANT IMPLEMENTATION : les groupes « correctif 1 » et
/// « correctif 2 » sont ROUGES. Les groupes « garde-fous » et « non-regression »
/// doivent etre VERTS des maintenant — s'ils sont rouges, c'est que la base
/// est deja cassee et il faut s'arreter la.

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Jetons d'un type donne presents dans la table de correspondance.
///
/// Tolere les deux conventions de cle (`[ADRESSE_1]` ou `ADRESSE_1`).
Iterable<String> tokensOfType(Map<String, String> mapping, String type) =>
    mapping.keys.where((k) => k.contains('${type}_'));

/// Valeurs reelles associees aux jetons d'un type donne.
Iterable<String> valuesOfType(Map<String, String> mapping, String type) =>
    tokensOfType(mapping, type).map((k) => mapping[k]!);

/// Verifie l'invariant fondamental : restaurer un texte masque redonne
/// exactement l'original, octet pour octet.
Future<void> expectRoundTrip(String original) async {
  final r = await Ecluse.redact(original);
  expect(
    Ecluse.restore(r.maskedText, r.mapping),
    equals(original),
    reason: 'La restauration doit etre byte-exacte',
  );
}

// ---------------------------------------------------------------------------
// Corpus
// ---------------------------------------------------------------------------

/// Facture A — trois adresses, toutes sur deux lignes.
/// Donnees 100 % synthetiques (SIRET sequentiel, telephones en plages ARCEP
/// reservees a la fiction, IBAN de test).
const factureA = '''
Entreprise RENOVAL
12 Rue des Quatre Vents
70160 PORT SUR SAONE
Tel : 03 53 01 44 12

SIRET : 12345678200010
N TVA intracommunautaire : FR11123456782

FACTURE

Date : 05/07/2022
Numero : FA00211

Client :
Mademoiselle Camille Verdier
7 Impasse des Charmilles
70160 PORT SUR SAONE
Tel : 06 39 98 27 65
Courriel : camille.verdier@example.fr

Adresse du chantier :
3 Route de Vellexon
70180 DAMPIERRE SUR SALON

Reglement par virement sur le compte :
IBAN FR76 3000 4000 0151 2345 6789 074
BIC BNPAFRPPXXX
''';

/// Facture B — meme contenu, adresses sur une seule ligne.
const factureB = '''
Entreprise RENOVAL, 12 Rue des Quatre Vents, 70160 PORT SUR SAONE
Tel : 03 53 01 44 12

Client :
Mademoiselle Camille Verdier, 7 Impasse des Charmilles, 70160 PORT SUR SAONE
Tel : 06 39 98 27 65

Adresse du chantier : 3 Route de Vellexon, 70180 DAMPIERRE SUR SALON
''';

void main() {
  // -------------------------------------------------------------------------
  // CORRECTIF 1 — l'adresse traverse un saut de ligne unique
  // -------------------------------------------------------------------------
  group('correctif 1 — adresse multiligne', () {
    test('cas 1 — facture A : trois adresses distinctes, aucune voie en clair',
        () async {
      final r = await Ecluse.redact(factureA);

      // Aucun odonyme ne doit fuir vers le LLM.
      expect(r.maskedText, isNot(contains('Rue des Quatre Vents')));
      expect(r.maskedText, isNot(contains('Impasse des Charmilles')));
      expect(r.maskedText, isNot(contains('Route de Vellexon')));

      // Ni le code postal, ni la commune.
      expect(r.maskedText, isNot(contains('70160')));
      expect(r.maskedText, isNot(contains('70180')));
      expect(r.maskedText, isNot(contains('PORT SUR SAONE')));
      expect(r.maskedText, isNot(contains('DAMPIERRE SUR SALON')));

      // Trois adresses => trois jetons distincts.
      final adresses = tokensOfType(r.mapping, 'ADRESSE');
      expect(adresses, hasLength(3),
          reason: 'Emetteur, cliente et chantier sont trois adresses');

      // Bug 2 : les valeurs doivent etre distinctes deux a deux.
      // Avant correction, emetteur et cliente s'effondraient sur
      // « 70160 PORT SUR SAONE », partageant le meme jeton.
      final valeurs = valuesOfType(r.mapping, 'ADRESSE').toSet();
      expect(valeurs, hasLength(3),
          reason: 'Deux adresses differentes ne doivent jamais fusionner');
    });

    test('cas 8 — facture A en CRLF : meme resultat, restauration exacte',
        () async {
      final crlf = factureA.replaceAll('\n', '\r\n');
      final r = await Ecluse.redact(crlf);

      expect(tokensOfType(r.mapping, 'ADRESSE'), hasLength(3));
      expect(r.maskedText, isNot(contains('Rue des Quatre Vents')));

      // Le separateur \r\n ne vit plus que dans la table : il doit revenir.
      await expectRoundTrip(crlf);
    });

    test('cas 7 — deux adresses distinctes recoivent deux jetons', () async {
      const texte = '''
Expediteur : 12 Rue des Quatre Vents
70160 PORT SUR SAONE

Destinataire : 7 Impasse des Charmilles
70180 DAMPIERRE SUR SALON
''';
      final r = await Ecluse.redact(texte);
      expect(valuesOfType(r.mapping, 'ADRESSE').toSet(), hasLength(2));
      await expectRoundTrip(texte);
    });
  });

  // -------------------------------------------------------------------------
  // GARDE-FOUS — empechent la reouverture du bug bloquant
  // -------------------------------------------------------------------------
  //
  // Ces trois tests doivent rester VERTS pour toujours. S'ils tombent au
  // rouge apres un elargissement de la regle, l'elargissement est a annuler.
  group('garde-fous — le span ne doit PAS traverser', () {
    test('cas 3 — ligne suivante sans code postal', () async {
      const texte = '''
7 Impasse des Charmilles
Merci de votre confiance
''';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains('Merci de votre confiance'),
          reason: 'Le span ne doit pas avaler une ligne quelconque');
      await expectRoundTrip(texte);
    });

    test('cas 4 — double saut de ligne entre voie et code postal', () async {
      const texte = '''
7 Impasse des Charmilles

70160 PORT SUR SAONE
''';
      final r = await Ecluse.redact(texte);
      // Le span est interrompu : au plus un jeton, jamais un span traversant
      // la ligne vide.
      expect(tokensOfType(r.mapping, 'ADRESSE').length, lessThanOrEqualTo(1));
      await expectRoundTrip(texte);
    });

    test('cas 5 — cinq chiffres suivis de minuscules ne font pas une commune',
        () async {
      const texte = '''
7 Impasse des Charmilles
70000 euros de travaux realises
''';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains('euros de travaux realises'),
          reason: 'Une commune commence par une majuscule');
      await expectRoundTrip(texte);
    });

    test('cas 6 — complement d adresse intercale : hors perimetre v0',
        () async {
      const texte = '''
7 Impasse des Charmilles
Batiment C
70160 PORT SUR SAONE
''';
      final r = await Ecluse.redact(texte);
      // Limite assumee et documentee dans LIMITES.md : le complement coupe
      // le span. Resolution correcte en phase 2 via le NER.
      expect(r.maskedText, contains('Batiment C'));
      await expectRoundTrip(texte);
    });

    // -----------------------------------------------------------------------
    // Cas 14 et 15 : le span de NOM ne traverse jamais un saut de ligne.
    //
    // Revele par le corpus realiste le 31/07 : le detecteur produisait
    // 'Nathalie Reynaud\n\nEtablissement' — le patronyme absorbait le premier
    // mot de la ligne suivante. La spec (§ 3) exigeait deja « sur la meme
    // ligne » ; la contrainte n'avait pas ete implementee, et aucun garde-fou
    // ne couvrait le detecteur de noms sur ce point.
    //
    // Ce n'est pas une fuite (le contenu est masque) mais une corruption de
    // la structure du document envoye au LLM.
    // -----------------------------------------------------------------------
    test('cas 14 — le span de nom ne traverse pas un double saut de ligne',
        () async {
      const texte =
          'Contact : Madame Nathalie Reynaud\n\nEtablissement : CH de Vesoul\n';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains('Etablissement'),
          reason: 'Le patronyme ne doit pas absorber la ligne suivante');
      await expectRoundTrip(texte);
    });

    test('cas 15 — le span de nom ne traverse pas un saut de ligne simple',
        () async {
      const texte = 'Present : Monsieur Marc Chevrier\nSecretaire de seance\n';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains('Secretaire'),
          reason: 'Le separateur autorise est l espace horizontal, jamais \\n');
      await expectRoundTrip(texte);
    });
  });

  // -------------------------------------------------------------------------
  // CORRECTIF 2 — patronyme en casse de titre apres civilite
  // -------------------------------------------------------------------------
  group('correctif 2 — patronyme en casse de titre', () {
    test('cas 9 — civilite + prenom + patronyme titre', () async {
      const texte = 'Mademoiselle Camille Verdier a signe le devis.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Verdier')),
          reason:
              'Le patronyme ne doit pas fuir quand il n est pas en capitales');
      expect(tokensOfType(r.mapping, 'NOM'), hasLength(1));
      await expectRoundTrip(texte);
    });

    test('cas 10 — patronyme compose', () async {
      const texte = 'Madame Sophie Dupont-Martin nous a contactes.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Dupont-Martin')));
      expect(tokensOfType(r.mapping, 'NOM'), hasLength(1),
          reason: 'Un compose est un seul patronyme, pas deux');
      await expectRoundTrip(texte);
    });

    test('cas 11 — particules absorbees', () async {
      const texte = 'Monsieur Jean de La Fontaine est le proprietaire.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('La Fontaine')));
      await expectRoundTrip(texte);
    });

    test('cas 13 — le span s arrete a la ponctuation', () async {
      const texte = 'Bonjour Madame Camille Verdier. Cordialement, le service.';
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains('Verdier')));
      expect(r.maskedText, contains('Cordialement'),
          reason: 'Un point termine le span de nom');
      await expectRoundTrip(texte);
    });
  });

  // -------------------------------------------------------------------------
  // NON-REGRESSION — doit rester vert avant comme apres
  // -------------------------------------------------------------------------
  group('non-regression', () {
    test('cas 2 — facture B (adresses sur une ligne) inchangee', () async {
      final r = await Ecluse.redact(factureB);

      expect(r.maskedText, isNot(contains('Rue des Quatre Vents')));
      expect(r.maskedText, isNot(contains('Impasse des Charmilles')));
      expect(r.maskedText, isNot(contains('Route de Vellexon')));
      expect(valuesOfType(r.mapping, 'ADRESSE').toSet(), hasLength(3));

      await expectRoundTrip(factureB);
    });

    test('cas 12 — patronyme sans civilite : comportement v0 inchange',
        () async {
      // Limite connue et documentee : sans civilite, la regle n est pas
      // armee. Ce test fige le comportement actuel pour que le correctif 2
      // ne l elargisse pas par accident (risque de faux positifs massifs
      // sur les debuts de phrase).
      const texte = 'Camille Verdier a signe le devis.';
      await expectRoundTrip(texte);
    });

    test('l invariant de restauration tient sur tout le corpus', () async {
      for (final doc in [factureA, factureB]) {
        await expectRoundTrip(doc);
      }
    });
  });
}
