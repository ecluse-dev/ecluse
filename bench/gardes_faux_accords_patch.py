#!/usr/bin/env python3
"""Patch TEMPORAIRE de mesure (P2-272) : branche des gardes candidates dans
quatre détecteurs, activées par la variable d'environnement ECLUSE_GARDE
(liste séparée par des virgules). Jamais commité dans `lib/` : le script
`mesure_gardes_faux_accords.sh` l'applique, mesure, puis rétablit les fichiers
par `git checkout`. Sans ECLUSE_GARDE, le comportement est celui de `main`.

Usage : python3 bench/gardes_faux_accords_patch.py <racine du dépôt>
"""
import sys
from pathlib import Path

R = Path(sys.argv[1])


def patch(chemin, avant, apres, nb=1):
    p = R / chemin
    t = p.read_text(encoding="utf-8")
    assert t.count(avant) == nb, (chemin, avant[:50], t.count(avant))
    p.write_text(t.replace(avant, apres), encoding="utf-8")


def ajoute_import_et_fin(chemin, code):
    p = R / chemin
    t = p.read_text(encoding="utf-8")
    p.write_text("import 'dart:io' show Platform;\n" + t + "\n" + code,
                 encoding="utf-8")


COMMUN = r"""
final Set<String> _gardesMesure =
    (Platform.environment['ECLUSE_GARDE'] ?? '').split(',').toSet();
final RegExp _sepMesure = RegExp(r'[\s\-./]');
"""

IBAN = COMMUN + r"""
bool gardeIbanMesure(String text, int start, int end) {
  if (_gardesMesure.length == 1 && _gardesMesure.first.isEmpty) return true;
  final s = text.substring(start, end);
  final n = s.replaceAll(_sepMesure, '').toUpperCase();
  if (_gardesMesure.contains('iban_g45') && _sepMesure.hasMatch(s)) {
    final l = s.split(RegExp(r'[\s\-./]+')).map((e) => e.length).toList();
    final quatre = l.length == 7 &&
        l.sublist(0, 6).every((x) => x == 4) &&
        l[6] == 3;
    final rib = l.length == 5 && l[0] == 4 && l[1] == 5 && l[2] == 5 &&
        l[3] == 11 && l[4] == 2;
    final cinq = l.length == 6 && l[0] == 4 &&
        l.sublist(1, 5).every((x) => x == 5) && l[5] == 3;
    if (!quatre && !rib && !cinq) return false;
  }
  if (_gardesMesure.contains('iban_g4') && _sepMesure.hasMatch(s)) {
    final p = s.split(RegExp(r'[\s\-./]+'));
    final l = p.map((e) => e.length).toList();
    final quatre = l.length == 7 &&
        l.sublist(0, 6).every((x) => x == 4) &&
        l[6] == 3;
    final rib = l.length == 5 && l[0] == 4 && l[1] == 5 && l[2] == 5 &&
        l[3] == 11 && l[4] == 2;
    if (!quatre && !rib) return false;
  }
  if (_gardesMesure.contains('iban_cle2') &&
      !RegExp(r'^FR[0-9]{2}').hasMatch(n)) {
    return false;
  }
  if (_gardesMesure.contains('iban_ocr3') &&
      RegExp(r'[oOlI]').allMatches(n.substring(4)).length > 3) {
    return false;
  }
  if (_gardesMesure.contains('iban_motcle')) {
    final a = start < 80 ? 0 : start - 80;
    final b = end + 40 > text.length ? text.length : end + 40;
    if (!RegExp(r'iban|rib\b|compte|virement|banque|bancaire|coordonn',
            caseSensitive: false)
        .hasMatch(text.substring(a, b))) {
      return false;
    }
  }
  return true;
}
"""

NIR = COMMUN + r"""
bool gardeNirMesure(String text, int start, int end) {
  if (_gardesMesure.length == 1 && _gardesMesure.first.isEmpty) return true;
  final s = text.substring(start, end);
  final lettres = RegExp(r'[oO]').allMatches(s).length;
  if (_gardesMesure.contains('nir_sanslettre') && lettres > 0) return false;
  if (_gardesMesure.contains('nir_unelettre') && lettres > 1) return false;
  if (_gardesMesure.contains('nir_suite') &&
      RegExp(r'^[ .\-/][0-9oOlI]{1,4}(?![0-9A-Za-z])')
          .hasMatch(text.substring(end))) {
    return false;
  }
  if (_gardesMesure.contains('nir_suitelettre')) {
    final m = RegExp(r'^[ .\-/][0-9oOlI]{1,4}(?![0-9A-Za-z])')
        .firstMatch(text.substring(end));
    if (m != null && RegExp(r'[oOlI]').hasMatch(m.group(0)!)) return false;
  }
  if (_gardesMesure.contains('nir_motcle')) {
    final a = start < 80 ? 0 : start - 80;
    final b = end + 40 > text.length ? text.length : end + 40;
    if (!RegExp(
            r'nir|s[ée]curit[ée]|sociale|s[ée]cu\b|assur[ée]|patient|vitale|\bss\b',
            caseSensitive: false)
        .hasMatch(text.substring(a, b))) {
      return false;
    }
  }
  return true;
}
"""

