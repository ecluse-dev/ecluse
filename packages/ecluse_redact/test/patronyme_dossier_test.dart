import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Patronyme seul dans un document ultérieur d'un dossier (P2-14). Un
/// patronyme établi par une mention certaine d'un document précédent du
/// dossier amorce la deuxième passe de `NameDetector` : jamais de liste
/// externe, jamais d'apprentissage. Sans dossier, rien ne change.
void main() {
  group('NameDetector avec patronymes connus', () {
    test('un patronyme connu est masqué seul, même en début de phrase', () {
      const detecteur = NameDetector(knownSurnames: {'verdier'});
      final r = detecteur.detect('Verdier a rappelé. Courrier pour Verdier.');
      expect(r.map((e) => e.value), ['Verdier', 'Verdier']);
      expect(r.first.start, 0);
    });

    test('sans patronyme connu, comportement d\'avant', () {
      expect(const NameDetector().detect('Verdier a rappelé.'), isEmpty);
    });

    test('un sigle exclu n\'est jamais retenu', () {
      const detecteur = NameDetector(knownSurnames: {'eva'});
      expect(detecteur.detect('EVA mesurée à 3.'), isEmpty);
    });

    test('patronymeEtabli : civilité, titre, couple sans ambiguïté', () {
      expect(NameDetector.patronymeEtabli('Verdier', 0.9), 'Verdier');
      expect(NameDetector.patronymeEtabli('Dr Nadia Costa', 0.9), 'Costa');
      expect(NameDetector.patronymeEtabli('Sophie Verdier', 0.6), 'Verdier');
      expect(NameDetector.patronymeEtabli('Verdier Sophie', 0.6), 'Verdier');
      // Prénom seul, mot isolé ou couple ambigu : rien d'établi.
      expect(NameDetector.patronymeEtabli('Sophie', 0.5), isNull);
      expect(NameDetector.patronymeEtabli('Verdier', 0.6), isNull);
      expect(NameDetector.patronymeEtabli('Delaunay Fabrier', 0.6), isNull);
    });
  });

  group('Ecluse.redact avec dossier', () {
    test('le patronyme établi dans un document est masqué dans le suivant',
        () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('Verdier a confirmé.', dossier: d);
      // N1 : une mention partielle d'un autre document reçoit un nouveau jeton.
      expect(r.maskedText, '[NOM_2] a confirmé.');
      expect(r.mapping, {'[NOM_2]': 'Verdier'});
    });

    test('avec N2, la mention rejoint l\'identité du premier document',
        () async {
      final d = Dossier(regle: RegleNoms.inclusion);
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('Courrier adressé à Verdier.', dossier: d);
      expect(r.maskedText, 'Courrier adressé à [NOM_1].');
    });

    test('un titre professionnel établit aussi le patronyme', () async {
      final d = Dossier();
      await Ecluse.redact('Le Dr Nadia Costa arrive.', dossier: d);
      final r = await Ecluse.redact('Costa rappelle demain.', dossier: d);
      expect(r.maskedText, contains('[NOM_'));
      expect(r.maskedText, isNot(contains('Costa')));
    });

    test('un prénom seul n\'établit aucun patronyme', () async {
      final d = Dossier();
      await Ecluse.redact('Sophie arrive.', dossier: d);
      final r = await Ecluse.redact('Dupont rappelle.', dossier: d);
      expect(r.maskedText, 'Dupont rappelle.');
    });

    test('sans dossier, le patronyme seul n\'est toujours pas masqué',
        () async {
      final r = await Ecluse.redact('Verdier a rappelé.');
      expect(r.maskedText, 'Verdier a rappelé.');
    });

    test('un dossier ne connaît pas les patronymes d\'un autre dossier',
        () async {
      final a = Dossier();
      final b = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: a);
      final r = await Ecluse.redact('Verdier a confirmé.', dossier: b);
      expect(r.maskedText, 'Verdier a confirmé.');
    });

    test('des détecteurs fournis par l\'appelant ne sont pas modifiés',
        () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      final r = await Ecluse.redact('Verdier a confirmé.',
          dossier: d, detectors: const <Detector>[]);
      expect(r.maskedText, 'Verdier a confirmé.');
    });

    test('coût assumé : un mot courant égal au patronyme est masqué', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Petit arrive.', dossier: d);
      final r = await Ecluse.redact('Petit déjeuner servi à 8 h.', dossier: d);
      expect(r.maskedText, contains('[NOM_'));
    });

    test('un dossier fermé n\'a plus aucun patronyme', () async {
      final d = Dossier();
      await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      d.fermer();
      await expectLater(Ecluse.redact('Verdier a confirmé.', dossier: d),
          throwsA(isA<DossierFermeException>()));
    });
  });
}
