#!/usr/bin/env python3
"""Variantes du détecteur d'établissements pour P2-295 (spec, mesure seule).

Applique à `etablissement_detector.dart` un filtre piloté par la variable
d'environnement `ECLUSE_ETAB` (vide : code actuel). **Jamais commité** : le
script `mesure_type_mot_generique.sh` rétablit le fichier (trap + git checkout).

  generiques : un type en toutes lettres suivi seulement de mots d'une liste
               fermée (Autonomie, D'accueil, Médicalisé, Médicalisée) n'est pas
               masqué ;
  nomprop    : un type en toutes lettres (« Foyer », « Clinique », … : pas un
               sigle) n'est masqué que si le nom qui suit est plus qu'un mot nu :
               guillemets, article ou connecteur, ou au moins deux mots.

Usage : python3 etablissement_variantes_patch.py RACINE_DU_DEPOT
"""
import sys

F = "packages/ecluse_redact/lib/src/heuristics/etablissement_detector.dart"

GARDE = r'''
  static const _generiques = {
    'autonomie', "d'accueil", 'd’accueil', 'médicalisé', 'médicalisée',
    'medicalise', //
  };

  static final RegExp _connecteurNom = RegExp(
      "(?:^|[ \\t])(?:de|du|des|le|la|les|sur|en|aux|au|d['’]|l['’])(?:[ \\t]|\$)",
      caseSensitive: false);

  /// Variante de mesure (P2-295), jamais commitée.
  static bool _garde(String s) {
    final v = Platform.environment['ECLUSE_ETAB'] ?? '';
    if (v.isEmpty) return true;
    String kw = '';
    for (final k in [..._keywords, ...etablissementKeywordsMinuscules]) {
      if (s.startsWith(k) && k.length > kw.length) kw = k;
    }
    if (kw.isEmpty) return true;
    final reste = s.substring(kw.length).trim();
    final mots = reste.split(RegExp(r'[ \t]+')).where((m) => m.isNotEmpty);
    if (v == 'generiques') {
      final gen = mots.isNotEmpty &&
          mots.every((m) => _generiques.contains(m.toLowerCase()));
      return !gen;
    }
    if (v == 'nomprop') {
      final sigle = kw == kw.toUpperCase() || kw == 'IMPro';
      if (sigle) return true;
      if (reste.startsWith('"') || reste.startsWith('«') ||
          reste.startsWith('“')) {
        return true;
      }
      return mots.length >= 2 || _connecteurNom.hasMatch(reste);
    }
    return true;
  }
'''


def main(racine):
    chemin = f"{racine}/{F}"
    s = open(chemin, encoding="utf-8").read()
    assert "_garde(" not in s, "déjà patché"
    s = s.replace("import 'package:ecluse_core/ecluse_core.dart';",
                  "import 'dart:io';\n\nimport 'package:ecluse_core/ecluse_core.dart';", 1)
    s = s.replace("  @override\n  List<DetectedEntity> detect(String text) {",
                  GARDE + "\n  @override\n  List<DetectedEntity> detect(String text) {", 1)
    s = s.replace("    for (final match in _pattern.allMatches(text)) {\n",
                  "    for (final match in _pattern.allMatches(text)) {\n"
                  "      if (!_garde(match.group(0)!)) continue;\n", 1)
    assert "_garde(match" in s
    open(chemin, "w", encoding="utf-8").write(s)


if __name__ == "__main__":
    main(sys.argv[1])
