import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// « SAINT M HERVE » : le « M » isolé après SAINT n'est pas une civilité
/// (P2-208).
///
/// La commune « Saint-M'Hervé » perd son apostrophe à la normalisation du
/// référentiel : « 35184 SAINT M HERVE CEDEX 3 ». Deux détecteurs lisaient le
/// « M » comme une civilité ou un patronyme : `AdresseDetector` le refuse
/// comme mot de commune (`_titres`, P2-180), `NameDetector` le prend pour le
/// nom qui précède le prénom connu « HERVE ». Résultat : « [ADRESSE] [NOM] 3 »,
/// le numéro de CEDEX en clair — seule adresse du balayage en capitales avec
/// CEDEX encore en défaut après P2-201. Valeurs synthétiques.
void main() {
  group('« SAINT M HERVE » est une commune', () {
    const textes = [
      'COURRIER À ADRESSER À :\n35184 SAINT M HERVE CEDEX 3\n'
          'MERCI DE VOTRE RETOUR.',
      'Courrier à adresser à :\n35184 Saint M Hervé CEDEX 3\n'
          'Merci de votre retour.',
      'COURRIER À ADRESSER À :\n35184 SAINT   M HERVE CEDEX 3\n'
          'MERCI DE VOTRE RETOUR.',
    ];
    for (final t in textes) {
      test(t.replaceAll('\n', '⏎'), () async {
        final r = await Ecluse.redact(t);
        for (final reste in [
          '35184',
          'SAINT',
          'Saint',
          'HERVE',
          'Hervé',
          'M ',
          'CEDEX',
          ' 3'
        ]) {
          expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
        }
        expect(r.maskedText.toLowerCase(), contains('merci de votre retour.'));
        expect(r.mapping.jetons, hasLength(1), reason: r.maskedText);
        expect(Ecluse.restore(r.maskedText, r.mapping), t);
      });
    }
  });

  group('une vraie civilité « M » reste une civilité', () {
    test('« M DUPONT » : le nom est masqué, la civilité reste', () async {
      final r = await Ecluse.redact('RDV AVEC M DUPONT');
      expect(r.maskedText, isNot(contains('DUPONT')));
      expect(r.maskedText, contains('M '));
    });

    test('« M HERVE » hors SAINT : toujours un nom', () {
      const d = NameDetector();
      expect(d.detect('RDV AVEC M HERVE').map((e) => e.value), ['M HERVE']);
    });

    test('« M. Dupont » et « Monsieur Dupont »', () async {
      for (final t in ['Vu avec M. Dupont hier.', 'Vu avec Monsieur Dupont.']) {
        final r = await Ecluse.redact(t);
        expect(r.maskedText, isNot(contains('Dupont')), reason: r.maskedText);
      }
    });

    test('un « M » après un autre mot que SAINT ne devient pas commune',
        () async {
      final r = await Ecluse.redact('VOIR 35184 VAL M DUPONT CEDEX 3');
      expect(r.maskedText, isNot(contains('DUPONT')), reason: r.maskedText);
    });
  });
}
