import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_redact/src/coupures_de_nom.dart';
import 'package:test/test.dart';

/// P2-289 : un mot de nom d'établissement commence par une **majuscule**.
///
/// La classe `[A-ZÀ-Ÿ]` couvre U+00C0 à U+0178, donc aussi les minuscules
/// accentuées U+00E0 à U+00FF, dont « à » : « CHU à Lille » passait pour un
/// nom d'établissement de trois mots (mesure P2-285 : 5 902 documents sur
/// 200 000 phrases sans personne, et 83 noms annotés du corpus réaliste
/// masqués avec un « à » de trop). Même défaut dans les classes de
/// `coupures_de_nom.dart`. Toutes les valeurs sont synthétiques.
void main() {
  const detector = EtablissementDetector();

  group('« à » et les minuscules accentuées ne sont pas un mot de nom', () {
    for (final t in [
      'Le dossier du CHU à Lille est clos.',
      'Passage du SSIAD à Angers ce matin.',
      'Transfert vers le CH à Vesoul.',
      'La clinique à Besançon ferme.',
    ]) {
      test('aucun établissement dans « $t »', () {
        expect(detector.detect(t), isEmpty);
      });
    }

    test('le nom s\'arrête avant « à »', () {
      expect(detector.detect('Admis au CH Vesoul à Lille.').single.value,
          'CH Vesoul');
      expect(detector.detect('Suivi au CHU Nord à Lille.').single.value,
          'CHU Nord');
    });
  });

  group('les majuscules accentuées restent des mots de nom', () {
    for (final (t, attendu) in const [
      ('Admis à la Clinique Évry hier.', 'Clinique Évry'),
      ('Suivi au CH Étoile du Nord.', 'CH Étoile du Nord'),
      ('Accueil à l\'IME Œuvre Sainte.', 'IME Œuvre Sainte'),
      ('Vu à la Résidence Ângelus.', 'Résidence Ângelus'),
    ]) {
      test(t, () {
        expect(detector.detect(t).single.value, attendu);
      });
    }
  });

  group('recollage de fin de ligne (coupuresDeNom)', () {
    test('« à » en tête de ligne n\'est pas la suite du nom', () {
      expect(coupuresDeNom('Transfert au CH\nà Lille demain.'), isEmpty);
      expect(coupuresDeNom('Vu au CH de\nà midi.'), isEmpty);
    });

    test('un nom en majuscule accentuée se recolle encore', () {
      expect(
          coupuresDeNom('Réside à l\'EHPAD\nÉtoile du Matin.'), hasLength(1));
      expect(coupuresDeNom('Admis au CH de\nÉvry hier.'), hasLength(1));
    });
  });
}
