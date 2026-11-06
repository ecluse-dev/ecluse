import 'package:ecluse_reference/ecluse_reference.dart';

/// Repérage des pathologies dans un texte (P2-125) — **mesure seulement**.
///
/// La pathologie est le quasi-identifiant le plus ré-identifiant après le
/// lieu (`agent/specs/P2-07.md`) : « atteinte de la maladie de Huntington »
/// désigne parfois une seule personne dans un département. Ce module
/// **repère** les mentions et leur catégorie ; il n'est branché ni sur
/// l'estimation du risque ni sur les suggestions de généralisation : sans
/// donnée de prévalence, aucun F chiffré n'est possible, et la table des
/// pathologies fréquentes n'est pas encore validée cliniquement (P2-110).
///
/// Deux sources :
///
/// - la **table maison provisoire** ([tablePathologiesProvisoire]), tirée de
///   `agent/specs/P2-94-table.md` § 3 ; elle prime pour ses mentions
///   (décision P2-113) ;
/// - le **catalogue Orphanet** ([RareDiseaseCatalog]) pour les maladies
///   rares, s'il est chargé.
///
/// Une mention n'est retenue comme **pathologie d'une personne** que si une
/// tournure qui la rattache à quelqu'un la précède dans la même phrase
/// (« atteinte de », « suivi pour », « antécédents : »…). Sans elle, « réseau
/// diabète » ou « unité Alzheimer » désignent un service, pas un malade :
/// [PathologieMention.rattachee] le dit, l'appelant choisit.
class PathologieMention {
  const PathologieMention({
    required this.start,
    required this.end,
    required this.text,
    required this.categorie,
    required this.systeme,
    required this.source,
    required this.rattachee,
    this.niee = false,
    this.adjectif = false,
  });

  final int start;
  final int end;
  final String text;

  /// Catégorie : intitulé ALD abrégé (table maison) ou catégorie Orphanet.
  final String categorie;

  /// Système (table maison) ou « maladie rare » (Orphanet).
  final String systeme;

  /// `'table'` ou `'orphanet'`.
  final String source;

  /// Une tournure de rattachement à une personne précède la mention dans la
  /// même phrase, ou la mention est une forme adjectivale (« diabétique »),
  /// et elle n'est pas niée.
  final bool rattachee;

  /// Une négation (« pas de », « aucun », « absence de », « sans ») précède
  /// la mention de peu : la pathologie est citée pour dire qu'elle est
  /// absente (P2-126). Jamais rattachée.
  final bool niee;

  /// Forme adjectivale (« diabétique ») : elle qualifie la personne et ne se
  /// remplace pas par un nom de catégorie sans réécrire la phrase ; aucune
  /// généralisation n'est proposée pour elle (P2-135).
  final bool adjectif;

  @override
  String toString() =>
      'PathologieMention($start-$end « $text » → $categorie, $source'
      '${rattachee ? ', rattachée' : ''})';
}

/// Entrée de la table maison : (système, catégorie, mentions).
typedef EntreePathologie = (String, String, List<String>);

