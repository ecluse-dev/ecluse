import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Restauration d'un jeton après une barre oblique inversée (P2-72). Un chemin
/// Windows (`C:\Users\Jean Dupont\Documents`) devient `C:\Users\[NOM_1]\Documents` :
/// la tolérance à l'échappement Markdown (P2-31) consommait la barre oblique devant
/// le jeton à la restauration (`C:\UsersJean Dupont\Documents`), donc le texte
/// restauré n'était pas celui de l'utilisateur. L'échappement Markdown échappe les
/// **deux** crochets ; une barre oblique devant le seul crochet ouvrant est un
/// séparateur de chemin et reste.
void main() {
  late Map<String, String> carte;
  setUp(() async {
    final r = await Ecluse.redact('M. Jean Dupont a appelé le 01 99 00 12 34.');
    carte = r.mapping;
  });

  test('chemin Windows : la barre oblique avant le jeton est conservée', () {
    final rest = Ecluse.restore(r'C:\Users\[NOM_1]\Documents', carte);
    expect(rest, r'C:\Users\Jean Dupont\Documents');
  });

  test('barre oblique devant le seul crochet ouvrant : conservée', () {
    expect(Ecluse.restore(r'a\[NOM_1] b', carte), r'a\Jean Dupont b');
  });

  test('chemin avec deux jetons', () {
    final rest = Ecluse.restore(r'\\[NOM_1]\[TELEPHONE_1]', carte);
    expect(rest, r'\\Jean Dupont\01 99 00 12 34');
  });

  test('de bout en bout : un chemin Windows masqué puis restauré est identique',
      () async {
    const texte = r'Dossier dans C:\Users\Jean Dupont\Documents\bilan.pdf';
    final r = await Ecluse.redact(texte);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('l\'échappement Markdown complet reste restauré', () {
    for (final forme in [
      r'\[NOM\_1\]',
      r'\[NOM_1\]',
      r'[NOM\_1]',
      r'**\[NOM\_1\]**'
    ]) {
      final rest = Ecluse.restore('Bonjour $forme.', carte);
      expect(rest, contains('Jean Dupont'), reason: forme);
      expect(rest, isNot(contains(r'\')), reason: forme);
    }
  });
}
