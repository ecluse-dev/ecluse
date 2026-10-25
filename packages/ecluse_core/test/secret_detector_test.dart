import 'dart:math';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

// Aucune valeur de ce fichier n'est un secret réel : chaque chaîne est
// assemblée à l'exécution (préfixe + caractères tirés d'une graine fixe),
// pour ne jamais figurer en clair dans le dépôt ni déclencher un scanner.

const _alnum = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

String _rand(Random rng, int n, [String alphabet = _alnum]) =>
    List.generate(n, (_) => alphabet[rng.nextInt(alphabet.length)]).join();

void main() {
  const detector = SecretDetector();
  final rng = Random(42);

  Future<List<DetectedEntity>> detect(String text) =>
      detector.detect(NormalizedText.identity(text));

  Future<void> expectSingle(
      String text, String value, double confidence) async {
    final entities = await detect(text);
    expect(entities, hasLength(1), reason: text);
    final e = entities.single;
    expect(e.type, EntityType.secret);
    expect(e.value, value);
    expect(text.substring(e.start, e.end), value);
    expect(e.confidence, confidence);
  }

  group('SecretDetector — formats à préfixe', () {
    test('jetons GitHub classiques (ghp_, gho_, ghu_, ghs_, ghr_)', () async {
      for (final p in ['ghp', 'gho', 'ghu', 'ghs', 'ghr']) {
        final token = '${p}_${_rand(rng, 36)}';
        await expectSingle('export GH_TOKEN=$token\n', token, 0.95);
      }
    });

    test('jeton GitHub à granularité fine', () async {
      final token = 'github_pat_${_rand(rng, 82, '$_alnum' '_')}';
      await expectSingle('token "$token";', token, 0.95);
    });

    test('identifiant d\'accès AWS', () async {
      for (final p in ['AKIA', 'ASIA', 'ABIA', 'ACCA']) {
        final id = p + _rand(rng, 16, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567');
        await expectSingle('aws_access_key_id = $id', id, 0.95);
      }
    });

    test('clé Google AIza', () async {
      final key = 'AIza${_rand(rng, 35, '$_alnum' '_-')}';
      await expectSingle('?key=$key&alt=json', key, 0.95);
    });

    test('clé Stripe live (secrète et restreinte)', () async {
      for (final p in ['sk', 'rk']) {
        final key = '${p}_live_${_rand(rng, 24)}';
        await expectSingle('STRIPE=$key', key, 0.95);
      }
    });

    test('jeton Slack', () async {
      final token =
          'xoxb-${_rand(rng, 11, '0123456789')}-${_rand(rng, 12, '0123456789')}'
          '-${_rand(rng, 24)}';
      await expectSingle('slack: $token', token, 0.95);
    });

    test('clé Anthropic', () async {
      final key = 'sk-ant-api03-${_rand(rng, 93, '$_alnum' '_-')}AA';
      await expectSingle('ANTHROPIC_API_KEY=$key', key, 0.95);
    });

    test('clé OpenAI : marqueur T3BlbkFJ, et ancien format à 48 caractères',
        () async {
      final modern = 'sk-proj-${_rand(rng, 30)}T3BlbkFJ${_rand(rng, 30)}';
      await expectSingle('key: $modern', modern, 0.95);
      final legacy = 'sk-${_rand(rng, 48)}';
      await expectSingle('key: $legacy', legacy, 0.95);
    });
  });

  group('SecretDetector — blocs PEM', () {
    String block(String kind, {bool withEnd = true, String eol = '\n'}) {
      final body =
          List.generate(4, (_) => _rand(rng, 64, '$_alnum+/')).join(eol);
      return '-----BEGIN $kind-----$eol$body$eol'
          '${withEnd ? '-----END $kind-----' : ''}';
    }

    test('bloc complet multi-ligne : confiance 1,0', () async {
      for (final kind in ['PRIVATE KEY', 'RSA PRIVATE KEY', 'EC PRIVATE KEY']) {
        final pem = block(kind);
        await expectSingle('clé :\n$pem\nfin', pem, 1.0);
      }
    });

    test('sauts de ligne littéraux (\\n dans du JSON)', () async {
      final pem = block('PRIVATE KEY', eol: r'\n');
      await expectSingle('{"key": "$pem"}', pem, 1.0);
    });

    test('bloc tronqué (sans END) : masqué jusqu\'à la fin du corps, 0,8',
        () async {
      final pem = block('RSA PRIVATE KEY', withEnd: false);
      final entities = await detect('début\n$pem');
      expect(entities, hasLength(1));
      expect(entities.single.confidence, 0.8);
      expect(entities.single.start, 'début\n'.length);
    });

    test('clé publique : pas un secret', () async {
      final pem = block('PUBLIC KEY');
      expect(await detect(pem), isEmpty);
    });
  });

  group('SecretDetector — chaînes de connexion', () {
    test('seul utilisateur:motdepasse est masqué, confiance 0,7', () async {
      final pass = _rand(rng, 14);
      final text =
          'DATABASE_URL=postgres://app_user:$pass@db.exemple.test:5432/prod';
      await expectSingle(text, 'app_user:$pass', 0.7);
    });

    test('schémas pris en charge', () async {
      for (final scheme in [
        'postgresql',
        'mysql',
        'mongodb',
        'mongodb+srv',
        'redis',
        'amqp',
        'https',
      ]) {
        final e = await detect('$scheme://u:${_rand(rng, 10)}@hote.test/x');
        expect(e, hasLength(1), reason: scheme);
      }
    });

    test('sans mot de passe ou mot de passe vide : rien', () async {
      expect(await detect('https://utilisateur@hote.test/page'), isEmpty);
      expect(await detect('postgres://app_user:@hote.test/db'), isEmpty);
      expect(await detect('https://hote.test:8080/chemin'), isEmpty);
    });
  });

  group('SecretDetector — rejets et pièges', () {
    test('mauvais préfixe ou valeur trop courte', () async {
      expect(await detect('ghp_${_rand(rng, 35)}'), isEmpty);
      expect(await detect('ghx_${_rand(rng, 36)}'), isEmpty);
      expect(
          await detect('AKIA${_rand(rng, 15, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')}'),
          isEmpty);
      expect(await detect('AIza${_rand(rng, 34)}'), isEmpty);
      expect(await detect('sk_live_${_rand(rng, 9)}'), isEmpty);
    });

    test('clé Stripe de test : hors v1', () async {
      expect(await detect('sk_test_${_rand(rng, 24)}'), isEmpty);
    });

    test('valeur plus longue collée : pas de découpage', () async {
      expect(await detect('ghp_${_rand(rng, 37)}'), isEmpty);
    });

    test('hachage Git, UUID, SHA-256, base64 de données : rien', () async {
      final hex = '0123456789abcdef';
      expect(await detect('commit ${_rand(rng, 40, hex)}'), isEmpty);
      expect(
          await detect('id ${_rand(rng, 8, hex)}-${_rand(rng, 4, hex)}-'
              '${_rand(rng, 4, hex)}-${_rand(rng, 4, hex)}-${_rand(rng, 12, hex)}'),
          isEmpty);
      expect(await detect('sha256 ${_rand(rng, 64, hex)}'), isEmpty);
      expect(await detect('data ${_rand(rng, 120, '$_alnum+/')}=='), isEmpty);
    });

    test('texte courant en français : rien', () async {
      expect(
        await detect(
            'Le patient sk-8 a pris rendez-vous. Voir https://exemple.test/a.'),
        isEmpty,
      );
    });
  });
}
