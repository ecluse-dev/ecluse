import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-307 (principe du 26 novembre, point 0) : un SIRET de clé juste sans le
/// mot « siret » et un numéro de TVA à clé fausse sans libellé de TVA sont
/// écartés sans rien dire (mesure P2-303 : 40 / 40 chacun). `Ecluse.redact` les
/// signale « à vérifier » dans `RedactResult.warnings` (type, compte et
/// positions, **jamais la valeur**). **Aucun masquage ne change.** Valeurs
/// synthétiques : SIREN 732 829 320 (clé Luhn juste), SIRET de clé juste
/// 732 829 320 00009, TVA de clé juste FR44 732829320 (on met 51).
void main() {
  const siretGroupes = '732 829 320 00009';
  const siretCompact = '73282932000009';
  const tvaFausse = 'FR51732829320';
  final motifSiret = RegExp(r'SIRET.*sans le mot.*non masqué.*à vérifier');
  final motifTva = RegExp(r'TVA.*sans libellé.*non masqué.*à vérifier');

  Iterable<String> signaux(RedactResult r, RegExp m) =>
      r.warnings.where(m.hasMatch);

  group('SIRET de clé juste sans le mot « siret »', () {
    test('groupes : signalé, sans la valeur ni un de ses groupes', () async {
      final r =
          await Ecluse.redact('Merci de recopier $siretGroupes dans la case.');
      final a = signaux(r, motifSiret).toList();
      expect(a, hasLength(1));
      expect(a.single, contains('1 occurrence'));
      expect(a.single, contains('position 18'));
      for (final g in ['829', '00009', '732']) {
        expect(a.single, isNot(contains(g)));
      }
    });

    test('collé : signalé', () async {
      final r =
          await Ecluse.redact('Valeur reportée : $siretCompact à vérifier.');
      expect(signaux(r, motifSiret), hasLength(1));
    });

    test('deux occurrences : un seul avertissement, compte et positions',
        () async {
      final r = await Ecluse.redact(
          'Valeur $siretGroupes puis, plus loin dans le texte, $siretCompact.');
      final a = signaux(r, motifSiret).toList();
      expect(a, hasLength(1));
      expect(a.single, contains('2 occurrences'));
    });

    test('avec le mot « siret » : masqué, pas de signal', () async {
      final r = await Ecluse.redact('SIRET $siretGroupes noté.');
      expect(r.entities.where((e) => e.type == EntityType.siren), isNotEmpty);
      expect(signaux(r, motifSiret), isEmpty);
    });

    test(
        'quatorze chiffres de clé fausse : pas de signal (un nombre ordinaire)',
        () async {
      final r = await Ecluse.redact('Valeur 73282932000001 à vérifier.');
      expect(signaux(r, motifSiret), isEmpty);
    });

    test('masquage inchangé : aucune entité de plus', () async {
      final r =
          await Ecluse.redact('Pièce jointe 3 : $siretCompact puis signature.');
      // Rien ne couvre les quatorze chiffres d'un seul tenant : le passage n'est
      // pas masqué, il est signalé.
      expect(r.entities.where((e) => e.end - e.start >= 14), isEmpty);
    });
  });

  group('TVA à clé fausse sans libellé', () {
    test('signalée, sans la valeur ni le SIREN', () async {
      final r =
          await Ecluse.redact('Merci de recopier $tvaFausse dans la case.');
      expect(r.entities.where((e) => e.type == EntityType.siren), isEmpty);
      final a = signaux(r, motifTva).toList();
      expect(a, hasLength(1));
      expect(a.single, contains('1 occurrence'));
      expect(a.single, isNot(contains('732')));
      expect(a.single, isNot(contains('FR51')));
    });

    test('avec le libellé « TVA » : masquée à 0,3, pas de signal', () async {
      final r = await Ecluse.redact('TVA $tvaFausse notée.');
      expect(r.entities.where((e) => e.type == EntityType.siren), isNotEmpty);
      expect(signaux(r, motifTva), isEmpty);
    });

    test('clé juste sans libellé : masquée, pas de signal', () async {
      final r = await Ecluse.redact('Valeur FR44732829320 notée.');
      expect(r.entities.where((e) => e.type == EntityType.siren), isNotEmpty);
      expect(signaux(r, motifTva), isEmpty);
    });
  });

  test('texte sans rien : aucun avertissement de ces gardes', () async {
    final r = await Ecluse.redact('Réunion lundi à 14 h, salle 3.');
    expect(signaux(r, motifSiret), isEmpty);
    expect(signaux(r, motifTva), isEmpty);
  });
}
