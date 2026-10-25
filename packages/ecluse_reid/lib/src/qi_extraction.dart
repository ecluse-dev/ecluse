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

/// Un nom de commune porté par plusieurs communes (« Saint-Denis », ~3 700
/// communes concernées sur ~35 000). Rendu à l'appelant pour qu'il sache
/// que le lieu est ambigu : le silence donnait F = population de la France
/// entière, un « risque faible » trompeur.
class LieuAmbigu {
  const LieuAmbigu(this.nom, this.candidats);

  /// Nom tel qu'écrit dans le texte.
  final String nom;

  /// Toutes les communes de ce nom.
  final List<Commune> candidats;

  /// Le candidat le plus **prudent** : la plus petite population connue
  /// (F le plus bas, donc le risque le plus élevé). `null` si aucune des
  /// communes n'a de population dans les données.
  Commune? get plusPetite {
    Commune? best;
    for (final c in candidats) {
      final pop = c.pmun;
      if (pop == null) continue;
      if (best == null || pop < best.pmun!) best = c;
    }
    return best;
  }
}

/// Gazetteer des communes (spec §2) : scanne des séquences de 1 à 3 tokens
/// capitalisés et teste chacune contre `GeoHierarchy.communesByName`.
///
/// Un nom **ambigu** (plusieurs communes) n'est plus ignoré : il produit le
/// QI de la commune la plus petite (cas le plus prudent, voir
/// [LieuAmbigu.plusPetite]) et est listé par [extractLieuAmbigu]. L'entrée
/// structurée reste recommandée quand l'ambiguïté compte.
List<Qi> extractLieu(EcluseReference ref, String text) {
  final qis = <Qi>[];
  for (final found in _scanCommunes(ref, text)) {
    if (found.length == 1) {
      qis.add(Qi(QiType.lieu, found.single.code));
    } else {
      final prudent = LieuAmbigu('', found).plusPetite;
      if (prudent != null) qis.add(Qi(QiType.lieu, prudent.code));
    }
  }
  return qis;
}

/// Les noms de commune ambigus du texte, avec leurs candidats.
List<LieuAmbigu> extractLieuAmbigu(EcluseReference ref, String text) {
  final out = <LieuAmbigu>[];
  for (final (nom, candidats) in _scanCommunesNommees(ref, text)) {
    if (candidats.length > 1) out.add(LieuAmbigu(nom, candidats));
  }
  return out;
}

Iterable<List<Commune>> _scanCommunes(EcluseReference ref, String text) =>
    _scanCommunesNommees(ref, text).map((e) => e.$2);

List<(String, List<Commune>)> _scanCommunesNommees(
  EcluseReference ref,
  String text,
) {
  final found = <(String, List<Commune>)>[];
  final tokens = RegExp(r"[A-ZÀ-Ý][\wÀ-ÿ'-]*").allMatches(text).toList();
  for (var i = 0; i < tokens.length; i++) {
    for (var span = 3; span >= 1; span--) {
      if (i + span > tokens.length) continue;
      final candidate =
          text.substring(tokens[i].start, tokens[i + span - 1].end);
      final matches = ref.geo.communesByName(candidate);
      if (matches.isNotEmpty) found.add((candidate, matches));
    }
  }
  return found;
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

/// Résultat détaillé d'une extraction : les QI et les avertissements à
/// montrer à l'utilisateur (aujourd'hui : les lieux ambigus).
class QiExtraction {
  const QiExtraction(this.qis, this.avertissements);

  final List<Qi> qis;
  final List<String> avertissements;
}

/// Comme [extractQis], mais signale explicitement les noms de commune
/// ambigus : le QI retenu est celui de la plus petite commune homonyme.
QiExtraction extractQisDetailed(EcluseReference ref, String text) {
  final avertissements = <String>[
    for (final a in extractLieuAmbigu(ref, text))
      'Lieu « ${a.nom} » ambigu (${a.candidats.length} communes de ce nom) : '
          'estimation faite sur la plus petite '
          '(${a.plusPetite?.libelle ?? "population inconnue"}, '
          'dép. ${a.plusPetite?.dep ?? "?"}) par prudence.',
  ];
  return QiExtraction(extractQis(ref, text), avertissements);
}
