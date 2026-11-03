import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Restauration d'un jeton échappé en Markdown (P2-31). Un LLM qui écrit en
/// Markdown échappe souvent les crochets et le soulignement (`\[NOM\_1\]`) : le
/// jeton n'était alors pas restauré. L'échappement est une transformation
/// exacte et sans perte, contrairement à une déformation des chiffres : seule
/// elle est tolérée en plus (jamais d'approximation sur le numéro).
void main() {
  late Map<String, String> carte;
  setUp(() async {
    final r = await Ecluse.redact('M. Jean Dupont a appelé le 01 99 00 12 34.');
    carte = r.mapping;
  });

  const nom = 'Jean Dupont';
  const accepte = {
    r'\[NOM\_1\]': 'crochets et soulignement échappés',
    r'\[NOM_1\]': 'crochets échappés seuls',
    r'[NOM\_1]': 'soulignement échappé seul',
    r'**\[NOM\_1\]**': 'échappé dans du gras',
    r'[ NOM\_1 ]': 'espaces et soulignement échappé',
  };
  for (final MapEntry(key: forme, value: nomCas) in accepte.entries) {
    test('restauré : $nomCas', () {
      final rest = Ecluse.restore('Bonjour $forme, merci.', carte);
      expect(rest, contains(nom), reason: 'forme : $forme');
      expect(rest, isNot(contains('NOM')), reason: 'reste du jeton : $rest');
      expect(rest, isNot(contains(r'\')), reason: 'barre oblique inversée');
    });
  }

  const refuse = {
    r'\[NOM\_10\]': 'chiffre différent',
    r'\[NOM\_2\]': 'autre numéro absent de la carte',
    'NOM_1': 'sans crochets',
    '(NOM_1)': 'autres délimiteurs',
  };
  for (final MapEntry(key: forme, value: nomCas) in refuse.entries) {
    test('jamais restauré : $nomCas', () {
      final rest = Ecluse.restore('Bonjour $forme, merci.', carte);
      expect(rest, isNot(contains(nom)), reason: 'forme : $forme');
    });
  }

  test('les jetons exacts sont restaurés comme avant', () {
    final rest = Ecluse.restore('[NOM_1] puis [TELEPHONE_1].', carte);
    expect(rest, 'Jean Dupont puis 01 99 00 12 34.');
  });
}
