import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

// Valeur fabriquée à l'exécution (aucun secret réel, rien de détectable en
// clair dans le dépôt).
final String _token =
    'ghp_${'aB3dE6gH9jK2mN5pQ8sT1vW4yZ7cF0hJ3kL6' * 2}'.substring(0, 4 + 36);

void main() {
  final text = 'Voici mon jeton $_token pour le dépôt.';

  test('le secret est masqué par [SECRET_1] et signalé', () async {
    final result = await Ecluse.redact(text);
    expect(result.maskedText, 'Voici mon jeton [SECRET_1] pour le dépôt.');
    expect(result.maskedText, isNot(contains(_token)));
    expect(result.warnings, hasLength(1));
    expect(result.warnings.single, contains('révoquer'));
  });

  test('restauration désactivée par défaut : le secret ne revient pas',
      () async {
    final result = await Ecluse.redact(text);
    expect(result.mapping.values, isNot(contains(_token)));
    final restored = Ecluse.restore('Réponse sur [SECRET_1].', result.mapping);
    expect(restored, 'Réponse sur [SECRET_1].');
  });

  test('restoreSecrets: true rétablit le secret', () async {
    final result = await Ecluse.redact(text, restoreSecrets: true);
    expect(result.mapping['[SECRET_1]'], _token);
    expect(Ecluse.restore('Réponse sur [SECRET_1].', result.mapping),
        'Réponse sur $_token.');
  });

  test('mode strict : refus explicite, sans écho du secret', () async {
    await expectLater(
      Ecluse.redact(text, refuseSecrets: true),
      throwsA(
        isA<SecretsRefusedException>()
            .having((e) => e.count, 'count', 1)
            .having((e) => e.toString(), 'message', isNot(contains(_token))),
      ),
    );
  });

  test('mode strict sans secret : traitement normal', () async {
    final result = await Ecluse.redact('Rien à signaler.', refuseSecrets: true);
    expect(result.maskedText, 'Rien à signaler.');
    expect(result.warnings, isEmpty);
  });

  test('un texte sans secret n\'a aucun avertissement', () async {
    final result = await Ecluse.redact('M. Jean Dupont');
    expect(result.warnings, isEmpty);
  });

  test('deux occurrences du même secret : un seul jeton, un seul avertissement',
      () async {
    final result = await Ecluse.redact('$_token puis $_token');
    expect(result.maskedText, '[SECRET_1] puis [SECRET_1]');
    expect(result.warnings, hasLength(1));
  });
}
