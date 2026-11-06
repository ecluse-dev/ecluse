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
  /// même phrase.
  final bool rattachee;

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
    ['diabète', 'diabète de type 1', 'diabète de type 2'],
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
  'CONNU POUR', 'CONNUE POUR', 'PRESENTE UN', 'PRESENTE UNE', //
];

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
      final t = table[cle];
      if (t != null) {
        meilleure = _mention(text, debut, finCar, t.$2, t.$1, 'table');
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
    String systeme, String source) {
  var debutPhrase = 0;
  for (final m in _finDePhrase.allMatches(text.substring(0, start))) {
    debutPhrase = m.end;
  }
  final avant = normName(text.substring(debutPhrase, start));
  final rattachee = _tournures.any((t) => ' $avant '.contains(' $t '));
  return PathologieMention(
    start: start,
    end: end,
    text: text.substring(start, end),
    categorie: categorie,
    systeme: systeme,
    source: source,
    rattachee: rattachee,
  );
}
