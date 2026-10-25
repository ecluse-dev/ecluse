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

// ---------------------------------------------------------------------------
// Extraction positionnée (P2-03b). Strictement additive : les fonctions
// ci-dessus gardent leur signature et leur comportement.
// ---------------------------------------------------------------------------

/// Un quasi-identifiant repéré dans le texte, avec sa position.
///
/// [start] et [end] sont des index de code units dans le texte d'origine
/// (`texte.substring(start, end) == text`), comme `DetectedEntity`.
class QiSpan {
  const QiSpan({
    required this.type,
    required this.start,
    required this.end,
    required this.text,
    this.qi,
    this.candidats = const [],
  });

  final QiType type;
  final int start;
  final int end;

  /// Le texte tel qu'écrit.
  final String text;

  /// Le QI structuré, ou `null` dans un seul cas : un nom de commune ambigu
  /// dont aucun homonyme n'a de population connue (le cas prudent est alors
  /// indéterminable).
  final Qi? qi;

  /// Pour un lieu : toutes les communes de ce nom (plusieurs si ambigu).
  final List<Commune> candidats;

  /// Le nom de lieu est porté par plusieurs communes.
  bool get ambigu => candidats.length > 1;
}

/// Résultat de [extractQiSpans] : les QI positionnés, triés par position, et
/// les avertissements à montrer (lieux ambigus).
class QiSpanExtraction {
  const QiSpanExtraction(this.spans, this.avertissements);

  final List<QiSpan> spans;
  final List<String> avertissements;
}

/// Garde, parmi des candidats pouvant se chevaucher, les plus longs sans
/// chevauchement (à longueur égale, le plus à gauche), triés par position.
///
/// Évite qu'un mot-clé inclus dans un plus long (« dentiste » dans
/// « chirurgien-dentiste ») ou qu'un sous-nom (« Mans » dans « Le Mans »)
/// produise un second QI du même type.
List<QiSpan> _sansChevauchement(List<QiSpan> candidats) {
  final parLongueur = [...candidats]..sort((a, b) {
      final longueur = (b.end - b.start) - (a.end - a.start);
      return longueur != 0 ? longueur : a.start - b.start;
    });
  final gardes = <QiSpan>[];
  for (final c in parLongueur) {
    if (!gardes.any((g) => c.start < g.end && g.start < c.end)) gardes.add(c);
  }
  return gardes..sort((a, b) => a.start - b.start);
}

/// Mots-clés cherchés comme mots entiers (jamais au milieu d'un mot : « orl »
/// n'est pas dans « Orléans »), sans tenir compte de la casse. Mêmes tables
/// que [extractProfession].
List<QiSpan> _professionSpans(String text) {
  final candidats = <QiSpan>[];
  void parcourt(Map<String, String> table) {
    for (final entry in table.entries) {
      final motif = RegExp(
        '(?<![\\p{L}\\p{N}])${RegExp.escape(entry.key)}(?![\\p{L}\\p{N}])',
        unicode: true,
        caseSensitive: false,
      );
      for (final m in motif.allMatches(text)) {
        candidats.add(QiSpan(
          type: QiType.profession,
          start: m.start,
          end: m.end,
          text: m.group(0)!,
          qi: Qi(QiType.profession, entry.value),
        ));
      }
    }
  }

  parcourt(_specialtyKeywords);
  parcourt(_professionKeywords);
  return _sansChevauchement(candidats);
}

/// Même gazetteer que [extractLieu] (séquences de 1 à 3 mots capitalisés),
/// avec positions. Deux mots ne sont réunis que s'ils ne sont séparés que
/// d'espaces : un nom de lieu ne traverse pas une ponctuation ou un saut de
/// ligne (« Dole. Belfort » n'est pas un candidat).
List<QiSpan> _lieuSpans(EcluseReference ref, String text) {
  final mots = RegExp(r"[A-ZÀ-Ý][\wÀ-ÿ'-]*").allMatches(text).toList();
  final seulementEspaces = RegExp('^[  ]+\$');
  final candidats = <QiSpan>[];
  for (var i = 0; i < mots.length; i++) {
    for (var longueur = 1;
        longueur <= 3 && i + longueur <= mots.length;
        longueur++) {
      var contigus = true;
      for (var k = 0; k < longueur - 1; k++) {
        final entre = text.substring(mots[i + k].end, mots[i + k + 1].start);
        if (!seulementEspaces.hasMatch(entre)) {
          contigus = false;
          break;
        }
      }
      if (!contigus) break;
      final start = mots[i].start;
      final end = mots[i + longueur - 1].end;
      final nom = text.substring(start, end);
      final communes = ref.geo.communesByName(nom);
      if (communes.isEmpty) continue;
      Qi? qi;
      if (communes.length == 1) {
        qi = Qi(QiType.lieu, communes.single.code);
      } else {
        final prudent = LieuAmbigu(nom, communes).plusPetite;
        if (prudent != null) qi = Qi(QiType.lieu, prudent.code);
      }
      candidats.add(QiSpan(
        type: QiType.lieu,
        start: start,
        end: end,
        text: nom,
        qi: qi,
        candidats: communes,
      ));
    }
  }
  return _sansChevauchement(candidats);
}

/// Même règle que [extractAge] (« N ans », 0 à 120), avec positions : le span
/// couvre les chiffres, l'espace éventuel (insécable compris) et « ans ».
List<QiSpan> _ageSpans(String text) {
  final spans = <QiSpan>[];
  for (final m in _agePattern.allMatches(text)) {
    final age = int.parse(m.group(1)!);
    if (age > 120) continue;
    spans.add(QiSpan(
      type: QiType.age,
      start: m.start,
      end: m.end,
      text: m.group(0)!,
      qi: Qi(QiType.age, age.toString()),
    ));
  }
  return spans;
}

/// Extrait les QI du texte **avec leur position**, sans exception pour une
/// entrée quelconque.
///
/// Différences voulues avec [extractQis] (qui reste inchangée) : mots-clés
/// cherchés comme mots entiers, plus long candidat seulement quand plusieurs se
/// recouvrent, nom de lieu contigu (sans ponctuation entre ses mots). Mêmes
/// vocabulaires, mêmes règles d'âge et de commune ambiguë (la plus petite
/// commune homonyme, par prudence). Le **rappel** n'est pas élargi ici.
QiSpanExtraction extractQiSpans(EcluseReference ref, String text) {
  final lieux = _lieuSpans(ref, text);
  final avertissements = <String>[
    for (final l in lieux.where((l) => l.ambigu)) _avertissementLieuAmbigu(l),
  ];
  final spans = [..._professionSpans(text), ...lieux, ..._ageSpans(text)]
    ..sort((a, b) => a.start - b.start);
  return QiSpanExtraction(spans, avertissements);
}

String _avertissementLieuAmbigu(QiSpan lieu) {
  final prudent = LieuAmbigu(lieu.text, lieu.candidats).plusPetite;
  return 'Lieu « ${lieu.text} » ambigu (${lieu.candidats.length} communes de ce '
      'nom) : estimation faite sur la plus petite '
      '(${prudent?.libelle ?? "population inconnue"}, '
      'dép. ${prudent?.dep ?? "?"}) par prudence.';
}