/// Table maison **provisoire** des pathologies fréquentes : copie de
/// `agent/specs/P2-94-table.md` § 3, **non validée cliniquement** (P2-110).
/// « SEP » en est retiré (sens multiples, choix provisoire de P2-112).
const List<EntreePathologie> tablePathologiesProvisoire = [
  (
    'neurologique',
    'accident vasculaire cérébral invalidant',
    ['AVC', 'accident vasculaire cérébral', 'hémiplégie séquellaire'],
  ),
  (
    'neurologique',
    "maladie d'Alzheimer et autres démences",
    ["maladie d'Alzheimer", 'démence', 'démence à corps de Lewy'],
  ),
  (
    'neurologique',
    'maladie de Parkinson',
    ['maladie de Parkinson', 'Parkinson']
  ),
  ('neurologique', 'sclérose en plaques', ['sclérose en plaques']),
  (
    'neurologique',
    'affections neurologiques graves, épilepsie grave',
    ['épilepsie', 'myopathie'],
  ),
  ('neurologique', 'paraplégie', ['paraplégie', 'tétraplégie']),
  (
    'psychiatrique',
    'affections psychiatriques de longue durée',
    ['schizophrénie', 'trouble bipolaire', 'dépression récurrente'],
  ),
  (
    'cardio-vasculaire',
    'insuffisance cardiaque grave, troubles du rythme',
    ['insuffisance cardiaque', 'fibrillation auriculaire', 'valvulopathie'],
  ),
  (
    'cardio-vasculaire',
    'maladie coronaire',
    ['infarctus du myocarde', 'maladie coronaire', 'angor'],
  ),
  (
    'cardio-vasculaire',
    'artériopathies chroniques',
    ['artériopathie des membres inférieurs', 'AOMI'],
  ),
  (
    'respiratoire',
    'insuffisance respiratoire chronique grave',
    ['BPCO', 'asthme grave', 'insuffisance respiratoire chronique'],
  ),
  (
    'digestif et hépatique',
    'rectocolite hémorragique et maladie de Crohn',
    ['maladie de Crohn', 'rectocolite hémorragique'],
  ),
  (
    'digestif et hépatique',
    'maladies chroniques du foie et cirrhoses',
    ['cirrhose', 'hépatite B', 'hépatite C'],
  ),
  (
    'métabolique',
    'diabète de type 1 et de type 2',
    // « DT1 », « DT2 » : sigles courants, sans autre sens dans un écrit de
    // soin (P2-134 ; mesure P2-129 : 30 « DT2 » sur 30 manqués).
    ['diabète', 'diabète de type 1', 'diabète de type 2', 'DT1', 'DT2'],
  ),
  (
    'métabolique',
    'maladies métaboliques héréditaires',
    ['phénylcétonurie', 'maladie de Gaucher'],
  ),
  (
    'rénal',
    'néphropathie chronique grave',
    ['insuffisance rénale chronique', 'dialyse', 'syndrome néphrotique'],
  ),
  ('hématologique', 'hémoglobinopathies', ['drépanocytose', 'thalassémie']),
  (
    'hématologique',
    "hémophilies et affections graves de l'hémostase",
    ['hémophilie', 'maladie de Willebrand'],
  ),
  (
    'hématologique',
    'insuffisances médullaires et autres cytopénies chroniques',
    ['aplasie médullaire'],
  ),
  (
    'immunitaire et infectieux',
    'déficit immunitaire primitif grave, infection par le VIH',
    ['VIH', 'infection par le VIH', 'séropositivité', 'déficit immunitaire'],
  ),
  ('immunitaire et infectieux', 'tuberculose active', ['tuberculose']),
  ('immunitaire et infectieux', 'bilharziose compliquée', ['bilharziose']),
  (
    'rhumatologique',
    'polyarthrite rhumatoïde évolutive',
    ['polyarthrite rhumatoïde'],
  ),
  ('rhumatologique', 'spondylarthrite grave', ['spondylarthrite ankylosante']),
  (
    'rhumatologique',
    'vascularites, lupus, sclérodermie systémique',
    ['lupus', 'sclérodermie', 'vascularite'],
  ),
  ('ostéo-articulaire', 'scoliose idiopathique structurale', ['scoliose']),
  (
    'oncologique',
    'tumeurs malignes',
    ['cancer du sein', 'cancer du poumon', 'lymphome', 'leucémie'],
  ),
  ('génétique', 'mucoviscidose', ['mucoviscidose']),
  (
    'transplantation',
    "suites de transplantation d'organe",
    ['greffe de rein', 'transplanté cardiaque'],
  ),
];

/// Tournures qui rattachent une pathologie à une personne, normalisées par
/// [normName]. Liste écrite par le projet, à mesurer (P2-125).
const List<String> _tournures = [
  'ATTEINT DE', 'ATTEINTE DE', 'ATTEINT D', 'ATTEINTE D', //
  'SUIVI POUR', 'SUIVIE POUR', 'TRAITE POUR', 'TRAITEE POUR', //
  'SOUFFRE DE', 'SOUFFRE D', 'SOUFFRANT DE', 'SOUFFRANTE DE', //
  'PORTEUR DE', 'PORTEUSE DE', 'PORTEUR D', 'PORTEUSE D', //
  'ANTECEDENT', 'ANTECEDENTS', 'DIAGNOSTIC DE', 'DIAGNOSTIC D', //
  'ATCD', 'ATCDS', // abréviation courante d'« antécédents » (P2-134)
  'CONNU POUR', 'CONNUE POUR', 'PRESENTE UN', 'PRESENTE UNE', //
];

/// Négations, normalisées par [normName], cherchées dans les
/// [_porteeNegation] mots qui précèdent la mention (P2-126 : « aucun
/// antécédent de BPCO » était rattaché par « antécédent »).
const List<String> _negations = [
  'PAS DE', 'PAS D', 'AUCUN', 'AUCUNE', 'ABSENCE DE', 'ABSENCE D', 'SANS', //
  'NI', 'JAMAIS DE', 'JAMAIS D', 'EXCLU', 'ECARTE', //
];
const int _porteeNegation = 5;

