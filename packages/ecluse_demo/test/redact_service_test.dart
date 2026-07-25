import 'package:ecluse_demo/ecluse_demo.dart';
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

    test('une erreur LLM se propage sans planter (LlmError typée)', () async {
      final service = RedactService(_FailingClient());
      await expectLater(
        () => service.process('Texte quelconque.', instruction: 'Résume.'),
        throwsA(isA<LlmError>()),
      );
    });
  });
}
