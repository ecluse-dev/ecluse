import 'package:ecluse_reference/ecluse_reference.dart';

import 'age_bands.dart' show seniorMaxAgeCap;
import 'qi.dart';

/// Extraction texte -> QI (spec §2). Couche mince et déterministe (pas de
/// NER) : le cœur du jalon est l'estimateur (`estimator.dart`), pas cette
/// extraction. Pour la démo/les tests, les QI peuvent aussi être fournis
/// directement structurés — c'est la voie recommandée.

final RegExp _agePattern = RegExp(r'\b(\d{1,3})\s*ans\b', caseSensitive: false);

/// Tranche d'âge telle que l'écrit `qiValueLabel` après généralisation
/// (« 100-104 ans »), relue comme une tranche (P2-102). Sans ce motif, « 104
/// ans » était relu dans « 100-104 ans » comme un âge exact : F pouvait
/// baisser après une généralisation censée le faire monter, et une
/// généralisation répétée bouclait (« 100-100-104 ans », mesure P2-93).
const String _tranche = r'\b(\d{1,3})\s*-\s*(\d{1,3})\s*ans\b';
final RegExp _tranchePattern = RegExp(_tranche, caseSensitive: false);

/// QI d'une tranche lue dans le texte. Le palier suit la largeur, comme
/// l'échelle de `generalizer.dart` : 5 ans au plus (palier 1), 10 au plus
/// (palier 2), au-delà (tranche senior, palier 3). `null` si la tranche est
/// incohérente ou hors des âges de l'échelle.
Qi? _trancheQi(RegExpMatch m) {
  final lo = int.parse(m.group(1)!);
  final hi = int.parse(m.group(2)!);
  if (lo > hi || hi > seniorMaxAgeCap) return null;
  final largeur = hi - lo + 1;
  final level = largeur <= 5 ? 1 : (largeur <= 10 ? 2 : 3);
  return Qi(QiType.age, '$lo-$hi', level: level);
}

/// Tournure de **durée** juste avant « N ans » : « signé pour 9 ans », « il y
/// a 3 ans », « existe depuis 23 ans ». Ce n'est pas un âge (P2-136 : 222
/// des 412 extractions à tort du corpus témoin de QI). « a 74 ans », « âgé
/// de 74 ans » ne sont pas concernés.
final RegExp _dureeAvant = RegExp(
  r'(?:^|[^\p{L}])(?:pour|depuis|pendant|durant|dans|il y a|voici|'
  r'en|sur|tous les|toutes les|chaque|après|avant)'
  r'(?:[ \t\u00A0]+(?:plus de|moins de|près de|environ|presque|bientôt|'
  r'déjà|au moins))?[ \t\u00A0]+$',
  unicode: true,
  caseSensitive: false,
);

/// Âges du texte, dans l'ordre : tranches (« 70-74 ans ») et âges exacts
/// (« N ans », 0 à 120) qui ne sont pas la borne d'une tranche.
List<(RegExpMatch, Qi)> _ages(String text) {
  final tranches = _tranchePattern.allMatches(text).toList();
  final trouves = <(RegExpMatch, Qi)>[
    for (final t in tranches)
      if (_trancheQi(t) case final qi?) (t, qi),
  ];
  for (final m in _agePattern.allMatches(text)) {
    if (tranches.any((t) => m.start < t.end && t.start < m.end)) continue;
    if (_dureeAvant
        .hasMatch(text.substring(m.start > 40 ? m.start - 40 : 0, m.start))) {
      continue;
    }
    final age = int.parse(m.group(1)!);
    if (age <= 120) trouves.add((m, Qi(QiType.age, age.toString())));
  }
  trouves.sort((a, b) => a.$1.start - b.$1.start);
  return trouves;
}

/// Motif « N ans » (spec §2), âges plausibles 0-120, et tranches écrites
/// par la généralisation (P2-102).
List<Qi> extractAge(String text) => [for (final (_, qi) in _ages(text)) qi];

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

/// Département tel que l'écrit `qiValueLabel` après généralisation du lieu
/// (« département 57 », « département 2A », « département 971 »), relu au
/// palier 1 (P2-116). Sans ce motif, le lieu généralisé disparaissait de
/// l'estimation : F était recalculé comme si aucun lieu n'était donné (×157 en
/// médiane, mesure P2-103) et le rapport rassurait à tort, alors que le
/// département restait dans le texte envoyé.
final RegExp _departementPattern = RegExp(
  r'(?<![\p{L}\p{N}])département\s+(\d{2,3}|2[AB])(?![\p{L}\p{N}])',
  unicode: true,
  caseSensitive: false,
);

/// Départements écrits du texte, connus de la géographie de référence. Un
/// code inconnu (« département 00 ») n'est pas relu : il ne désigne aucun
/// territoire dont on connaisse la population.
List<(RegExpMatch, Qi)> _departements(EcluseReference ref, String text) => [
      for (final m in _departementPattern.allMatches(text))
        if (ref.geo.regionOfDep(m.group(1)!.toUpperCase()) != null)
          (m, Qi(QiType.lieu, m.group(1)!.toUpperCase(), level: 1)),
    ];

