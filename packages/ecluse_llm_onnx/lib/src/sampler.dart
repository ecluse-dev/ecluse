import 'dart:math';

/// Stratégie d'échantillonnage à partir d'un vecteur de logits.
///
/// Pur Dart, testable sans modèle ONNX. Utilisé par la boucle de
/// génération autoregressive.
abstract interface class Sampler {
  int sample(List<double> logits);
}

/// Greedy : argmax des logits. Déterministe. Recommandé pour
/// l'anonymisation.
class GreedySampler implements Sampler {
  const GreedySampler();

  @override
  int sample(List<double> logits) {
    if (logits.isEmpty) {
      throw ArgumentError.value(logits, 'logits', 'vide');
    }
    var best = 0;
    var bestScore = logits[0];
    for (var i = 1; i < logits.length; i++) {
      if (logits[i] > bestScore) {
        bestScore = logits[i];
        best = i;
      }
    }
    return best;
  }
}

/// top-k + top-p (nucleus) + température.
///
/// Paramètres :
///   - temperature = 0 => bascule sur greedy (déterministe).
///   - topK = 0        => pas de troncature par k.
///   - topP = 1.0      => pas de troncature nucleus.
class TopKPSampler implements Sampler {
  TopKPSampler({
    required this.temperature,
    this.topK = 0,
    this.topP = 1.0,
    int? seed,
  })  : assert(temperature >= 0.0),
        assert(topK >= 0),
        assert(topP > 0.0 && topP <= 1.0),
        _rng = Random(seed);

  final double temperature;
  final int topK;
  final double topP;
  final Random _rng;

  @override
  int sample(List<double> logits) {
    if (temperature == 0.0) {
      return const GreedySampler().sample(logits);
    }

    // 1) température : divise les logits.
    final scaled = List<double>.generate(
      logits.length,
      (i) => logits[i] / temperature,
    );

    // 2) softmax stable.
    final probs = _softmax(scaled);

    // 3) trier par proba décroissante, garder les indices.
    final indexed = List<_ProbEntry>.generate(
      probs.length,
      (i) => _ProbEntry(i, probs[i]),
    )..sort((a, b) => b.p.compareTo(a.p));

    // 4) top-k.
    final kept =
        topK > 0 && topK < indexed.length ? indexed.sublist(0, topK) : indexed;

    // 5) top-p : garde le plus petit préfixe dont la somme >= topP.
    final selected = <_ProbEntry>[];
    var cumul = 0.0;
    for (final entry in kept) {
      selected.add(entry);
      cumul += entry.p;
      if (cumul >= topP) break;
    }

    // 6) renormalisation et tirage.
    final total = selected.fold<double>(0.0, (a, e) => a + e.p);
    if (total <= 0) return selected.first.index;
    final r = _rng.nextDouble() * total;
    var acc = 0.0;
    for (final entry in selected) {
      acc += entry.p;
      if (r <= acc) return entry.index;
    }
    return selected.last.index;
  }

  List<double> _softmax(List<double> xs) {
    var maxVal = xs[0];
    for (var i = 1; i < xs.length; i++) {
      if (xs[i] > maxVal) maxVal = xs[i];
    }
    final exps = List<double>.generate(xs.length, (i) => exp(xs[i] - maxVal));
    final sum = exps.fold<double>(0.0, (a, b) => a + b);
    return List<double>.generate(exps.length, (i) => exps[i] / sum);
  }
}

class _ProbEntry {
  const _ProbEntry(this.index, this.p);
  final int index;
  final double p;
}
