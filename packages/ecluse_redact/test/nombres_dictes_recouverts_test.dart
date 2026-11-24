import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-281 : une suite dictée **recouverte en partie** par une entité reste
/// signalée « nombre dicté non reconnu ».
///
/// Régression trouvée après P2-275 : l'entité `iban` posée sur le début d'un
/// IBAN dicté abîmé (clé fausse, mot perdu) suffisait à faire croire la suite
/// entière traitée ; le reste de l'identifiant passait en clair sans aucun
/// avertissement (règle 4 : pas d'échec silencieux). Les textes sont
/// synthétiques (corpus de `bench/generate_corpus_dicte_non_valide.py`) ;
/// aucun n'est un identifiant réel.
void main() {
  bool signale(RedactResult r) =>
      r.warnings.any((m) => m.contains('nombre dicté non reconnu'));

  /// Vrai si une suite d'entités contiguës (à un espace près) couvre
  /// [debut, fin) en entier.
  bool couvert(RedactResult r, int debut, int fin) {
    var pos = debut;
    final es = [...r.entities]..sort((a, b) => a.start.compareTo(b.start));
    for (final e in es) {
      if (e.end <= pos) continue;
      if (e.start > pos) break;
      pos = e.end;
      if (pos >= fin) return true;
    }
    return false;
  }

  const cas = <String, (String, int, int)>{
    'clé fausse, entité sur le début': (
      'l iban fr vingt-trois soixante-dix-sept trente-cinq quarante et un '
          'onze o huit vingt-cinq treize quarante et un vingt-cinq '
          'vingt-huit six cent zéro a été refusé par la banque clé invalide',
      7,
      147
    ),
    'mot perdu, entité sur le début': (
      'l iban fr soixante douze vingt dix sept quatre vingt douze treize '
          'cinquante six zéro huit cinquante neuf dix neuf soixante six '
          'trente neuf cinquante cinq cent quatre a été refusé par la '
          'banque clé invalide',
      7,
      165
    ),
    'clé fausse, entité sur la fin seulement': (
      'l iban fr cinquante vingt sept quatre vingt un zéro six quatre vingt '
          'onze zéro neuf r dix huit quarante neuf dix neuf soixante six '
          'cinquante cinq soixante zéro a été refusé par la banque clé '
          'invalide',
      7,
      159
    ),
    'clé fausse, entité sur la quasi-totalité': (
      'merci de régler la facture sur l iban fr soixante treize trente '
          'soixante quinze vingt huit quarante neuf quarante cinq quarante '
          'neuf onze quarante et un cinquante deux zéro huit p soixante zéro '
          'avant le trente',
      38,
      193
    ),
  };

  group('identifiant dicté abîmé, recouvert en partie par une entité', () {
    cas.forEach((nom, c) {
      test(nom, () async {
        final (texte, debut, fin) = c;
        final r = await Ecluse.redact(texte);
        // Soit l'identifiant est masqué en entier, soit l'utilisateur en est
        // averti : jamais ni l'un ni l'autre.
        expect(couvert(r, debut, fin) || signale(r), isTrue);
      });
    });
  });

  test('l\'avertissement ne contient aucune valeur du texte', () async {
    final (texte, _, _) = cas.values.first;
    final r = await Ecluse.redact(texte);
    final w = r.warnings.where((m) => m.contains('nombre dicté non reconnu'));
    for (final m in w) {
      expect(m.contains('vingt'), isFalse);
      expect(m.contains('soixante'), isFalse);
    }
  });
}