/// Négation placée **après** la mention (P2-134, mesure P2-129) : « Diabète :
/// non. », « Tuberculose exclue au dernier bilan », « BPCO ? à éliminer ».
/// « non » n'y compte que suivi d'une ponctuation ou d'une fin de texte :
/// « diabète non insulinodépendant » reste une pathologie. Le « non » placé
/// juste **avant** (« non diabétique ») est traité à part : seul le mot qui
/// précède immédiatement compte, pour ne pas nier « non fumeur, atteint de
/// diabète ».
final RegExp _negationApres = RegExp(
    r'^[ \t]*(?::[ \t]*non[ \t]*(?:[.,;!?)]|$)|non[ \t]*(?:[.,;!?)]|$)|'
    r'(?:exclue?s?|écartée?s?)(?![\p{L}])|\?[ \t]*à éliminer)',
    caseSensitive: false,
    unicode: true);

/// Formes adjectivales qui qualifient une personne (« Mme X, diabétique »),
/// rattachées à la mention de la table dont elles relèvent (P2-126).
/// Liste écrite par le projet, provisoire comme la table. Comparées en
/// minuscules **avec** leurs accents.
const Map<String, String> formesAdjectivalesProvisoires = {
  'diabétique': 'diabète', 'épileptique': 'épilepsie', //
  'parkinsonien': 'maladie de Parkinson', //
  'parkinsonienne': 'maladie de Parkinson', //
  'hémophile': 'hémophilie', 'schizophrène': 'schizophrénie', //
  'paraplégique': 'paraplégie', 'tétraplégique': 'tétraplégie', //
  'dialysé': 'dialyse', 'dialysée': 'dialyse', //
  'cirrhotique': 'cirrhose', 'drépanocytaire': 'drépanocytose', //
  'séropositif': 'séropositivité', 'séropositive': 'séropositivité', //
  'bipolaire': 'trouble bipolaire', //
  'insuffisant cardiaque': 'insuffisance cardiaque', //
  'insuffisante cardiaque': 'insuffisance cardiaque', //
  'insuffisant rénal': 'insuffisance rénale chronique', //
  'insuffisante rénale': 'insuffisance rénale chronique', //
};

Map<String, (String, String)>? _indexAdjectifs;

Map<String, (String, String)> _adjectifs() => _indexAdjectifs ??= {
      for (final MapEntry(key: forme, value: mention)
          in formesAdjectivalesProvisoires.entries)
        forme: _table()[normName(mention)]!,
    };

/// Caractères lus au plus avant une mention pour y chercher une tournure de
/// rattachement ou une négation, dans la même phrase. Comme la fenêtre de la
/// fiche « Prénom » de `NameDetector` : 300. Une liste d'antécédents plus
/// longue sans point perd le rattachement de ses derniers éléments.
const int _fenetre = 300;

/// « de » ou « d' » suivi d'un nom propre, juste après une mention.
final RegExp _eponyme = RegExp(
    r"[ \t\u00A0]+(?:de[ \t\u00A0]+|d['’])"
    r'(?!(?:Mme|Mlle|Monsieur|Madame|Mademoiselle|Dr|Pr|M)(?![\p{L}]))'
    r"\p{Lu}[\p{L}'’-]*",
    unicode: true);

const int _longueurMax = 10;

final RegExp _jeton = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final RegExp _finDePhrase = RegExp(r'[.!?\n]');

Map<String, (String, String)>? _indexTable;

Map<String, (String, String)> _table() => _indexTable ??= {
      for (final (systeme, categorie, mentions) in tablePathologiesProvisoire)
        for (final m in mentions) normName(m): (systeme, categorie),
    };

/// Repère les pathologies de [text]. [catalogue] (maladies rares) est
/// facultatif ; s'il est fourni, il doit être chargé. Mentions sans
/// chevauchement, la plus longue d'abord, la table maison prioritaire à
/// longueur égale.
List<PathologieMention> extrairePathologies(
  String text, {
  RareDiseaseCatalog? catalogue,
}) {
  final jetons = _jeton.allMatches(text).toList();
  final table = _table();
  final trouvees = <PathologieMention>[];
  var i = 0;
  while (i < jetons.length) {
    PathologieMention? meilleure;
    var fin = i;
    for (var n = _longueurMax; n >= 1 && meilleure == null; n--) {
      if (i + n > jetons.length) continue;
      final debut = jetons[i].start;
      final finCar = jetons[i + n - 1].end;
      final cle = normName(text.substring(debut, finCar));
      // Forme adjectivale d'abord, accents compris : « dialysé » et
      // « dialyse » ont la même forme normalisée (P2-126).
      final adj = _adjectifs()[text.substring(debut, finCar).toLowerCase()];
      final t = adj == null ? table[cle] : null;
      if (adj != null) {
        meilleure = _mention(text, debut, finCar, adj.$2, adj.$1, 'table',
            adjectif: true);
      } else if (t != null) {
        // Éponyme accolé (« myopathie de Duchenne ») : absorbé dans la
        // mention. Sans cela, généraliser « myopathie » laissait « maladie
        // neurologique de Duchenne » : le nom propre restait visible (P2-135).
        final e = _eponyme.matchAsPrefix(text, finCar);
        final finMention = e == null ? finCar : e.end;
        meilleure = _mention(text, debut, finMention, t.$2, t.$1, 'table');
        if (e != null) {
          var k = i + n - 1;
          while (k + 1 < jetons.length && jetons[k + 1].end <= finMention) {
            k++;
          }
          fin = k;
          break;
        }
      } else if (catalogue != null) {
        final codes = catalogue.codesForMention(cle);
        if (codes.isNotEmpty) {
          final categorie = codes.length == 1
              ? catalogue.categoryOf(codes.single)!
              : 'maladie rare (plusieurs catégories)';
          meilleure = _mention(
              text, debut, finCar, categorie, 'maladie rare', 'orphanet');
        }
      }
      if (meilleure != null) fin = i + n - 1;
    }
    if (meilleure != null) {
      trouvees.add(meilleure);
      i = fin + 1;
    } else {
      i++;
    }
  }
  return trouvees;
}

