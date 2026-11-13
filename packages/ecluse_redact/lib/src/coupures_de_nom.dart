import 'heuristics/etablissement_keywords.dart';

/// Fins de ligne à neutraliser à l'intérieur d'un nom d'établissement ou
/// d'un nom de commune (P2-173).
///
/// **Pourquoi.** Un traitement de texte ou l'extraction d'un PDF coupent une
/// ligne à l'espace : « Centre⏎Hospitalier de Dole », « CH⏎de Vesoul »,
/// « 70180 DAMPIERRE SUR⏎SALON ». Les détecteurs d'établissement et d'adresse
/// s'arrêtent volontairement au saut de ligne (deux lignes sans rapport ne
/// doivent pas fusionner), donc la suite du nom partait en clair : sur le
/// corpus flou réaliste recoupé, 44 établissements à 90 colonnes et la fin de
/// 13 communes à 60 colonnes (`bench/ETAT.md`, « mise en page »).
///
/// **Comment.** Comme pour un identifiant coupé (`_coupuresDeLigne`), la fin
/// de ligne n'est remplacée par une espace que dans la **vue de détection** :
/// le texte n'est jamais réécrit, et ce sont toujours les détecteurs, avec
/// leurs propres garde-fous, qui décident. Ici on ne dit que « ces deux
/// lignes se lisent d'un trait ».
///
/// **Quand.** Seulement là où le nom continue visiblement :
///
/// 1. la ligne finit par un mot de liaison derrière un mot-clé
///    d'établissement (« CH de⏎Vesoul », « IME La⏎Source ») ou derrière un
///    code postal et le début d'une commune (« 70180 DAMPIERRE SUR⏎SALON ») :
///    une ligne ne s'arrête pas sur « de » ou « SUR » ;
/// 2. la ligne finit par le mot-clé ou par le début du nom, et la suivante
///    commence par un mot de liaison **en minuscules** suivi d'un nom propre
///    (« CH⏎de Vesoul ») : une phrase ne commence pas par une minuscule ;
/// 3. la ligne finit par le mot-clé ou par le début du nom, et la suivante
///    commence par un nom propre qui n'ouvre pas une phrase (« EHPAD⏎Les
///    Tilleuls », « Centre⏎Hospitalier de Dole »). C'est le cas ambigu : un
///    pronom, un déterminant, une civilité, une étiquette (« Contact : ») ou
///    un article suivi d'une minuscule (« Les résidents ») ne sont pas
///    recollés ;
/// 4. la coupure tombe dans un mot-clé de plusieurs mots (« centre⏎
///    hospitalier », « Maison de⏎retraite »).
///
/// Jamais à travers une ligne vide, et au plus deux fins de ligne de suite
/// (un nom sur trois lignes) : au-delà, on ne recolle plus.
///
/// **Reste** (écrit dans `LIMITES.md` § 5.2) : le cas 3 peut recoller un nom
/// propre qui ouvrait en réalité une phrase sans ponctuation avant
/// (« …à l'EHPAD⏎Bellevue est fermée ») : sur-masquage, jamais une fuite. Un
/// nom de commune coupé ailleurs que derrière un mot de liaison (« SAINT
/// GERMAIN⏎LAVAL ») n'est pas recollé : rien ne le distingue de la ligne
/// suivante.
///
/// Rend les intervalles `(début, fin)` à remplacer par une seule espace
/// (blancs horizontaux autour de la fin de ligne compris), dans l'ordre du
/// texte. Coût linéaire : chaque fin de ligne n'examine qu'une fenêtre bornée
/// de part et d'autre.
List<(int, int)> coupuresDeNom(String vue) {
  final resultat = <(int, int)>[];
  var i = vue.indexOf('\n');
  if (i < 0) return resultat;
  // Début du contexte « avant » : la ligne courante, ou une ligne précédente
  // déjà recollée à celle-ci (au plus deux fins de ligne de suite).
  var debutContexte = 0;
  var recolleesDeSuite = 0;
  while (i >= 0) {
    var s = i;
    if (s > 0 && vue.codeUnitAt(s - 1) == 0x0D) s--;
    while (s > 0 && _blanc(vue.codeUnitAt(s - 1))) {
      s--;
    }
    var e = i + 1;
    while (e < vue.length && _blanc(vue.codeUnitAt(e))) {
      e++;
    }
    final suivante = vue.indexOf('\n', e);
    var recolle = false;
    final ligneVide = s <= debutContexte ||
        e >= vue.length ||
        vue.codeUnitAt(e) == 0x0A ||
        vue.codeUnitAt(e) == 0x0D;
    if (!ligneVide && recolleesDeSuite < 2) {
      final debut = s - debutContexte > _fenetre ? s - _fenetre : debutContexte;
      var avant = vue.substring(debut, s);
      if (recolleesDeSuite > 0) avant = avant.replaceAll(_finDeLigne, ' ');
      final finApres = suivante < 0 ? vue.length : suivante;
      final apres =
          vue.substring(e, finApres - e > _fenetre ? e + _fenetre : finApres);
      recolle = _seRecollent(avant, apres);
    }
    if (recolle) {
      resultat.add((s, e));
      recolleesDeSuite++;
    } else {
      recolleesDeSuite = 0;
      debutContexte = i + 1;
    }
    i = suivante;
  }
  return resultat;
}

