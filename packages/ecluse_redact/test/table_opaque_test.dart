import 'dart:async';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-193 : la table de correspondance ne s'affiche jamais en clair.
///
/// `RedactResult.mapping` était un `Map<String, String>` : `print(result.mapping)`
/// écrivait toutes les valeurs (vu en sonde le 15 novembre, P2-189). Ces tests
/// n'utilisent que ce que fait un appelant distrait — interpolation, `print`,
/// `toString`, message d'exception — et vérifient qu'aucune valeur ni aucun
/// jeton n'en sort. Ils échouent sur `main` (avant le type dédié).
/// Valeurs synthétiques.
void main() {
  const texte =
      'M. Jean Dupont, NIR 1 85 05 78 006 084 91, joint le 06 12 34 56 78.';
  const valeurs = ['Dupont', '185057800608491', '1 85 05 78', '06 12 34 56 78'];

  void sansValeur(String sortie, String contexte) {
    for (final v in valeurs) {
      expect(sortie, isNot(contains(v)), reason: contexte);
    }
    expect(sortie, isNot(contains('[NOM_1]')), reason: '$contexte (jeton)');
  }

  test('interpolation et toString : aucune valeur, aucun jeton', () async {
    final r = await Ecluse.redact(texte);
    sansValeur('${r.mapping}', 'interpolation');
    sansValeur(r.mapping.toString(), 'toString');
    sansValeur('table : ${r.mapping}', 'interpolation dans un message');
  });

  test('print : rien d\'exploitable sur la sortie', () async {
    final r = await Ecluse.redact(texte);
    final lignes = <String>[];
    runZoned(
      () => print(r.mapping),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, ligne) => lignes.add(ligne),
      ),
    );
    sansValeur(lignes.join('\n'), 'print');
  });

  test('message d\'exception : aucune valeur', () async {
    final r = await Ecluse.redact(texte);
    final e = Exception('table inattendue : ${r.mapping}');
    sansValeur(e.toString(), 'exception');
    final s = StateError('${r.mapping}');
    sansValeur(s.toString(), 'StateError');
  });

  test('RedactResult entier : le toString par défaut ne montre pas la table',
      () async {
    final r = await Ecluse.redact(texte);
    sansValeur('${r.mapping.runtimeType}', 'type');
    sansValeur('$r', 'RedactResult');
  });
}
