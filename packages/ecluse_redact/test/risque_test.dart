import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Branchement de `ecluse_reid` dans `Ecluse.redact` (P2-04, option A de
/// `agent/specs/P2-03.md` : rapport de risque seul). Deux garanties :
/// sans référence, la sortie est celle d'avant le branchement, octet pour
/// octet ; avec, le texte masqué ne change pas et le rapport dit toujours ce
/// qu'il n'a pas évalué.
void main() {
  // Sorties relevées avant le branchement (aucune référence).
  const equivalences = <(String, String, Map<String, String>)>[
    (
      'Mme Sophie Verdier, née le 12/03/1950, joignable au 01 99 00 12 34, '
          'habite à Thionville. Le Dr Martin, pneumologue, la suit depuis ses '
          '74 ans. Contact : sophie.verdier@example.fr',
      'Mme [NOM_1], née le [DATE_NAISSANCE_1], joignable au [TELEPHONE_1], '
          'habite à Thionville. Le [NOM_2], pneumologue, la suit depuis ses '
          '74 ans. Contact : [EMAIL_1]',
      {
        '[NOM_1]': 'Sophie Verdier',
        '[DATE_NAISSANCE_1]': '12/03/1950',
        '[TELEPHONE_1]': '01 99 00 12 34',
        '[NOM_2]': 'Dr Martin',
        '[EMAIL_1]': 'sophie.verdier@example.fr',
      }
    ),
    (
      'Aucun nom ici, seulement une réunion à Dole.',
      'Aucun nom ici, seulement une réunion à Dole.',
      {}
    ),
    ('', '', {}),
    (
      'M. Jean Dupont puis M. Dupont ; Mme Dupont rappelle.',
      'M. [NOM_1] puis M. [NOM_1] ; Mme [NOM_2] rappelle.',
      {'[NOM_1]': 'Jean Dupont', '[NOM_2]': 'Dupont'}
    ),
  ];

  late EcluseReference ref;
  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
  });

  group('sans référence : comportement inchangé', () {
    for (final (texte, masque, carte) in equivalences) {
      test('« ${texte.length > 30 ? texte.substring(0, 30) : texte} »',
          () async {
        final r = await Ecluse.redact(texte);
        expect(r.maskedText, masque);
        expect(r.mapping, carte);
        expect(r.warnings, isEmpty);
        expect(r.risque, isNull, reason: 'fonction inactive : pas de rapport');
      });
    }
  });

  group('avec référence : le texte masqué ne change pas', () {
    for (final (texte, masque, carte) in equivalences) {
      test('« ${texte.length > 30 ? texte.substring(0, 30) : texte} »',
          () async {
        final sans = await Ecluse.redact(texte);
        final avec = await Ecluse.redact(texte, riskReference: ref);
        expect(avec.maskedText, masque);
        expect(avec.maskedText, sans.maskedText);
        expect(avec.mapping, carte);
        expect(avec.warnings, sans.warnings);
        expect(avec.entities.length, sans.entities.length);
        expect(avec.risque, isNotNull);
        // La restauration est celle d'avant (la fusion « Dupont » reste le
        // cas connu de LIMITES.md § 5.3), pas nécessairement le texte d'origine.
        expect(Ecluse.restore(avec.maskedText, avec.mapping),
            Ecluse.restore(sans.maskedText, sans.mapping));
      });
    }
  });

  group('rapport de risque', () {
    test('évalué : QI repérés avec position dans le texte masqué', () async {
      final r = await Ecluse.redact(
          'Mme Sophie Verdier, 66 ans, habite à Thionville.',
          riskReference: ref);
      final e = r.risque!.evaluation;
      expect(e.statut, EvaluationStatut.evalue);
      expect(e.estimate!.f, greaterThan(0));
      expect(e.spans, isNotEmpty);
      for (final s in e.spans) {
        expect(r.maskedText.substring(s.start, s.end), s.text);
      }
    });

    test(
        'un QI déjà masqué n\'est pas évalué : le rapport porte sur le texte '
        'envoyé', () async {
      final r = await Ecluse.redact(
          'Joignable au 01 99 00 12 34. Sans autre indice.',
          riskReference: ref);
      expect(r.risque!.evaluation.statut, EvaluationStatut.aucunQi);
    });

    test('aucun QI : jamais lu comme un risque faible', () async {
      final r = await Ecluse.redact('Réunion de service reportée.',
          riskReference: ref);
      final rapport = r.risque!;
      expect(rapport.evaluation.statut, EvaluationStatut.aucunQi);
      expect(rapport.evaluation.estimate, isNull);
      expect(
          rapport.evaluation.notes.join(' '), contains('pas un risque faible'));
    });

    test('non évaluable : motif lisible', () async {
      final r = await Ecluse.redact(
          'Elle habite à Dole et travaille à Belfort.',
          riskReference: ref);
      final e = r.risque!.evaluation;
      expect(e.statut, EvaluationStatut.nonEvaluable);
      expect(e.motifs.single, contains('plusieurs lieux'));
    });

    test('le rappel limité (sans NER) figure toujours dans le rapport',
        () async {
      for (final t in ['', 'Mme X, 66 ans, habite à Thionville.', 'Rien.']) {
        final r = await Ecluse.redact(t, riskReference: ref);
        expect(r.risque!.limites.join(' '), contains('Rappel limité'),
            reason: t);
        expect(r.risque!.limites.join(' '), contains('texte masqué'));
        expect(r.risque!.evaluation.notes.first, honestyContract);
      }
    });

    test(
        'une référence inutilisable ne fait jamais échouer la '
        'pseudonymisation', () async {
      final cassee =
          EcluseReference(fileAssets(assetsDir: '/chemin/inexistant'));
      final r = await Ecluse.redact('Mme Sophie Verdier habite à Dole.',
          riskReference: cassee);
      expect(r.maskedText, contains('[NOM_1]'));
      expect(Ecluse.restore(r.maskedText, r.mapping),
          'Mme Sophie Verdier habite à Dole.');
      final e = r.risque!.evaluation;
      expect(e.statut, EvaluationStatut.nonEvaluable);
      expect(e.motifs, isNotEmpty);
      expect(e.notes.first, honestyContract);
    });
  });
}
