import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// `EtablissementDetector` : un type d'établissement en toutes lettres suivi
/// seulement de mots d'une liste fermée de mots génériques n'est pas masqué
/// (P2-301, décision du 26 novembre, point 5, option 2 de
/// `agent/specs/P2-295.md`).
///
/// Chemin mesuré : le détecteur seul. Le chiffre `Ecluse.redact` (200 000
/// documents sans personne, témoin de 480, flou réaliste et adversarial) est
/// dans la description de la PR et dans `bench/ETAT.md`.
///
/// Toutes les valeurs sont synthétiques.
void main() {
  const detector = EtablissementDetector();

  group('type + mot générique de la liste : non masqué', () {
    for (final t in [
      'La Résidence Autonomie est ouverte.',
      'Note Logistique La Résidence Autonomie.',
      "Le Foyer D'accueil Médicalisé ferme.",
      'Le Foyer D’accueil Médicalisé ferme.',
      'Le Foyer Médicalisé ferme.',
      'Le Foyer Médicalisée ferme.',
      'La Résidence Services est ouverte.',
      'Le Centre Social est fermé.',
      'Le Lycée Agricole est fermé.',
      'La RÉSIDENCE AUTONOMIE est ouverte.',
      "Le Foyer D'ACCUEIL MÉDICALISÉ ferme.",
      // Plusieurs mots génériques de suite.
      'Le Foyer Autonomie Services ferme.',
    ]) {
      test('aucun établissement dans « $t »', () {
        expect(detector.detect(t), isEmpty);
      });
    }
  });

  group('ce que la liste ne retire pas', () {
    test('un nom propre derrière un type reste masqué', () {
      expect(detector.detect('Le Foyer Les Lilas ferme.').single.value,
          'Foyer Les Lilas');
      expect(detector.detect('La Clinique Pasteur ouvre.').single.value,
          'Clinique Pasteur');
    });

    test('un mot générique suivi d\'un mot hors liste reste masqué en entier',
        () {
      final e = detector.detect('La Résidence Autonomie Horizon ouvre.');
      expect(e, hasLength(1));
      expect(e.single.value, 'Résidence Autonomie Horizon');
    });

    test('un mot hors liste suivi d\'un mot générique reste masqué en entier',
        () {
      final e = detector.detect('La Résidence Horizon Services ouvre.');
      expect(e.single.value, 'Résidence Horizon Services');
    });

    test('un nom entre guillemets reste masqué, même s\'il est générique', () {
      expect(
          detector.detect('La Résidence « Autonomie » ouvre.'), hasLength(1));
    });

    test('un sigle suivi d\'un mot de la liste reste masqué', () {
      // La liste ne vaut que pour un type écrit en toutes lettres.
      expect(
          detector.detect('Le CH Services ouvre.').single.value, 'CH Services');
      expect(detector.detect('L\'EHPAD Social ouvre.').single.value,
          'EHPAD Social');
    });

    test('positions : début et fin du nom conservés', () {
      const t = 'Voir la Clinique Pasteur demain.';
      final e = detector.detect(t).single;
      expect(t.substring(e.start, e.end), 'Clinique Pasteur');
    });
  });

  test('la liste est une constante documentée et extensible', () {
    expect(EtablissementDetector.motsGeneriques, contains('autonomie'));
    expect(EtablissementDetector.motsGeneriques, contains("d'accueil"));
    expect(EtablissementDetector.motsGeneriques, contains('médicalisé'));
    expect(EtablissementDetector.motsGeneriques, contains('médicalisée'));
    expect(EtablissementDetector.motsGeneriques, contains('services'));
    expect(EtablissementDetector.motsGeneriques, contains('social'));
    expect(EtablissementDetector.motsGeneriques, contains('agricole'));
  });
}