PathologieMention _mention(String text, int start, int end, String categorie,
    String systeme, String source,
    {bool adjectif = false}) {
  // Fenêtre bornée avant la mention : sans elle, chaque mention relisait
  // tout le texte qui la précède, et le coût devenait quadratique (P2-128 :
  // 2,7 s pour 2 000 mentions, 46 s pour 8 000).
  final base = start > _fenetre ? start - _fenetre : 0;
  var debutPhrase = base;
  for (final m in _finDePhrase.allMatches(text.substring(base, start))) {
    debutPhrase = base + m.end;
  }
  final avant = normName(text.substring(debutPhrase, start));
  final mots = avant.isEmpty ? const <String>[] : avant.split(' ');
  final proches = mots.sublist(
      mots.length > _porteeNegation ? mots.length - _porteeNegation : 0);
  final apres =
      text.substring(end, end + 40 > text.length ? text.length : end + 40);
  final niee =
      _negations.any((n) => ' ${proches.join(' ')} '.contains(' $n ')) ||
          (mots.isNotEmpty && mots.last == 'NON') ||
          _negationApres.hasMatch(apres);
  final rattachee =
      !niee && (adjectif || _tournures.any((t) => ' $avant '.contains(' $t ')));
  return PathologieMention(
    start: start,
    end: end,
    text: text.substring(start, end),
    categorie: categorie,
    systeme: systeme,
    source: source,
    rattachee: rattachee,
    niee: niee,
    adjectif: adjectif,
  );
}

/// Libellés de systèmes, au féminin ou au genre de leur nom, pour la
/// généralisation d'une pathologie fréquente (P2-135).
const Map<String, String> _libellesSystemes = {
  'neurologique': 'maladie neurologique',
  'psychiatrique': 'trouble psychiatrique',
  'cardio-vasculaire': 'maladie cardio-vasculaire',
  'respiratoire': 'maladie respiratoire',
  'digestif et hépatique': 'maladie digestive ou hépatique',
  'métabolique': 'maladie métabolique',
  'rénal': 'maladie rénale',
  'hématologique': 'maladie hématologique',
  'immunitaire et infectieux': 'maladie immunitaire ou infectieuse',
  'rhumatologique': 'maladie rhumatologique',
  'ostéo-articulaire': 'affection ostéo-articulaire',
  'oncologique': 'maladie oncologique',
  'génétique': 'maladie génétique',
  'transplantation': 'suites de greffe',
};

/// Paliers de généralisation d'une pathologie, du plus précis au plus
/// général, **sans article** pour s'insérer à la place de la mention
/// (« atteinte de la maladie de Huntington » → « atteinte de la maladie
/// neurologique rare » → « atteinte de la maladie rare ») (P2-135,
/// `agent/specs/P2-07.md` § 2.3).
///
/// Maladie rare : catégorie Orphanet, puis « maladie rare ». Pathologie
/// fréquente : système de la table, puis « maladie chronique ». Forme
/// adjectivale ou niée : aucun palier. **Aucun F n'est associé** : sans
/// prévalence, ces paliers sont des suggestions de dernier recours.
List<String> paliersPathologie(PathologieMention m) {
  if (m.adjectif || m.niee) return const [];
  if (m.source == 'orphanet') {
    final c = m.categorie;
    return [
      if (!c.startsWith('maladie rare (')) c[0].toLowerCase() + c.substring(1),
      'maladie rare',
    ];
  }
  final systeme = _libellesSystemes[m.systeme];
  return [if (systeme != null) systeme, 'maladie chronique'];
}
