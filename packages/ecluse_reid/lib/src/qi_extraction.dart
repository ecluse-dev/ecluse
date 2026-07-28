import 'package:ecluse_reference/ecluse_reference.dart';

import 'qi.dart';

/// Extraction texte -> QI (spec §2). Couche mince et déterministe (pas de
/// NER) : le cœur du jalon est l'estimateur (`estimator.dart`), pas cette
/// extraction. Pour la démo/les tests, les QI peuvent aussi être fournis
/// directement structurés — c'est la voie recommandée.

final RegExp _agePattern = RegExp(r'\b(\d{1,3})\s*ans\b', caseSensitive: false);

/// Motif « N ans » (spec §2), âges plausibles 0-120.
List<Qi> extractAge(String text) {
  final qis = <Qi>[];
  for (final match in _agePattern.allMatches(text)) {
    final age = int.parse(match.group(1)!);
    if (age <= 120) qis.add(Qi(QiType.age, age.toString()));
  }
  return qis;
}

/// Gazetteer des communes (spec §2) : scanne des séquences de 1 à 3 tokens
/// capitalisés et teste chacune contre `GeoHierarchy.communesByName`.
/// Couche mince : les homonymes (plusieurs communes du même nom) sont
/// silencieusement ignorés — l'entrée structurée est recommandée quand
/// l'ambiguïté compte.
List<Qi> extractLieu(EcluseReference ref, String text) {
  final qis = <Qi>[];
  final tokens = RegExp(r"[A-ZÀ-Ý][\wÀ-ÿ'-]*").allMatches(text).toList();
  for (var i = 0; i < tokens.length; i++) {
    for (var span = 3; span >= 1; span--) {
      if (i + span > tokens.length) continue;
      final candidate =
          text.substring(tokens[i].start, tokens[i + span - 1].end);
      final matches = ref.geo.communesByName(candidate);
      if (matches.length == 1) {
        qis.add(Qi(QiType.lieu, matches.single.code));
      }
    }
  }
  return qis;
}

/// Mots-clés des 14 spécialités DREES (code numérique) + 4 professions
/// (clé texte) — spec §2. La spécialité "14" (« autre spécialité ») n'a pas
/// de mot-clé fiable et n'est volontairement pas couverte.
const Map<String, String> _specialtyKeywords = {
  'généraliste': '01',
  'médecin généraliste': '01',
  'chirurgien': '02',
  'ophtalmologue': '03',
  'ophtalmologiste': '03',
  'orl': '04',
  'oto-rhino-laryngologiste': '04',
  'anesthésiste': '05',
  'anesthésiste-réanimateur': '05',
  'cardiologue': '06',
  'dermatologue': '07',
  'gastro-entérologue': '08',
  'gastroentérologue': '08',
  'gynécologue': '09',
  'pédiatre': '10',
  'pneumologue': '11',
  'psychiatre': '12',
  'radiologue': '13',
};

const Map<String, String> _professionKeywords = {
  'pharmacien': 'pharmacien',
  'pharmacienne': 'pharmacien',
  'dentiste': 'chirurgien-dentiste',
  'chirurgien-dentiste': 'chirurgien-dentiste',
  'sage-femme': 'sage-femme',
  'podologue': 'pedicure-podologue',
  'pédicure-podologue': 'pedicure-podologue',
};

/// Petite liste de mots-clés des 14 spécialités + professions (spec §2),
/// recherche insensible à la casse sur le texte brut (les clés couvrent les
/// variantes accentuées usuelles).
List<Qi> extractProfession(EcluseReference ref, String text) {
  final lower = text.toLowerCase();
  final qis = <Qi>[];
  for (final entry in _specialtyKeywords.entries) {
    if (lower.contains(entry.key)) qis.add(Qi(QiType.profession, entry.value));
  }
  for (final entry in _professionKeywords.entries) {
    if (lower.contains(entry.key)) qis.add(Qi(QiType.profession, entry.value));
  }
  return qis;
}

/// Combine les trois extractions (concaténation simple, pas de
/// dédoublonnage supplémentaire — couche mince, spec §2).
List<Qi> extractQis(EcluseReference ref, String text) => [
      ...extractProfession(ref, text),
      ...extractLieu(ref, text),
      ...extractAge(text),
    ];
