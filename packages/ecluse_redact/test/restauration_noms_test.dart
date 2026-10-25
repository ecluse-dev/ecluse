import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Relecture d'octobre 2026 (P1-26) : la carte de restauration doit suivre
/// ce que dit `LIMITES.md` §5.3 (forme la plus complète, aucun caractère
/// perdu), et deux personnes de sexes différents ne doivent pas être
/// fusionnées sur un patronyme commun.
void main() {
  Future<(RedactResult, String)> aller(String texte) async {
    final r = await Ecluse.redact(texte);
    return (r, Ecluse.restore(r.maskedText, r.mapping));
  }

  group('forme la plus complète', () {
    test('patronyme seul puis titre + prénom + nom', () async {
      final (r, restaure) = await aller(
        'Costa arrive. Dr Nadia Costa part. Nadia Costa revient.',
      );
      expect(r.mapping.values.toSet(), {'Dr Nadia Costa'});
      // Aucune mention ne perd le prénom ni le titre à la restauration.
      expect(restaure, contains('Nadia'));
      expect(restaure.contains('Dr Nadia Costa part'), isTrue);
      expect(restaure.split('Costa').length - 1, 3);
    });

    test('titre + patronyme puis titre + prénom + nom', () async {
      final (r, restaure) = await aller(
        'Dr Costa arrive. Plus tard Dr Nadia Costa part.',
      );
      expect(r.mapping.values.toSet(), {'Dr Nadia Costa'});
      expect(restaure, isNot(contains('Dr Costa')));
    });

    test('mention complète en premier : inchangé', () async {
      final (r, restaure) = await aller(
        'Mme Alice Martin est là. Mme Martin part.',
      );
      expect(r.mapping.values.toSet(), {'Alice Martin'});
      expect(restaure, 'Mme Alice Martin est là. Mme Alice Martin part.');
    });
  });

  group('deux personnes de sexes différents, même patronyme', () {
    test('M. Jean Dupont et Mme Dupont : deux jetons, aller-retour exact',
        () async {
      const texte = 'M. Jean Dupont et son épouse Mme Dupont.';
      final (r, restaure) = await aller(texte);
      expect(r.mapping, hasLength(2));
      expect(restaure, texte);
    });

    test('Mme Dupont puis M. Pierre Dupont : deux jetons', () async {
      const texte = 'Mme Dupont est venue. M. Pierre Dupont aussi.';
      final (r, restaure) = await aller(texte);
      expect(r.mapping, hasLength(2));
      expect(restaure, texte);
    });

    test('même sexe, même patronyme : toujours fusionnés', () async {
      final (r, _) = await aller('M. Jean Dupont est là. M. Dupont part.');
      expect(r.mapping, hasLength(1));
    });

    test('sans civilité : fusion inchangée', () async {
      final (r, _) = await aller('Dr Nadia Costa part. Costa revient.');
      expect(r.mapping, hasLength(1));
    });
  });
}
