import 'package:ecluse_core/ecluse_core.dart';

import 'etablissement_keywords.dart';

/// Détecteur heuristique de noms d'établissements — **v0 de
/// démonstration**.
///
/// Motif : un mot-clé caractéristique du secteur médico-social (`Foyer`,
/// `Résidence`, `IME`, `ITEP`, `ESAT`, `EHPAD`, `MAS`, `FAM`, `Centre`,
/// `CH`, `SSIAD`, `Clinique`, `Hôpital`, `Lycée`) suivi d'un nom propre. Un
/// établissement nommé participe au pouvoir d'identification d'une
/// personne (« le directeur de l'EHPAD Les Tilleuls ») au même titre
/// qu'un nom de personne — voir la philosophie du README racine sur le
/// faisceau d'indices. Confiance modérée (0.7) : le mot-clé est un indice
/// fort, mais le nom propre qui suit n'est pas validé (pas d'annuaire des
/// établissements embarqué).
///
/// Le nom qui suit le mot-clé est capté par une **règle de frontière**,
/// pas par un plafond numérique de mots (voir le corpus de mesure du
/// 31/07 : un plafond `{0,3}` tronque les noms légitimes longs et ne
/// protège pas contre l'absorption d'un mot sans rapport — les deux
/// défauts sont les deux faces du même plafond arbitraire). Le nom
/// s'étend tant que le token suivant est un mot en casse de titre ou en
/// capitales, ou un connecteur d'une liste fermée (`de`, `du`, `des`,
/// `le`, `la`, `les`, `d'`, `l'`, `sur`, `en`, `aux`, `au`) — le connecteur
/// n'est jamais absorbé seul : s'il n'est suivi d'aucun mot valide, il
/// n'est pas non plus capté (« Centre Hospitalier de garde » s'arrête à
/// `Hospitalier`, pas de connecteur qui traîne). Il s'arrête à la première
/// ponctuation, au premier saut de ligne, ou au premier mot en minuscule
/// hors liste de connecteurs.
///
/// **Mots génériques (P2-301).** Un type écrit en toutes lettres (« Résidence »,
/// « Foyer », « Centre »…) suivi *seulement* de mots de [motsGeneriques]
/// (« Résidence Autonomie », « Foyer D'accueil Médicalisé », « Centre
/// Social ») désigne une catégorie, pas un établissement : il n'est pas
/// masqué. Sans cette garde, 2 063 documents sur 200 000 phrases du soin sans
/// personne portaient ce masquage (P2-295). La garde ne vaut ni pour un sigle
/// (« CH Services » reste masqué), ni pour un nom entre guillemets, ni dès
/// qu'un mot hors liste figure dans le nom (« Résidence Autonomie Horizon »
/// est masqué en entier). **Limite assumée** : la liste ne connaît que ce
/// qu'elle contient ; un établissement réellement nommé « Résidence
/// Autonomie » ne serait pas masqué (voir `LIMITES.md`, 5.2).
final class EtablissementDetector implements EntityDetector {
  const EtablissementDetector();

  /// Mots génériques (en minuscules) qui, seuls derrière un type en toutes
  /// lettres, ne forment pas un nom d'établissement. Liste fermée et
  /// extensible : y ajouter un mot revient à parier qu'aucun établissement ne
  /// porte ce seul mot comme nom (P2-295, question 2). Les deux écritures de
  /// l'apostrophe sont présentes.
  static const Set<String> motsGeneriques = {
    'autonomie',
    "d'accueil",
    'd’accueil',
    'médicalisé',
    'médicalisée',
    'services',
    'social',
    'agricole',
  };

  @override
  EntityType get type => EntityType.etablissement;

  static const _keywords = etablissementKeywords;

  /// Liste fermée de connecteurs — jamais absorbés seuls, uniquement
  /// lorsqu'ils sont suivis d'un mot valide (voir [_segment]).
  static const String _connector =
      "(?:de|du|des|le|la|les|sur|en|aux|au|d['’]|l['’])";

  static const String _word = "[A-ZÀ-ÖØ-ÞŒ][\\wÀ-ÿ'’\\-]*";

  /// Un connecteur optionnel obligatoirement suivi d'un mot. Si un
  /// connecteur est présent mais qu'aucun mot valide ne suit (mot en
  /// minuscule, ponctuation, saut de ligne, fin de texte), tout le
  /// segment échoue — pas seulement la partie connecteur — et la
  /// répétition dans [_pattern] s'arrête avant, sans l'absorber.
  static const String _segment = '(?:$_connector[ \\t]+)?$_word';

  // Frontière de mot à gauche : évite qu'un mot-clé court (« CH ») ne matche
  // comme sous-chaîne d'un mot plus long (ex. « SANDWICH ») — les mots-clés
  // plus longs étaient déjà protégés de fait par l'espace obligatoire qui
  // suit, mais pas côté gauche. Écrite `(?<![\wÀ-ÿ])` et non `\b` : `\b` ne
  // connaît pas les lettres accentuées, « CH » était trouvé au milieu de
  // « BUËCH » et « VAL BUË » restait en clair (P2-207).
  //
  // `[ \t]` plutôt que `\s` entre le mot-clé et le nom, et entre chaque
  // segment du nom : un nom d'établissement ne traverse jamais un saut de
  // ligne dans un document réel — `\s` matcherait aussi le saut de ligne
  // et fusionnerait deux entités sans rapport (bug corrigé précédemment).
  static final RegExp _pattern = RegExp(
    r'(?<![\wÀ-ÿ])'
    '(?:${[..._keywords, ...etablissementKeywordsMinuscules].join('|')})'
    // Nom entre guillemets (« Les Tilleuls », "Les Tilleuls") ou nu.
    '[ \\t]+(?:["«“][ \\t]?$_segment(?:[ \\t]+$_segment)*[ \\t]?["»”]'
    '|$_segment(?:[ \\t]+$_segment)*)',
  );

  /// Vrai si [nom] (mot-clé compris) est un type en toutes lettres suivi
  /// seulement de mots génériques. Ne lit que la forme, jamais n'imprime la
  /// valeur.
  static bool _typeEtMotsGeneriques(String nom) {
    var motCle = '';
    for (final k in [..._keywords, ...etablissementKeywordsMinuscules]) {
      if (nom.startsWith(k) && k.length > motCle.length) motCle = k;
    }
    if (motCle.isEmpty) return false;
    // Un sigle (« CH », « EHPAD », « IMPro ») n'est pas un type en toutes
    // lettres : il reste masqué quel que soit le mot qui suit.
    if (motCle == motCle.toUpperCase() || motCle == 'IMPro') return false;
    final mots = nom
        .substring(motCle.length)
        .split(RegExp(r'[ \t]+'))
        .where((m) => m.isNotEmpty)
        .toList();
    return mots.isNotEmpty &&
        mots.every((m) => motsGeneriques.contains(m.toLowerCase()));
  }

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
      if (_typeEtMotsGeneriques(match.group(0)!)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.etablissement,
          start: match.start,
          end: match.end,
          value: match.group(0)!,
          confidence: 0.7,
        ),
      );
    }
    return results;
  }
}
