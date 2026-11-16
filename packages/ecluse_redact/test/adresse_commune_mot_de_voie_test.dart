import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Commune dont le nom contient un **mot de voie** (P2-213) : « Graffigny-
/// Chemin », « La Chaussée-Tirancourt », « Cours-la-Ville », « Rue ». Quand
/// une ligne « code postal + mot » suit, le mot de voie du nom était lu comme
/// un type de voie et la ligne suivante comme le code postal de cette voie :
/// le vrai code postal et le début du nom restaient en clair (« 52417
/// GRAFFIGNY [ADRESSE_1] », constat de P2-210). Mesure de départ du balayage
/// `bench/generate_corpus_commune_voie.py` : 641 documents sur 3 744, les 52
/// communes du référentiel concernées.
///
/// Noms de communes publics du référentiel versionné, codes postaux et
/// numéros de CEDEX fabriqués, aucune donnée réelle.
void main() {
  Future<void> attend(String texte, String masque) async {
    final r = await Ecluse.redact(texte);
    expect(r.maskedText, masque, reason: r.maskedText);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  }

  group('code postal et début du nom ne restent plus en clair', () {
    test('le constat de P2-210, en capitales', () async {
      await attend(
          'A RETOURNER A : 52417 GRAFFIGNY CHEMIN CEDEX 7\n'
              '39314 NUMEROS EN ATTENTE',
          'A RETOURNER A : [ADRESSE_1]\n[ADRESSE_2]');
    });

    test('deux adresses sur deux lignes, casse ordinaire', () async {
      await attend(
          'Courrier à adresser à :\n52417 Graffigny-Chemin Cedex 7\n'
              '25000 Besançon\nMerci de votre retour.',
          'Courrier à adresser à :\n[ADRESSE_1]\n[ADRESSE_2]\n'
              'Merci de votre retour.');
    });

    test('mot de voie au milieu du nom, sans CEDEX, en capitales', () async {
      // Rien en clair, mais un seul jeton pour les deux lignes : en capitales,
      // le texte d'ombre écrit « la Chaussee » (déterminant en minuscules),
      // n'y voit pas un « code postal + commune » et étend la voie jusqu'au
      // code postal. Limite écrite dans `LIMITES.md`.
      await attend(
          'COURRIER À ADRESSER À :\n80691 LA CHAUSSEE TIRANCOURT\n'
              '80000 AMIENS\nMERCI DE VOTRE RETOUR.',
          'COURRIER À ADRESSER À :\n[ADRESSE_1]\nMERCI DE VOTRE RETOUR.');
    });

    test('le même sans déterminant : une adresse par ligne', () async {
      await attend(
          'COURRIER À ADRESSER À :\n69470 COURS LA VILLE CEDEX\n'
              '69000 LYON\nMERCI DE VOTRE RETOUR.',
          'COURRIER À ADRESSER À :\n[ADRESSE_1]\n[ADRESSE_2]\n'
              'MERCI DE VOTRE RETOUR.');
    });

    test('mot de voie en tête du nom : le code postal n\'est pas un numéro',
        () async {
      // « 0120 Rue Cedex 1 » était lu comme le numéro 120 d'une voie, et le
      // premier chiffre du code postal restait en clair.
      await attend(
          'Courrier à adresser à :\n80120 Rue Cedex 1\n80100 Abbeville\n'
              'Merci de votre retour.',
          'Courrier à adresser à :\n[ADRESSE_1]\n[ADRESSE_2]\n'
              'Merci de votre retour.');
    });

    test('derrière une vraie voie, en capitales (texte d\'ombre compris)',
        () async {
      await attend(
          'COURRIER À ADRESSER À :\n7 RUE DES LILAS\n56693 LE COURS CEDEX 3\n'
              '77821 FORMULAIRES EN ATTENTE\nMERCI DE VOTRE RETOUR.',
          'COURRIER À ADRESSER À :\n[ADRESSE_1]\n[ADRESSE_2]\n'
              'MERCI DE VOTRE RETOUR.');
    });

    test('code postal introduit comme une référence : rien ne reste en clair',
        () async {
      // « Lot 52417 … » : le nombre seul ne serait pas lu comme un code
      // postal (P2-167). Mais dès qu'une adresse est reconnue à partir du
      // mot de voie, elle part du code postal : dans le doute, le côté qui
      // protège.
      final r = await Ecluse.redact(
          'Lot 52417 GRAFFIGNY CHEMIN CEDEX 7\n39314 Colis en attente');
      expect(r.maskedText, isNot(contains('52417')), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('GRAFFIGNY')), reason: r.maskedText);
    });
  });

  group('vraies voies : inchangées', () {
    const inchanges = {
      '12 CHEMIN DES VIGNES\n25000 BESANCON': '[ADRESSE_1]',
      '12 chemin des Vignes, 25000 Besançon': '[ADRESSE_1]',
      'rue des Lilas, 75015 Paris': '[ADRESSE_1]',
      '12 chemin des Vignes': '[ADRESSE_1]',
      // Un nombre à cinq chiffres suivi de mots en minuscules n'est pas un
      // code postal suivi d'une commune : la voie commence à son type.
      'Le lot 54321 livré rue des Lilas, 75015 Paris':
          'Le lot 54321 livré [ADRESSE_1]',
      // Une commune puis une vraie voie numérotée : deux adresses.
      '70000 Vesoul, 12 rue des Lilas, 70000 Vesoul':
          '[ADRESSE_1], [ADRESSE_2]',
    };
    for (final MapEntry(key: texte, value: masque) in inchanges.entries) {
      test(texte.replaceAll('\n', '⏎'), () async {
        final avant = 'Courrier à adresser à :\n';
        const apres = '\nMerci de votre retour.';
        final entier = texte == texte.toUpperCase()
            ? '${avant.toUpperCase()}$texte${apres.toUpperCase()}'
            : '$avant$texte$apres';
        final r = await Ecluse.redact(entier);
        final attendu = texte == texte.toUpperCase()
            ? '${avant.toUpperCase()}$masque${apres.toUpperCase()}'
            : '$avant$masque$apres';
        expect(r.maskedText, attendu, reason: r.maskedText);
        expect(Ecluse.restore(r.maskedText, r.mapping), entier);
      });
    }
  });
}
