import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Nombre de cinq chiffres qui n'est pas un code postal (P2-167). Mesure de
/// départ (`bench/generate_corpus_cinq_chiffres.py`, 400 phrases sans aucune
/// adresse) : 132 adresses prédites par `Ecluse.redact`, 88 par
/// `AdresseDetector` seul (nombre + mot à majuscule) et 44 par le texte
/// d'ombre des casses de phrase et minuscules (nombre + nom commun).
///
/// Ce qui est écarté, c'est le nombre **introduit par une tournure de quantité
/// ou de référence** (« de », « environ », « lot », « réf. », « n° »…), jamais
/// un mot suivant choisi d'après les valeurs d'un corpus. Un code postal qui
/// suit une voie, une virgule, « à » ou une étiquette d'adresse reste masqué.
void main() {
  // Rouges avant la correction : aucune adresse dans ces phrases.
  const intacts = [
    // Texte en casse de phrase (texte d'ombre) : nom commun après le nombre.
    'Commande de 70000 unités, cedex 9 non concerné.',
    'Commande de 70000 unités.',
    'Stock de 54321 pièces ce mois-ci.',
    'Environ 12345 exemplaires au dernier relevé.',
    'Livraison de 20000 colis.',
    'Un total de 33000 boîtes.',
    // Casse ordinaire : mot à majuscule après le nombre.
    'Réf. 55090 Standard au dernier relevé. Voir la note de la Direction.',
    'Dossier n° 17514 Alpha. Merci de répondre à Marie.',
    'Lot 70000 Bravo livré. Rapport du service Qualité.',
    'Référence 54321 Archive. Voir la note de la Direction.',
    'Commande 21964 Express. Voir la note de la Direction.',
    'N° de lot 40404 Nord. Rapport du service Qualité.',
    'Facture de 12500 Alpha. Merci de répondre à Marie.',
    // Étiquette suivie de deux-points.
    'Total : 70000 unités',
    'Réf. : 54321 Standard. Voir la note de la Direction.',
  ];
  for (final texte in intacts) {
    test('aucune adresse : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(
        r.entities.where((e) => e.type == EntityType.adresse),
        isEmpty,
        reason: r.maskedText,
      );
    });
  }

  // Doivent rester masquées : un vrai code postal et sa commune.
  const adresses = {
    'Adresse : 70000 Vesoul': 'Adresse : [ADRESSE_1]',
    'Adresse : 8 chemin des Vignes, 70000 Vesoul': 'Adresse : [ADRESSE_1]',
    'Il habite à 70000 Vesoul depuis dix ans. Voir Marie.':
        'Il habite à [ADRESSE_1] depuis dix ans. Voir Marie.',
    'Courrier envoyé à Vesoul, 70000 Vesoul.':
        'Courrier envoyé à Vesoul, [ADRESSE_1].',
    'Mme Durand, 12 rue du Lot 46000 Cahors': 'Mme [NOM_1], [ADRESSE_1]',
    'Résidence Alpha\n70000 Vesoul': 'Résidence Alpha\n[ADRESSE_1]',
    // Texte sans majuscule : la commune après un code postal reste lue.
    'il habite à 70000 vesoul depuis dix ans':
        'il habite à [ADRESSE_1] depuis dix ans',
    'adresse : 70000 vesoul': 'adresse : [ADRESSE_1]',
    'la mairie, 70000 vesoul': 'la mairie, [ADRESSE_1]',
  };
  for (final e in adresses.entries) {
    test('adresse conservée : ${e.key.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(e.key);
      expect(
        r.entities.where((x) => x.type == EntityType.adresse),
        isNotEmpty,
        reason: r.maskedText,
      );
    });
  }

  // Limites assumées, documentées dans `LIMITES.md` : ce qui ne change pas ou
  // qui est perdu. Un test les fixe pour que la perte reste mesurée.
  // « de » seul n'est pas une tournure de quantité (décision du 13 novembre) :
  // un code postal introduit par « de » reste masqué.
  for (final texte in const [
    'Courrier de la mairie de 70000 Vesoul.',
    'Patient originaire de 25000 Besançon.',
    'Transfert en provenance de 90000 Belfort.',
  ]) {
    test('code postal introduit par « de », toujours masqué : $texte',
        () async {
      final r = await Ecluse.redact(texte);
      expect(r.entities.where((e) => e.type == EntityType.adresse), isNotEmpty);
    });
  }

  test('« de » après un nom de quantité : « un lot de 12345 Pièces »',
      () async {
    final r = await Ecluse.redact('Il reste un lot de 12345 Pièces en stock.');
    expect(r.entities.where((e) => e.type == EntityType.adresse), isEmpty);
  });

  test('reste masqué à tort : nombre en tête de phrase (même forme)', () async {
    final r = await Ecluse.redact('58699 Alpha livrés. Voir la note de Marie.');
    expect(r.entities.where((e) => e.type == EntityType.adresse), isNotEmpty);
  });

  // P2-177 : ce qui distingue « 58699 Alpha livrés. » d'une adresse, c'est le
  // mot en minuscules qui suit le nom. Une règle qui s'en servirait ferait
  // partir ces adresses en clair (mesure : `bin/run_cp_tete_bench.dart`, 108
  // adresses sur 432 de `bench/generate_corpus_cp_tete.py`). Le masquage à
  // tort est donc gardé ; ces tests tiennent les adresses à ne pas perdre.
  group('code postal en tête suivi de mots en minuscules : toujours masqué',
      () {
    for (final texte in const [
      // En tête de texte.
      '25000 Besançon depuis 2019.',
      '90000 Belfort et environs.',
      '39100 Dole le 3 mai 2026.',
      // En tête de ligne : bloc d'adresse, ou prose recoupée comme dans un
      // PDF.
      'Résidence des Tilleuls\n70000 Vesoul pour le courrier.',
      'La famille reste domiciliée au\n25000 Besançon depuis 2019.',
      // En tête de phrase.
      'Adresse inchangée. 21000 Dijon jusqu\'à nouvel ordre.',
      // Texte tapé sans aucune majuscule.
      '70000 vesoul depuis dix ans.',
      'le courrier est à envoyer au\n70170 port-sur-saône uniquement.',
      'dossier complet. 39000 lons-le-saunier à confirmer.',
    ]) {
      test(texte.replaceAll('\n', r'\n'), () async {
        final r = await Ecluse.redact(texte);
        final codePostal = RegExp(r'\d{5}').stringMatch(texte)!;
        expect(
            r.entities.where((e) => e.type == EntityType.adresse), isNotEmpty);
        expect(r.maskedText, isNot(contains(codePostal)));
        // La commune ne reste pas en clair non plus.
        final commune =
            RegExp(r'\d{5} ([^ .\n]+)').firstMatch(texte)!.group(1)!;
        expect(r.maskedText, isNot(contains(commune)));
      });
    }
  });
}
