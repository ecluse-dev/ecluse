import 'dart:io';

import 'package:ecluse_demo/ecluse_demo.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-286 : l'encart « ce que disent les mesures » de la page de démo et le
/// bouton du quatrième exemple. La page est lue telle que livrée
/// (`web/index.html`) : les chiffres viennent de `bench/COMPARATIF.md` et de
/// l'article de benchmark (23 et 24 novembre 2026), pas d'une saisie libre ;
/// chaque barre porte sa réserve et sa date.
void main() {
  final html = File('web/index.html').readAsStringSync();

  String bloc(String id) {
    final debut = html.indexOf('id="$id"');
    expect(debut, greaterThan(0), reason: id);
    final fin = html.indexOf('</figure>', debut);
    return html.substring(debut, fin);
  }

  test('trois mesures, chacune avec une réserve et une date', () {
    for (final id in [
      'mesure-identifiants',
      'mesure-couverture',
      'mesure-a-tort'
    ]) {
      final b = bloc(id);
      expect(b, contains('Réserve.'), reason: id);
      expect(b, contains('Mesuré'), reason: id);
      expect(b, contains('novembre 2026'), reason: id);
    }
  });

  test('identifiants : Écluse 100 %, Presidio 16,7 %', () {
    final b = bloc('mesure-identifiants');
    expect(b, contains('200 000 documents'));
    expect(b, contains('>100 %<'));
    expect(b, contains('>16,7 %<'));
  });

  test('couverture : 397 entités, cinq outils', () {
    final b = bloc('mesure-couverture');
    expect(b, contains('397 entités'));
    for (final v in ['100 %', '70 %', '53 %', '52 %', '47 %']) {
      expect(b, contains('>$v<'), reason: v);
    }
  });

  test('masqués à tort : 480 documents, Écluse 3 %, spaCy 100 %', () {
    final b = bloc('mesure-a-tort');
    expect(b, contains('480 documents'));
    for (final v in ['3 %', '54 %', '93 %', '95 %', '100 %']) {
      expect(b, contains('>$v<'), reason: v);
    }
    // Sous-promettre : la réserve dit que 3 % n'est pas 0.
    expect(b, contains('3 % n\'est pas 0'));
  });

  test('l\'encart dit que Écluse réduit le risque sans l\'annuler', () {
    expect(html, contains('Écluse réduit le risque, il ne l\'annule pas'));
    expect(html, contains('synthétiques'));
  });

  test('un bouton par exemple proposé par la démo', () {
    for (var i = 0; i < demoSamples.length; i++) {
      expect(html, contains('id="sample-$i-btn"'), reason: '$i');
      expect(html, contains('loadSample($i)'), reason: '$i');
    }
  });

  test('le gras de l\'IA est rendu sur les panneaux 3 et 4', () {
    expect(html, contains('rendreGras(highlightTokens(data.llmResponse))'));
    expect(
        html,
        contains(
            'rendreGras(highlightByValues(data.restoredText, data.entities))'));
  });

  test('l\'exemple « note de liaison » passe par le service de démo', () async {
    final service = RedactService(_Gras());
    final r = await service.process(noteDeLiaisonSample.text,
        instruction: noteDeLiaisonSample.instruction);
    expect(r.entities, hasLength(5));
    expect(r.warnings.any((w) => w.contains('clé invalide')), isTrue);
  });
}

final class _Gras implements LlmClient {
  @override
  Future<String> complete(String maskedText,
          {required String instruction}) async =>
      '**Résumé** : $maskedText';
}
