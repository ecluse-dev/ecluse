import 'package:ecluse_core/ecluse_core.dart';

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
final class EtablissementDetector implements EntityDetector {
  const EtablissementDetector();

  @override
  EntityType get type => EntityType.etablissement;

  static const _keywords = [
    'Foyer',
    'Résidence',
    'Residence',
    'IME',
    'ITEP',
    'ESAT',
    'EHPAD',
    'MAS',
    'FAM',
    'Centre',
    'CH',
    'SSIAD',
    'Clinique',
    'Hôpital',
    'Hopital',
    'Lycée',
    'Lycee',
  ];

  /// Liste fermée de connecteurs — jamais absorbés seuls, uniquement
  /// lorsqu'ils sont suivis d'un mot valide (voir [_segment]).
  static const String _connector =
      "(?:de|du|des|le|la|les|sur|en|aux|au|d['’]|l['’])";

  static const String _word = "[A-ZÀ-Ÿ][\\wÀ-ÿ'’\\-]*";

  /// Un connecteur optionnel obligatoirement suivi d'un mot. Si un
  /// connecteur est présent mais qu'aucun mot valide ne suit (mot en
  /// minuscule, ponctuation, saut de ligne, fin de texte), tout le
  /// segment échoue — pas seulement la partie connecteur — et la
  /// répétition dans [_pattern] s'arrête avant, sans l'absorber.
  static const String _segment = '(?:$_connector[ \\t]+)?$_word';

  // `\b` : évite qu'un mot-clé court (« CH ») ne matche comme sous-chaîne
  // d'un mot plus long (ex. « SANDWICH ») — les mots-clés plus longs
  // étaient déjà protégés de fait par l'espace obligatoire qui suit, mais
  // pas côté gauche.
  //
  // `[ \t]` plutôt que `\s` entre le mot-clé et le nom, et entre chaque
  // segment du nom : un nom d'établissement ne traverse jamais un saut de
  // ligne dans un document réel — `\s` matcherait aussi le saut de ligne
  // et fusionnerait deux entités sans rapport (bug corrigé précédemment).
  static final RegExp _pattern = RegExp(
    r'\b'
    '(?:${_keywords.join('|')})'
    '[ \\t]+$_segment(?:[ \\t]+$_segment)*',
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
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
