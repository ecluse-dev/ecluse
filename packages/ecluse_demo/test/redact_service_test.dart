import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// Client LLM factice : renvoie le texte reçu tel quel, et enregistre ce
/// qu'il a effectivement reçu pour vérifier qu'aucun texte original ne
/// franchit la frontière `LlmClient`.
final class _EchoClient implements LlmClient {
  String? lastReceivedText;
  String? lastReceivedInstruction;

  @override
  Future<String> complete(String maskedText,
      {required String instruction}) async {
    lastReceivedText = maskedText;
    lastReceivedInstruction = instruction;
    return maskedText;
  }
}

final class _FailingClient implements LlmClient {
  @override
  Future<String> complete(String maskedText, {required String instruction}) {
    throw const LlmError('Le fournisseur LLM a renvoyé une erreur.');
  }
}

void main() {
  group('RedactService', () {
    test('le LLM ne reçoit jamais le texte original, seulement le masqué',
        () async {
      final client = _EchoClient();
      final service = RedactService(client);

      const text = 'M. Jean Dupont, né le 1 janvier 1980.';
      final result = await service.process(text, instruction: 'Résume.');

      expect(client.lastReceivedText, isNot(contains('Jean Dupont')));
      expect(client.lastReceivedText, contains('[NOM_1]'));
      expect(result.restoredText, text);
    });

    test(
        'le résultat restauré correspond au texte original quand le LLM '
        'renvoie le texte masqué inchangé', () async {
      final client = _EchoClient();
      final service = RedactService(client);

      const text = 'Contactez julien.vasseur@example.fr pour plus '
          "d'informations.";
      final result = await service.process(text, instruction: 'Résume.');

      expect(result.restoredText, text);
      expect(result.maskedText, isNot(contains('julien.vasseur')));
    });

    test('texte en minuscules, consigne capitalisée : noms masqués (P2-137)',
        () async {
      final client = _EchoClient();
      final service = RedactService(client);
      const text = 'rdv avec m. julien chevrier au ssiad de gray demain';
      final result = await service.process(text, instruction: 'Résume.');
      expect(client.lastReceivedText, isNot(contains('chevrier')));
      expect(result.warnings.join(), contains('aucune majuscule'));
      expect(result.restoredText, text);
    });

    test('une personne citée dans la consigne garde le jeton du texte',
        () async {
      final client = _EchoClient();
      final service = RedactService(client);
      await service.process('M. Jean Dupont est arrivé.',
          instruction: 'Résume le cas de M. Dupont.');
      expect(client.lastReceivedInstruction, isNot(contains('Dupont')));
      expect(client.lastReceivedInstruction, contains('[NOM_1]'));
    });

    test('avec référence : rapport de risque et pathologie (P2-141)', () async {
      final ref =
          EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
      await ref.preload();
      await ref.rareDiseases.load();
      final service = RedactService(_EchoClient(), reference: ref);
      final r = await service.process(
          'Mme Sophie Verdier, 74 ans, pneumologue à Thionville, atteinte de '
          'la maladie de Huntington.',
          instruction: 'Résume.');
      expect(r.risque, isNotNull);
      expect(r.risque!.evaluation.spans, isNotEmpty);
      expect([for (final p in r.risque!.pathologies) p.text],
          ['maladie de Huntington']);
    });

    test('sans référence : aucun rapport', () async {
      final r = await RedactService(_EchoClient())
          .process('M. Jean Dupont, 74 ans.', instruction: 'Résume.');
      expect(r.risque, isNull);
    });

    test('une erreur LLM se propage sans planter (LlmError typée)', () async {
      final service = RedactService(_FailingClient());
      await expectLater(
        () => service.process('Texte quelconque.', instruction: 'Résume.'),
        throwsA(isA<LlmError>()),
      );
    });
  });
}