FINESS = COMMUN + r"""
bool gardeFinessMesure(String raw, int start, int end, bool contexte) {
  if (_gardesMesure.length == 1 && _gardesMesure.first.isEmpty) return true;
  if (contexte) return true;
  if (_gardesMesure.contains('finess_sanscontexte')) return false;
  if (_gardesMesure.contains('finess_suite') &&
      RegExp(r'^[\s  .\-/]?[0-9oOlI]{1,3}(?![0-9A-Za-z])')
          .hasMatch(raw.substring(end))) {
    return false;
  }
  if (_gardesMesure.contains('finess_suitelettre')) {
    final m = RegExp(r'^[\s\u00A0\u202F.\-/]?[0-9oOlI]{1,3}(?![0-9A-Za-z])')
        .firstMatch(raw.substring(end));
    if (m != null && RegExp(r'[oOlI]').hasMatch(m.group(0)!)) return false;
  }
  return true;
}
"""

ADRESSE = COMMUN + r"""
bool gardeAdresseMesure(String value) {
  if (_gardesMesure.length == 1 && _gardesMesure.first.isEmpty) return true;
  final reste = value.length > 5 ? value.substring(5).trim() : '';
  if (_gardesMesure.contains('adr_sanschiffre') &&
      RegExp(r'[0-9]').hasMatch(reste)) {
    return false;
  }
  if (_gardesMesure.contains('adr_confusables')) {
    final mot = reste.split(RegExp(r'\s+')).first;
    if (mot.isNotEmpty && RegExp(r'^[0-9oOlI]+$').hasMatch(mot)) return false;
  }
  return true;
}
"""

# IBAN
patch("packages/ecluse_core/lib/src/detectors/iban_detector.dart",
      "      results.add(\n        DetectedEntity(\n          type: EntityType.iban,\n          start: match.start,\n          end: match.end,\n          value: text.substring(match.start, match.end),\n          confidence: confidence,",
      "      if (!gardeIbanMesure(text, match.start, match.end)) continue;\n      results.add(\n        DetectedEntity(\n          type: EntityType.iban,\n          start: match.start,\n          end: match.end,\n          value: text.substring(match.start, match.end),\n          confidence: confidence,")
ajoute_import_et_fin("packages/ecluse_core/lib/src/detectors/iban_detector.dart", IBAN)
# NIR
patch("packages/ecluse_core/lib/src/detectors/nir_detector.dart",
      "      if (NirDetector._cleJuste(normalise)) continue;\n      results.add(",
      "      if (NirDetector._cleJuste(normalise)) continue;\n      if (!gardeNirMesure(text, match.start, match.end)) continue;\n      results.add(")
ajoute_import_et_fin("packages/ecluse_core/lib/src/detectors/nir_detector.dart", NIR)
# FINESS
patch("packages/ecluse_core/lib/src/detectors/finess_detector.dart",
      "      final siren = !hasContext && _sirenKeyword.hasMatch(fenetre);\n",
      "      final siren = !hasContext && _sirenKeyword.hasMatch(fenetre);\n      if (!gardeFinessMesure(raw, start, end, hasContext || siren)) continue;\n")
ajoute_import_et_fin("packages/ecluse_core/lib/src/detectors/finess_detector.dart", FINESS)
# Adresse
patch("packages/ecluse_redact/lib/src/heuristics/adresse_detector.dart",
      "      if (_estIntroduitParQuantite(text, start)) continue;\n",
      "      if (_estIntroduitParQuantite(text, start)) continue;\n      if (!gardeAdresseMesure(text.substring(start, end))) continue;\n")
ajoute_import_et_fin("packages/ecluse_redact/lib/src/heuristics/adresse_detector.dart", ADRESSE)
print("patch de mesure appliqué")