/// Longueur maximale examinée de part et d'autre d'une fin de ligne : un nom
/// d'établissement ou une adresse tiennent largement dedans, et le coût reste
/// linéaire sur une ligne très longue.
const int _fenetre = 160;

bool _blanc(int c) => c == 0x20 || c == 0x09;

final RegExp _finDeLigne = RegExp(r'[ \t]*\r?\n[ \t]*');

bool _seRecollent(String avant, String apres) {
  if (_finCommune.hasMatch(avant) && _debutMotCommune.hasMatch(apres)) {
    return true;
  }
  // Cas 4 : coupure dans un mot-clé de plusieurs mots.
  for (final (debut, suite) in _motsClesCoupes) {
    if (debut.hasMatch(avant) && suite.hasMatch(apres)) return true;
  }
  // Cas 1 : mot de liaison en fin de ligne, derrière un mot-clé.
  if (_etablissementPuisLiaison.hasMatch(avant)) {
    return _debutMot.hasMatch(apres);
  }
  if (!_etablissementEnFinDeLigne.hasMatch(avant)) return false;
  // Cas 2 : la ligne suivante commence par une liaison en minuscules.
  if (_liaisonPuisMot.hasMatch(apres)) return true;
  // Cas 3 : nom propre en tête de ligne, s'il n'ouvre pas une phrase.
  final mot = _premierMot.firstMatch(apres);
  if (mot == null) return false;
  if (_etiquette.hasMatch(apres)) return false;
  final premier = mot.group(0)!;
  if (_articles.contains(premier)) return _articlePuisNomPropre.hasMatch(apres);
  return !_ouvreUnePhrase.contains(premier);
}

// --- Établissement ---------------------------------------------------------
// Mêmes briques que `EtablissementDetector` (mot-clé, connecteur, mot en
// casse de titre), pour ne recoller que ce que le détecteur saura lire.

const String _connecteur = '(?:de|du|des|le|la|les|sur|en|aux|au)';
const String _mot = "[A-ZÀ-Ÿ][\\wÀ-ÿ'’\\-]*";
const String _segment = "(?:(?:$_connecteur[ \\t]+|[dl]['’]))?$_mot";

String _alternative(Iterable<String> motsCles) =>
    (motsCles.toList()..sort((a, b) => b.length.compareTo(a.length)))
        .map((k) => k.split(' ').map(RegExp.escape).join('[ \\t]+'))
        .join('|');

final String _motsCles = _alternative(
    [...etablissementKeywords, ...etablissementKeywordsMinuscules]);

/// « … CH », « … Centre Hospitalier », « … Résidence Les » en fin de ligne.
final RegExp _etablissementEnFinDeLigne =
    RegExp('\\b(?:$_motsCles)(?:[ \\t]+$_segment)*\$');

/// « … CH de », « … IME La », « … MAS des » en fin de ligne : la ligne finit
/// par un mot de liaison, en minuscules ou en article capitalisé.
final RegExp _etablissementPuisLiaison = RegExp(
    '\\b(?:$_motsCles)(?:[ \\t]+$_segment)*[ \\t]+(?:$_connecteur|Le|La|Les)\$');

final RegExp _debutMot = RegExp('^$_mot');
final RegExp _liaisonPuisMot = RegExp("^(?:$_connecteur[ \\t]+|[dl]['’])$_mot");
final RegExp _premierMot = RegExp('^[A-ZÀ-Ÿ][\\wÀ-ÿ\\-]*');
final RegExp _articlePuisNomPropre = RegExp('^(?:Le|La|Les)[ \\t]+$_mot');

/// « Contact : », « Tél. : » : une étiquette de champ en tête de ligne n'est
/// pas la suite d'un nom.
final RegExp _etiquette = RegExp("^[A-ZÀ-Ÿ][\\wÀ-ÿ'’. \\-]{0,30}:");

