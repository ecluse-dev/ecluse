import 'dart:async';
import 'dart:math';

import 'package:test/test.dart';

/// Vérifie qu'un coût croît linéairement, sans borne en millisecondes (P2-100).
///
/// Pourquoi : une borne absolue (« moins de 3 s ») dépend de la machine. Sur
/// un serveur d'intégration continue partagé, elle échouait sans régression
/// du code (3 320 ms pour 3 000 le 2 novembre 2026, PR #242). Le défaut que ces
/// tests doivent attraper est une croissance quadratique ou pire : on compare
/// donc deux tailles. Quadrupler l'entrée multiplie le temps par environ 4 si
/// le coût est linéaire, par environ 16 s'il est quadratique ; le seuil de 8
/// passe le bruit et attrape la régression.
///
/// Le meilleur de plusieurs essais écarte la compilation des motifs au premier
/// passage. Sous [plancherMs] pour la grande taille, le coût est négligeable
/// quelle que soit sa croissance et le rapport, dominé par le bruit, n'est pas
/// évalué.
Future<void> expectCroissanceLineaire(
  FutureOr<void> Function(int n) f, {
  required int n,
  double seuil = 8,
  int essais = 3,
  int plancherMs = 50,
  String raison = '',
}) async {
  final petit = await _meilleurTemps(() => f(n), essais);
  final grand = await _meilleurTemps(() => f(4 * n), essais);
  if (grand < plancherMs * 1000) return;
  expect(grand / max(petit, 1), lessThan(seuil),
      reason: '$raison n = $n : $petit µs ; 4n : $grand µs'.trim());
}

Future<int> _meilleurTemps(FutureOr<void> Function() f, int essais) async {
  var meilleur = -1;
  for (var essai = 0; essai < essais; essai++) {
    final sw = Stopwatch()..start();
    await f();
    final us = sw.elapsedMicroseconds;
    if (meilleur < 0 || us < meilleur) meilleur = us;
  }
  return meilleur;
}
