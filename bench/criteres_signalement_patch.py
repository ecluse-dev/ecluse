#!/usr/bin/env python3
"""Patch TEMPORAIRE de mesure (P2-280) : à chaque appel de `_suitesNonReconnues`
(un par document), écrit dans le fichier nommé par la variable d'environnement
ECLUSE_CRITERES une ligne « DOC » puis, pour chaque suite d'au moins 9
mots-nombres, une ligne JSON : nombre de mots-nombres, bornes, nombre de jetons,
longueur en caractères, les 100 caractères qui précèdent, les 20 qui suivent, et
si une entité masquée recouvre la suite. Les corpus étant synthétiques, ces
fragments ne sont pas des données réelles ; ils restent dans le fichier de
mesure, jamais dans un message ou une sortie console de `lib/`.

Jamais commité dans `lib/` : `mesure_criteres_signalement.sh` l'applique, mesure,
puis rétablit les fichiers par `git checkout`. Sans ECLUSE_CRITERES, le
comportement est celui de `main`.

Usage : python3 bench/criteres_signalement_patch.py <racine du dépôt>
"""
import sys
from pathlib import Path

R = Path(sys.argv[1])


def patch(chemin, avant, apres):
    p = R / chemin
    t = p.read_text(encoding="utf-8")
    assert t.count(avant) == 1, (chemin, avant[:50], t.count(avant))
    p.write_text(t.replace(avant, apres), encoding="utf-8")


patch("packages/ecluse_redact/lib/src/ecluse.dart",
      "import 'dart:async';\n",
      "import 'dart:async';\nimport 'dart:convert' show jsonEncode;\n"
      "import 'dart:io' show File, FileMode, Platform;\n")
patch("packages/ecluse_redact/lib/src/nombres_dictes.dart",
      """  if (suites.isEmpty) return const [];
  final r = <int>[];
  var k = 0;
  for (final s in suites) {
    while (k < entites.length && entites[k].end <= s.debut) {
      k++;
    }
    final recouvert = k < entites.length && entites[k].start < s.fin;
""",
      """  final sortieMesure = Platform.environment['ECLUSE_CRITERES'];
  if (sortieMesure != null) {
    File(sortieMesure).writeAsStringSync('DOC\\n', mode: FileMode.append);
  }
  if (suites.isEmpty) return const [];
  final r = <int>[];
  var k = 0;
  for (final s in suites) {
    while (k < entites.length && entites[k].end <= s.debut) {
      k++;
    }
    final recouvert = k < entites.length && entites[k].start < s.fin;
    if (sortieMesure != null) {
      File(sortieMesure).writeAsStringSync(
          '${jsonEncode({
                'mots': s.mots,
                'debut': s.debut,
                'fin': s.fin,
                'jetons': s.jetons.length,
                'chars': s.fin - s.debut,
                'avant': text.substring(s.debut > 100 ? s.debut - 100 : 0, s.debut),
                'apres': text.substring(
                    s.fin, s.fin + 20 > text.length ? text.length : s.fin + 20),
                'couvert': recouvert,
              })}\\n',
          mode: FileMode.append);
    }
""")
print("patch de mesure appliqué")