const Set<String> _articles = {'Le', 'La', 'Les'};

/// Mots qui, en tête de ligne après un mot-clé, ouvrent une phrase ou
/// annoncent une personne : jamais la suite du nom de l'établissement. Liste
/// fermée, sensible à la casse (un établissement « Résidence Notre-Dame » se
/// recolle : « Notre-Dame » n'est pas « Notre »).
const Set<String> _ouvreUnePhrase = {
  // Pronoms et déterminants.
  'Il', 'Elle', 'Ils', 'Elles', 'On', 'Nous', 'Vous', 'Je', 'Tu', 'Ce', 'Cet',
  'Cette', 'Ces', 'Un', 'Une', 'Des', 'Du', 'De', 'Au', 'Aux', 'Son', 'Sa',
  'Ses', 'Mon', 'Ma', 'Mes', 'Notre', 'Votre', 'Nos', 'Vos', 'Leur', 'Leurs',
  'Aucun', 'Aucune', 'Chaque', 'Tout', 'Tous', 'Toute', 'Toutes', 'Plusieurs',
  // Conjonctions, prépositions, adverbes de début de phrase.
  'Et', 'Ou', 'Mais', 'Donc', 'Or', 'Ni', 'Car', 'Si', 'En', 'Pour', 'Par',
  'Avec', 'Sans', 'Dans', 'Sur', 'Sous', 'Chez', 'Vers', 'Depuis', 'Pendant',
  'Après', 'Avant', 'Selon', 'Suite', 'Lors', 'Quand', 'Comme', 'Que', 'Qui',
  'Pas', 'Ne', 'Puis', 'Ensuite', 'Enfin', 'Ainsi', 'Aussi', 'Alors', 'Merci',
  'Bonjour', 'Bonsoir', 'Cordialement', 'Salutations',
  // Civilités et titres : un nom de personne, détecté à part.
  'Madame', 'Monsieur', 'Mademoiselle', 'Mme', 'Mlle', 'Mmes', 'MM', 'Mr',
  'M', 'Dr', 'Dre', 'Docteur', 'Docteure', 'Pr', 'Professeur', 'Professeure',
  'Me', 'Maître',
};

/// Mots-clés de plusieurs mots, à chaque espace : (fin de ligne, début de la
/// ligne suivante). La suite doit être suivie d'un nom, comme l'exige le
/// détecteur. « Centre⏎Hospitalier » relève du cas 3 (« Centre » est un
/// mot-clé à lui seul) ; « centre⏎hospitalier » et « Maison de⏎retraite »
/// n'y entrent pas, d'où cette table.
final List<(RegExp, RegExp)> _motsClesCoupes = [
  for (final motCle in {
    ...etablissementKeywords,
    ...etablissementKeywordsMinuscules
  })
    for (var k = motCle.indexOf(' '); k >= 0; k = motCle.indexOf(' ', k + 1))
      (
        RegExp(
            '\\b${RegExp.escape(motCle.substring(0, k)).replaceAll(' ', '[ \\t]+')}\$'),
        RegExp(
            '^${RegExp.escape(motCle.substring(k + 1)).replaceAll(' ', '[ \\t]+')}'
            '[ \\t]+$_segment'),
      ),
];

// --- Commune ---------------------------------------------------------------

const String _h = '[ \\t\\u00A0\\u202F]';
const String _motCommune = "[A-ZÀ-ÖØ-Þ][\\wÀ-ÖØ-Þà-öø-ÿ'’-]*";

/// Mots qui lient les parties d'un nom de commune, dans les trois casses où
/// on les écrit (« sur », « Sur », « SUR »). Une ligne qui finit par l'un
/// d'eux derrière un code postal n'est pas finie.
final String _liaisonsCommune = [
  for (final l in const [
    'sur',
    'sous',
    'les',
    'le',
    'la',
    'de',
    'du',
    'des',
    'en',
    'aux',
    'au',
    'lès',
    'lez',
    'saint',
    'sainte',
    'st',
    'ste',
  ]) ...[l, l.toUpperCase(), l[0].toUpperCase() + l.substring(1)],
].join('|');

/// « 70180 DAMPIERRE SUR », « 25000 SAINT », « 70160 Port sur » en fin de
/// ligne : code postal, au plus deux mots de commune, un mot de liaison.
final RegExp _finCommune = RegExp('(?<!\\d)\\d{5}$_h+'
    '(?:$_motCommune[ \\u00A0\\u202F-]){0,2}(?:$_liaisonsCommune)\$');

final RegExp _debutMotCommune = RegExp('^$_motCommune');