/// Gazetteer des communes (spec §2) : scanne des séquences de 1 à 3 tokens
/// capitalisés et teste chacune contre `GeoHierarchy.communesByName`.
///
/// Un nom **ambigu** (plusieurs communes) n'est plus ignoré : il produit le
/// QI de la commune la plus petite (cas le plus prudent, voir
/// [LieuAmbigu.plusPetite]) et est listé par [extractLieuAmbigu]. L'entrée
/// structurée reste recommandée quand l'ambiguïté compte.
List<Qi> extractLieu(EcluseReference ref, String text) {
  final qis = <Qi>[
    for (final (_, qi) in _departements(ref, text)) qi,
  ];
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
      if (matches.isEmpty) continue;
      final debut = tokens[i].start;
      if (_lieuEvenement
          .hasMatch(text.substring(debut > 40 ? debut - 40 : 0, debut))) {
        continue;
      }
      if (_homonymesCourants.contains(candidate.toLowerCase()) &&
          !_locatifAvant
              .hasMatch(text.substring(debut > 30 ? debut - 30 : 0, debut))) {
        continue;
      }
      found.add((candidate, matches));
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

/// Libellés écrits par `qiValueLabel` pour une profession généralisée, relus
/// à leur palier (P2-102). Sans eux, « médecin (toute spécialité) » n'était
/// plus une profession : F passait du Cas A au Cas B et pouvait baisser, ou
/// l'évaluation devenait impossible (mesure P2-93).
const Map<String, Qi> _libellesGeneralises = {
  'médecin (toute spécialité)':
      Qi(QiType.profession, professionToutesSpecialites, level: 1),
  'professionnel de santé (toute profession)':
      Qi(QiType.profession, professionnelDeSante, level: 2),
};

/// Petite liste de mots-clés des 14 spécialités + professions (spec §2),
/// recherche insensible à la casse sur le texte brut (les clés couvrent les
/// variantes accentuées usuelles).
List<Qi> extractProfession(EcluseReference ref, String text) {
  final lower = text.toLowerCase();
  final qis = <Qi>[];
  for (final entry in _libellesGeneralises.entries) {
    if (lower.contains(entry.key)) qis.add(entry.value);
  }
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
  for (final entry in _libellesGeneralises.entries) {
    final motif = RegExp(RegExp.escape(entry.key), caseSensitive: false);
    for (final m in motif.allMatches(text)) {
      candidats.add(QiSpan(
        type: QiType.profession,
        start: m.start,
        end: m.end,
        text: m.group(0)!,
        qi: entry.value,
      ));
    }
  }
  return _sansChevauchement(candidats);
}

/// Même gazetteer que [extractLieu] (séquences de 1 à 3 mots capitalisés),
/// avec positions. Deux mots ne sont réunis que s'ils ne sont séparés que
/// d'espaces : un nom de lieu ne traverse pas une ponctuation ou un saut de
/// ligne (« Dole. Belfort » n'est pas un candidat).
/// Communes dont le nom est aussi un mot courant (« Tours de garde »,
/// « Nuits de garde », « Orange », « Sens »). Elles ne comptent comme lieu
/// qu'après une préposition ou un verbe de lieu (« à Tours », « habite
/// Orange ») (P2-136 : 190 extractions de lieu à tort sur le corpus témoin
/// de QI, toutes de ce type). Liste écrite par le projet ; elle recoupe en
/// partie les leurres du corpus témoin.
const Set<String> _homonymesCourants = {
  'tours', 'nuits', 'orange', 'plaine', 'pont', 'ville', 'mer', 'sens', //
  'bar', 'ham', 'vic', 'lit', 'mars', 'mai', 'août', 'sète', 'condé', //
  'gap', 'bourg', 'port', 'puy', 'roche', 'rive', 'lac', 'val', 'bois', //
};

final RegExp _locatifAvant = RegExp(
  r"(?:^|[^\p{L}])(?:à|a|de|d'|d’|en|vers|près de|habite|vit|né|née|"
  r'originaire de|domicilié|domiciliée|résidant|réside)[ \t\u00A0]*$',
  unicode: true,
  caseSensitive: false,
);

/// Lieu d'un **événement**, pas d'une personne : « la réunion aura lieu à
/// Brest », « se tiendra à Dijon », « organisée à Lille » (P2-142 : les 57
/// extractions à tort restantes du corpus témoin de QI après P2-136).
final RegExp _lieuEvenement = RegExp(
  r'(?:(?:aura|a eu|avait|ont eu|auront) lieu|se tiendra|se tiendront|'
  r"s'est tenue?s?|s’est tenue?s?|se déroulera|se dérouleront|"
  r'organisée?s?|prévue?s?) (?:à|au|en)[ \t\u00A0]+$',
  caseSensitive: false,
);

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
      if (_homonymesCourants.contains(nom.toLowerCase()) &&
          !_locatifAvant
              .hasMatch(text.substring(start > 30 ? start - 30 : 0, start))) {
        continue;
      }
      if (_lieuEvenement
          .hasMatch(text.substring(start > 40 ? start - 40 : 0, start))) {
        continue;
      }
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
List<QiSpan> _ageSpans(String text) => [
      for (final (m, qi) in _ages(text))
        QiSpan(
          type: QiType.age,
          start: m.start,
          end: m.end,
          text: m.group(0)!,
          qi: qi,
        ),
    ];

/// Extrait les QI du texte **avec leur position**, sans exception pour une
/// entrée quelconque.
///
/// Différences voulues avec [extractQis] (qui reste inchangée) : mots-clés
/// cherchés comme mots entiers, plus long candidat seulement quand plusieurs se
/// recouvrent, nom de lieu contigu (sans ponctuation entre ses mots). Mêmes
/// vocabulaires, mêmes règles d'âge et de commune ambiguë (la plus petite
/// commune homonyme, par prudence). Le **rappel** n'est pas élargi ici.
QiSpanExtraction extractQiSpans(EcluseReference ref, String text) {
  final lieux = _sansChevauchement([
    ..._lieuSpans(ref, text),
    for (final (m, qi) in _departements(ref, text))
      QiSpan(
        type: QiType.lieu,
        start: m.start,
        end: m.end,
        text: m.group(0)!,
        qi: qi,
      ),
  ]);
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
