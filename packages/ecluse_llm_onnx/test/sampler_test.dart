import 'package:ecluse_llm_onnx/ecluse_llm_onnx.dart';
import 'package:test/test.dart';

void main() {
  group('GreedySampler', () {
    const sampler = GreedySampler();

    test('argmax simple', () {
      expect(sampler.sample([0.1, 0.5, 0.3, 0.05, 0.05]), 1);
    });

    test('argmax avec plusieurs pics — prend le premier', () {
      expect(sampler.sample([0.5, 0.5, 0.0]), 0);
    });

    test('déterministe entre appels', () {
      final logits = [0.1, 0.9, 0.2];
      final results = List.generate(20, (_) => sampler.sample(logits));
      expect(results.toSet(), {1});
    });

    test('lève si vecteur vide', () {
      expect(() => sampler.sample(const []), throwsArgumentError);
    });
  });

  group('TopKPSampler', () {
    test('temperature=0 => bascule sur greedy', () {
      final s = TopKPSampler(temperature: 0.0, seed: 42);
      final logits = [0.1, 0.9, 0.2, 0.8];
      final ids = List.generate(30, (_) => s.sample(logits));
      expect(ids.toSet(), {1});
    });

    test('seed identique => sortie reproductible', () {
      final logits = [1.0, 2.0, 0.5, 0.1, 3.0];
      final a = TopKPSampler(temperature: 1.0, seed: 7);
      final b = TopKPSampler(temperature: 1.0, seed: 7);
      final samplesA = List.generate(50, (_) => a.sample(logits));
      final samplesB = List.generate(50, (_) => b.sample(logits));
      expect(samplesA, equals(samplesB));
    });

    test('top_k=1 => déterministe (équivaut à greedy)', () {
      final s = TopKPSampler(temperature: 1.0, topK: 1, seed: 1);
      final logits = [0.1, 5.0, 0.2, 0.3];
      final ids = List.generate(20, (_) => s.sample(logits));
      expect(ids.toSet(), {1});
    });

    test('top_p=0.01 concentre sur le top 1', () {
      final s = TopKPSampler(temperature: 1.0, topP: 0.01, seed: 3);
      // Logits très asymétriques => softmax pique.
      final logits = [10.0, 0.0, 0.0, 0.0];
      final ids = List.generate(30, (_) => s.sample(logits));
      expect(ids.toSet(), {0});
    });

    test('top_p=1.0 échantillonne toute la distribution', () {
      final s = TopKPSampler(temperature: 1.5, topP: 1.0, seed: 5);
      // Distribution plate => on doit voir plusieurs indices sortir.
      final logits = [1.0, 1.0, 1.0, 1.0];
      final ids = List.generate(200, (_) => s.sample(logits));
      expect(ids.toSet().length, greaterThan(1));
    });
  });
}
